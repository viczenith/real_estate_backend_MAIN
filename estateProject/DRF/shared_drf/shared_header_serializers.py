from rest_framework import serializers
from django.utils.timesince import timesince
from django.conf import settings

from estateApp.models import (
    UserNotification
)

class SimpleNotificationSerializer(serializers.ModelSerializer):
    title = serializers.CharField(source='notification.title')
    message = serializers.CharField(source='notification.message')
    created_at = serializers.DateTimeField(format="%Y-%m-%dT%H:%M:%SZ")
    notification_id = serializers.IntegerField(source='notification.id')

    class Meta:
        model = UserNotification
        fields = ['notification_id', 'title', 'message', 'created_at', 'read']


class HeaderUserSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    full_name = serializers.CharField()
    job = serializers.CharField(allow_null=True, allow_blank=True)
    profile_image = serializers.SerializerMethodField()
    is_staff = serializers.BooleanField()
    role = serializers.CharField(allow_null=True)

    def get_profile_image(self, obj):
        try:
            if getattr(obj, 'profile_image', None):
                request = self.context.get('request')
                url = obj.profile_image.url
                if request:
                    return request.build_absolute_uri(url)
                return url
        except Exception:
            pass
        return None


class ClientChatPreviewSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    full_name = serializers.CharField()
    profile_image = serializers.SerializerMethodField()
    unread_count = serializers.IntegerField()
    last_content = serializers.CharField(allow_null=True)
    last_file = serializers.CharField(allow_null=True)
    last_message_timestamp = serializers.DateTimeField(allow_null=True)
    last_message_timesince = serializers.SerializerMethodField()

    def get_profile_image(self, obj):
        # obj is a dict in our view
        prof = obj.get('profile_image')
        request = self.context.get('request')
        if prof:
            try:
                if request:
                    return request.build_absolute_uri(prof)
                return prof
            except Exception:
                return prof
        return None

    def get_last_message_timesince(self, obj):
        ts = obj.get('last_message_timestamp')
        if not ts:
            return None
        return timesince(ts) + ' ago'


class MarketerChatPreviewSerializer(ClientChatPreviewSerializer):
    """Alias serializer for marketer chat preview; same fields as client preview."""
    pass


