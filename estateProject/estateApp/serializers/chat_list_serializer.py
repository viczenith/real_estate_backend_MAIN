# from rest_framework import serializers

# class ClientChatSerializer(serializers.Serializer):
#     id = serializers.IntegerField()
#     full_name = serializers.CharField()
#     last_message = serializers.DateTimeField()
#     unread_count = serializers.IntegerField()


from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()

class ClientChatSerializer(serializers.ModelSerializer):
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.IntegerField(read_only=True)
    timestamp = serializers.DateTimeField(format='iso-8601')  # Ensure proper format

    class Meta:
        model = User
        fields = ['id', 'first_name', 'last_name', 'email', 'last_message', 'unread_count', 'timestamp']

    def get_last_message(self, obj):
        return obj.last_message or "No messages yet"

        