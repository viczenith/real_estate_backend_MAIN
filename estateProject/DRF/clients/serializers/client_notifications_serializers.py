# from rest_framework import serializers
# from estateApp.models import UserNotification, Notification

# class NotificationSerializer(serializers.ModelSerializer):
#     # Expose the human-friendly choice label used by the Django template
#     notification_type_display = serializers.SerializerMethodField()

#     class Meta:
#         model = Notification
#         fields = ['id', 'notification_type', 'notification_type_display', 'title', 'message', 'created_at']
#         read_only_fields = ['id', 'created_at']

#     def get_notification_type_display(self, obj):
#         try:
#             # Use model's display helper if available
#             return obj.get_notification_type_display()
#         except Exception:
#             # Fallback to the raw value as string
#             return str(getattr(obj, 'notification_type', '') or '')


# class UserNotificationSerializer(serializers.ModelSerializer):
#     notification = NotificationSerializer(read_only=True)

#     class Meta:
#         model = UserNotification
#         fields = ['id', 'notification', 'created_at', 'read']
#         read_only_fields = ['id', 'notification', 'created_at']




from rest_framework import serializers
from estateApp.models import Notification, UserNotification

class NotificationSerializer(serializers.ModelSerializer):
    notification_type_display = serializers.CharField(source='get_notification_type_display', read_only=True)
    created_at = serializers.DateTimeField(format="%Y-%m-%dT%H:%M:%SZ", read_only=True)

    class Meta:
        model = Notification
        fields = [
            'id',
            'notification_type',
            'notification_type_display',
            'title',
            'message',
            'created_at'
        ]


class UserNotificationSerializer(serializers.ModelSerializer):
    notification = NotificationSerializer(read_only=True)
    read = serializers.BooleanField(read_only=True)
    created_at = serializers.DateTimeField(format="%Y-%m-%dT%H:%M:%SZ", read_only=True)

    class Meta:
        model = UserNotification
        fields = ['id', 'notification', 'read', 'created_at']
