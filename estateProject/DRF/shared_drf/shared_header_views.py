from rest_framework.views import APIView
from rest_framework.generics import ListAPIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from django.db.models import Count, Max, Q
from django.utils import timezone
from django.core.paginator import Paginator

from estateApp.models import (
    UserNotification, Notification, Message, ClientUser, CustomUser
)
from DRF.shared_drf.shared_header_serializers import (
    SimpleNotificationSerializer, HeaderUserSerializer, ClientChatPreviewSerializer, MarketerChatPreviewSerializer
)

# Helper: safe absolute url builder
def build_absolute_url(request, url):
    if not url:
        return None
    try:
        return request.build_absolute_uri(url)
    except Exception:
        return url


class HeaderDataAPIView(APIView):
    """
    Returns all data needed to render the dynamic header.
    - When unauthenticated, returns minimal fields (home_url).
    - When authenticated, returns counts, notifications preview, profile info, and message summary.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        data = {
            "home_url": request.build_absolute_uri('/') if request else "/",
        }

        user = request.user if getattr(request, 'user', None) and request.user.is_authenticated else None

        # Unauthenticated: return only minimal header
        if not user:
            return Response(data, status=status.HTTP_200_OK)

        # Profile info
        data['user'] = HeaderUserSerializer(user, context={'request': request}).data

        # Notifications (unread count + first 5 unread notifications)
        unread_qs = UserNotification.objects.filter(user=user, read=False).select_related('notification').order_by('-created_at')
        unread_count = unread_qs.count()
        recent_unread = unread_qs[:5]
        data['unread_notifications_count'] = unread_count
        data['unread_notifications'] = SimpleNotificationSerializer(recent_unread, many=True, context={'request': request}).data

        # Messages: role-sensitive
        if getattr(user, 'role', '') == 'admin' or user.is_staff:
            # Admin view: get distinct clients who have unread messages to admin
            # We'll look for messages where recipient is the admin (user) OR messages sent by client to admin user
            # Find clients who have unread messages addressed to this admin
            client_msgs = (
                Message.objects
                .filter(sender__role='client', recipient=user)  # messages from clients to admin
                .values('sender')
                .annotate(unread_count=Count('id', filter=Q(is_read=False)))
                .filter(unread_count__gt=0)
            )

            # Collect client IDs
            client_ids = [c['sender'] for c in client_msgs]
            clients = ClientUser.objects.filter(id__in=client_ids)

            preview_list = []
            total_unread = 0
            for c in clients:
                unread_count = Message.objects.filter(sender=c, recipient=user, is_read=False).count()
                last_msg = Message.objects.filter(sender=c, recipient=user).order_by('-date_sent').first()
                preview_list.append({
                    "id": c.id,
                    "full_name": c.full_name,
                    "profile_image": getattr(c.profile_image, 'url', None) if getattr(c, 'profile_image', None) else None,
                    "unread_count": unread_count,
                    "last_content": last_msg.content if last_msg and last_msg.content else None,
                    "last_file": getattr(last_msg.file, 'name', None) if last_msg and getattr(last_msg, 'file', None) else None,
                    "last_message_timestamp": last_msg.date_sent if last_msg else None
                })
                total_unread += unread_count

            # Marketers unread for admin header parity
            marketers_unread_qs = (
                Message.objects
                .filter(sender__role='marketer', recipient=user)
                .values('sender')
                .annotate(unread_count=Count('id', filter=Q(is_read=False)))
                .filter(unread_count__gt=0)
            )
            marketer_ids = [m['sender'] for m in marketers_unread_qs]
            marketers = CustomUser.objects.filter(id__in=marketer_ids, role='marketer')
            marketers_preview = []
            marketers_total_unread = 0
            for m in marketers:
                m_unread = Message.objects.filter(sender=m, recipient=user, is_read=False).count()
                if m_unread == 0:
                    continue
                m_last = Message.objects.filter(sender=m, recipient=user).order_by('-date_sent').first()
                marketers_preview.append({
                    "id": m.id,
                    "full_name": m.full_name,
                    "profile_image": getattr(m.profile_image, 'url', None) if getattr(m, 'profile_image', None) else None,
                    "unread_count": m_unread,
                    "last_content": m_last.content if m_last else None,
                    "last_file": getattr(m_last.file, 'name', None) if m_last and getattr(m_last, 'file', None) else None,
                    "last_message_timestamp": m_last.date_sent if m_last else None
                })
                marketers_total_unread += m_unread

            data.update({
                "total_unread_messages": total_unread,
                "client_count": len(preview_list),
                "unread_clients": ClientChatPreviewSerializer(preview_list, many=True, context={'request': request}).data,
                "marketers_unread_count": marketers_total_unread,
                "unread_marketers": MarketerChatPreviewSerializer(marketers_preview, many=True, context={'request': request}).data,
            })
        else:
            # Non-admin user: count messages from admin (global messages) and unread from admin
            global_unread = Message.objects.filter(recipient=user, is_read=False).count()
            unread_from_admin = Message.objects.filter(sender__role='admin', recipient=user, is_read=False).count()
            data.update({
                "global_message_count": global_unread,
                "unread_admin_count": unread_from_admin
            })

        return Response(data, status=status.HTTP_200_OK)


class ChatUnreadCountAPIView(APIView):
    """
    Lightweight endpoint polled by the header JS to update badges quickly.
    - returns role-specific counts.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        user = request.user if getattr(request, 'user', None) and request.user.is_authenticated else None
        if not user:
            return Response({"detail": "unauthenticated"}, status=status.HTTP_204_NO_CONTENT)

        if getattr(user, 'role', '') == 'admin' or user.is_staff:
            total_unread = Message.objects.filter(recipient=user, is_read=False).count()
            # total_unread_count — total unread across client conversations (alias)
            total_unread_count = total_unread
            return Response({
                "total_unread": total_unread,
                "total_unread_count": total_unread_count
            }, status=status.HTTP_200_OK)
        else:
            global_message_count = Message.objects.filter(recipient=user, is_read=False).count()
            unread_admin_count = Message.objects.filter(sender__role='admin', recipient=user, is_read=False).count()
            return Response({
                "global_message_count": global_message_count,
                "unread_admin_count": unread_admin_count
            }, status=status.HTTP_200_OK)


