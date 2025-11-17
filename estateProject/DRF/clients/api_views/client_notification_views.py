from DRF.clients.serializers.client_notifications_serializers import UserNotificationSerializer
from DRF.clients.serializers.permissions import IsClientUser
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.generics import RetrieveAPIView, ListAPIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from rest_framework.pagination import PageNumberPagination
from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_datetime
from django.utils import timezone

from estateApp.models import UserNotification


class SmallPagination(PageNumberPagination):
    page_size = 12
    page_size_query_param = "page_size"
    max_page_size = 100

class ClientNotificationListAPI(ListAPIView):
    """
    GET /api/notifications/  (clients only)
    Optional query params:
      - filter=unread|read|all  (default: all)
      - since=YYYY-MM-DDTHH:MM:SSZ  (only return notifications created after this time)
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsClientUser)
    serializer_class = UserNotificationSerializer
    pagination_class = SmallPagination

    def get_queryset(self):
        user = self.request.user
        qs = UserNotification.objects.filter(user=user).select_related('notification').order_by('-created_at')

        filt = self.request.GET.get('filter', 'all').lower()
        if filt == 'unread':
            qs = qs.filter(read=False)
        elif filt == 'read':
            qs = qs.filter(read=True)

        since = self.request.GET.get('since')
        if since:
            dt = parse_datetime(since)
            if dt:
                if timezone.is_naive(dt):
                    dt = timezone.make_aware(dt, timezone.get_default_timezone())
                qs = qs.filter(created_at__gt=dt)
        return qs

class ClientNotificationDetailAPI(RetrieveAPIView):
    """
    GET /api/notifications/<pk>/  (clients only) - ensures object belongs to request.user
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsClientUser)
    serializer_class = UserNotificationSerializer
    lookup_field = 'pk'

    def get_object(self):
        user = self.request.user
        return get_object_or_404(UserNotification.objects.select_related('notification'), pk=self.kwargs['pk'], user=user)

class UnreadCountAPI(APIView):
    """
    GET /api/notifications/unread-count/ -> { unread: n, total: m }
    (clients only)
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsClientUser)

    def get(self, request, *args, **kwargs):
        user = request.user
        unread = UserNotification.objects.filter(user=user, read=False).count()
        total = UserNotification.objects.filter(user=user).count()
        return Response({"unread": unread, "total": total}, status=status.HTTP_200_OK)

class MarkReadAPI(APIView):
    """
    POST /api/notifications/<pk>/mark-read/  (clients only)
    Marks the UserNotification.read = True (no read_at in your model)
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsClientUser)

    def post(self, request, pk, *args, **kwargs):
        user = request.user
        un = get_object_or_404(UserNotification, pk=pk, user=user)
        if not un.read:
            un.read = True
            un.save(update_fields=['read'])
        return Response(UserNotificationSerializer(un, context={'request': request}).data, status=status.HTTP_200_OK)

class MarkUnreadAPI(APIView):
    """
    POST /api/notifications/<pk>/mark-unread/  (clients only)
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsClientUser)

    def post(self, request, pk, *args, **kwargs):
        user = request.user
        un = get_object_or_404(UserNotification, pk=pk, user=user)
        if un.read:
            un.read = False
            un.save(update_fields=['read'])
        return Response(UserNotificationSerializer(un, context={'request': request}).data, status=status.HTTP_200_OK)

class MarkAllReadAPI(APIView):
    """
    POST /api/notifications/mark-all-read/  (clients only)
    Marks all unread notifications for the requesting client as read (atomic single update)
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsClientUser)

    def post(self, request, *args, **kwargs):
        user = request.user
        updated = UserNotification.objects.filter(user=user, read=False).update(read=True)
        return Response({"marked": updated}, status=status.HTTP_200_OK)
