from rest_framework import serializers
from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import Notification, UserNotification
from .user_serializers import CustomUserSerializer

class NotificationSerializer(DynamicFieldsModelSerializer):
    class Meta:
        model = Notification
        fields = '__all__'

class UserNotificationSerializer(DynamicFieldsModelSerializer):
    user = CustomUserSerializer(read_only=True)
    notification = NotificationSerializer(read_only=True)
    
    class Meta:
        model = UserNotification
        fields = '__all__'
