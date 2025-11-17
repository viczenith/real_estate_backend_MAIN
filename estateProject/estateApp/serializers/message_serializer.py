from rest_framework import serializers
from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import Message
from .user_serializers import NestedUserSerializer

class MessageSerializer(DynamicFieldsModelSerializer):
    sender = NestedUserSerializer(read_only=True)
    recipient = NestedUserSerializer(read_only=True)
    # For nested replies, include a simple version to avoid deep recursion
    replies = serializers.SerializerMethodField()

    def get_replies(self, obj):
        replies = obj.replies.all()
        return MessageSerializer(replies, many=True, fields=('id', 'content', 'date_sent')).data

    class Meta:
        model = Message
        fields = '__all__'


class MessageCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ['content','message_type','file','reply_to']