class NotificationsListAPIView(ListAPIView):
    """
    Full paginated notifications list for the current user.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = SimpleNotificationSerializer

    def get_queryset(self):
        user = self.request.user
        return UserNotification.objects.filter(user=user).select_related('notification').order_by('-created_at')


class MarkNotificationReadAPIView(APIView):
    """
    Mark a user-notification as read (POST).
    URL pattern expects <int:pk> which is the UserNotification id.
    Optionally accepts ?next=... for redirect on template side.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, pk, *args, **kwargs):
        user = request.user
        try:
            un = UserNotification.objects.get(pk=pk, user=user)
        except UserNotification.DoesNotExist:
            return Response({"detail": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        un.read = True
        un.save(update_fields=['read'])
        return Response({"detail": "marked read", "id": pk}, status=status.HTTP_200_OK)


class AdminClientChatListAPIView(APIView):
    """
    Returns a lightweight list of clients with unread messages for admin.
    Similar to what header shows, but dedicated endpoint for admin chat list page.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        user = request.user
        if not (user.is_staff or getattr(user, 'role', '') == 'admin'):
            return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

        # Find clients who have sent messages to admin and have unread messages
        clients_data = []
        clients_qs = ClientUser.objects.filter(sent_messages__recipient=user).distinct()
        for c in clients_qs:
            unread_count = Message.objects.filter(sender=c, recipient=user, is_read=False).count()
            if unread_count == 0:
                continue
            last_msg = Message.objects.filter(sender=c, recipient=user).order_by('-date_sent').first()
            clients_data.append({
                "id": c.id,
                "full_name": c.full_name,
                "profile_image": getattr(c.profile_image, 'url', None) if getattr(c, 'profile_image', None) else None,
                "unread_count": unread_count,
                "last_content": last_msg.content if last_msg else None,
                "last_file": getattr(last_msg.file, 'name', None) if last_msg and getattr(last_msg, 'file', None) else None,
                "last_message_timestamp": last_msg.date_sent if last_msg else None
            })

        # sort by last_message_timestamp desc
        clients_data.sort(key=lambda x: x.get('last_message_timestamp') or timezone.datetime.min, reverse=True)

        return Response({
            "client_count": len(clients_data),
            "clients": clients_data
        }, status=status.HTTP_200_OK)


class AdminMarketerChatListAPIView(APIView):
    """
    Returns a lightweight list of marketers with unread messages for admin.
    Parity to clients unread list, used by header in admin side.
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        user = request.user
        if not (user.is_staff or getattr(user, 'role', '') == 'admin'):
            return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

        marketers_data = []
        marketers_qs = CustomUser.objects.filter(role='marketer', sent_messages__recipient=user).distinct()
        for m in marketers_qs:
            unread_count = Message.objects.filter(sender=m, recipient=user, is_read=False).count()
            if unread_count == 0:
                continue
            last_msg = Message.objects.filter(sender=m, recipient=user).order_by('-date_sent').first()
            marketers_data.append({
                "id": m.id,
                "full_name": m.full_name,
                "profile_image": getattr(m.profile_image, 'url', None) if getattr(m, 'profile_image', None) else None,
                "unread_count": unread_count,
                "last_content": last_msg.content if last_msg else None,
                "last_file": getattr(last_msg.file, 'name', None) if last_msg and getattr(last_msg, 'file', None) else None,
                "last_message_timestamp": last_msg.date_sent if last_msg else None
            })

        marketers_data.sort(key=lambda x: x.get('last_message_timestamp') or timezone.datetime.min, reverse=True)

        return Response({
            "marketer_count": len(marketers_data),
            "marketers": marketers_data
        }, status=status.HTTP_200_OK)


