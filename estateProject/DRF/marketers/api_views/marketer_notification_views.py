from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import status
from rest_framework.authentication import SessionAuthentication, TokenAuthentication
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from DRF.marketers.serializers.marketer_notifications_serializers import (
    MarketerUserNotificationSerializer,
)
from DRF.marketers.serializers.permissions import IsMarketerUser
from estateApp.models import UserNotification


class MarketerNotificationPagination(PageNumberPagination):
    page_size = 12
    page_size_query_param = "page_size"
    max_page_size = 100


class MarketerNotificationListAPI(ListAPIView):
    """List notifications for the authenticated marketer user."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerUser)
    serializer_class = MarketerUserNotificationSerializer
    pagination_class = MarketerNotificationPagination

    def get_queryset(self):
        user = self.request.user
        qs = (
            UserNotification.objects.filter(user=user)
            .select_related("notification")
            .order_by("-created_at")
        )

        filt = self.request.GET.get("filter", "all").lower()
        if filt == "unread":
            qs = qs.filter(read=False)
        elif filt == "read":
            qs = qs.filter(read=True)

        since = self.request.GET.get("since")
        if since:
            dt = parse_datetime(since)
            if dt:
                if timezone.is_naive(dt):
                    dt = timezone.make_aware(dt, timezone.get_default_timezone())
                qs = qs.filter(created_at__gt=dt)
        return qs


class MarketerNotificationDetailAPI(RetrieveAPIView):
    """Retrieve a specific notification belonging to the marketer."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerUser)
    serializer_class = MarketerUserNotificationSerializer
    lookup_field = "pk"

    def get_object(self):
        user = self.request.user
        return get_object_or_404(
            UserNotification.objects.select_related("notification"),
            pk=self.kwargs["pk"],
            user=user,
        )


class MarketerUnreadCountAPI(APIView):
    """Return unread and total counts for marketer notifications."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerUser)

    def get(self, request, *args, **kwargs):
        user = request.user
        unread = UserNotification.objects.filter(user=user, read=False).count()
        total = UserNotification.objects.filter(user=user).count()
        return Response({"unread": unread, "total": total}, status=status.HTTP_200_OK)


class MarketerMarkReadAPI(APIView):
    """Mark a marketer notification as read."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerUser)

    def post(self, request, pk, *args, **kwargs):
        user = request.user
        un = get_object_or_404(UserNotification, pk=pk, user=user)
        if not un.read:
            un.read = True
            un.save(update_fields=["read"])
        return Response(
            MarketerUserNotificationSerializer(un, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


class MarketerMarkUnreadAPI(APIView):
    """Mark a marketer notification as unread."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerUser)

    def post(self, request, pk, *args, **kwargs):
        user = request.user
        un = get_object_or_404(UserNotification, pk=pk, user=user)
        if un.read:
            un.read = False
            un.save(update_fields=["read"])
        return Response(
            MarketerUserNotificationSerializer(un, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


class MarketerMarkAllReadAPI(APIView):
    """Mark all marketer notifications as read."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerUser)

    def post(self, request, *args, **kwargs):
        user = request.user
        updated = UserNotification.objects.filter(user=user, read=False).update(read=True)
        return Response({"marked": updated}, status=status.HTTP_200_OK)
