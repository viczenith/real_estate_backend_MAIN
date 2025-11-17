from rest_framework import serializers
from estateApp.models import Notification, UserNotification


class MarketerNotificationSerializer(serializers.ModelSerializer):
    notification_type_display = serializers.CharField(source="get_notification_type_display", read_only=True)
    created_at = serializers.DateTimeField(format="%Y-%m-%dT%H:%M:%SZ", read_only=True)

    class Meta:
        model = Notification
        fields = [
            "id",
            "notification_type",
            "notification_type_display",
            "title",
            "message",
            "created_at",
        ]


class MarketerUserNotificationSerializer(serializers.ModelSerializer):
    notification = MarketerNotificationSerializer(read_only=True)
    read = serializers.BooleanField(read_only=True)
    created_at = serializers.DateTimeField(format="%Y-%m-%dT%H:%M:%SZ", read_only=True)

    class Meta:
        model = UserNotification
        fields = ["id", "notification", "read", "created_at"]
