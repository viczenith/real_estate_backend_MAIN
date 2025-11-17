from rest_framework import serializers
from estateApp.models import Message, CustomUser
from django.utils.timesince import timesince


class MessageSenderSerializer(serializers.ModelSerializer):
    """Lightweight serializer for message sender info"""
    full_name = serializers.SerializerMethodField()
    
    class Meta:
        model = CustomUser
        fields = ['id', 'email', 'full_name', 'role']
    
    def get_full_name(self, obj):
        return obj.get_full_name()


class MessageSerializer(serializers.ModelSerializer):
    """Full message serializer with sender details"""
    sender = MessageSenderSerializer(read_only=True)
    recipient = MessageSenderSerializer(read_only=True)
    file_url = serializers.SerializerMethodField()
    file_name = serializers.SerializerMethodField()
    file_size = serializers.SerializerMethodField()
    file_type = serializers.SerializerMethodField()
    time_ago = serializers.SerializerMethodField()
    is_sender = serializers.SerializerMethodField()
    formatted_date = serializers.SerializerMethodField()
    sender_avatar = serializers.SerializerMethodField()
    
    class Meta:
        model = Message
        fields = [
            'id', 'sender', 'recipient', 'message_type', 'content',
            'file', 'file_url', 'file_name', 'file_size', 'file_type',
            'date_sent', 'formatted_date', 'time_ago', 'is_read',
            'status', 'reply_to', 'is_sender', 'deleted_for_everyone',
            'deleted_for_everyone_at', 'sender_avatar'
        ]
        read_only_fields = ['id', 'date_sent', 'sender', 'recipient']

    def to_representation(self, instance):
        data = super().to_representation(instance)

        if getattr(instance, 'deleted_for_everyone', False):
            data['content'] = '🚫 This message was deleted'
            data['file'] = None
            data['file_url'] = None
            data['file_name'] = None
            data['file_size'] = None
            data['file_type'] = None
        return data
    
    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None
    
    def get_file_name(self, obj):
        if obj.file:
            return obj.file.name.split('/')[-1]
        return None
    
    def get_file_size(self, obj):
        if obj.file:
            try:
                return obj.file.size
            except:
                return None
        return None
    
    def get_file_type(self, obj):
        if obj.file:
            name = obj.file.name.lower()
            if any(ext in name for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']):
                return 'image'
            elif '.pdf' in name:
                return 'pdf'
            elif any(ext in name for ext in ['.doc', '.docx']):
                return 'document'
            elif any(ext in name for ext in ['.xls', '.xlsx']):
                return 'spreadsheet'
            elif any(ext in name for ext in ['.zip', '.rar', '.7z']):
                return 'archive'
            else:
                return 'file'
        return None

    def get_sender_avatar(self, obj):
        sender = getattr(obj, 'sender', None)
        role = getattr(sender, 'role', '') if sender else ''
        profile_image = getattr(sender, 'profile_image', None) if sender else None
        if profile_image:
            url = getattr(profile_image, 'url', '') or ''
            if not url:
                return None
            request = self.context.get('request')
            if request and not url.startswith('http'):
                return request.build_absolute_uri(url)
            return url
        if role.lower() in {'admin', 'support'}:
            return 'asset://assets/logo.png'
        return None
    
    def get_time_ago(self, obj):
        return timesince(obj.date_sent)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if getattr(instance, 'deleted_for_everyone', False):
            data['content'] = '🚫 This message was deleted'
            data['file_url'] = None
            data['file_type'] = None
        return data
    
    def get_is_sender(self, obj):
        request = self.context.get('request')
        if request and request.user:
            return obj.sender == request.user
        return False
    
    def get_formatted_date(self, obj):
        return obj.date_sent.strftime('%b %d, %Y %I:%M %p')


class MessageCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating new messages"""
    
    class Meta:
        model = Message
        fields = ['content', 'file', 'message_type', 'reply_to']
    
    def validate(self, data):
        content = data.get('content', '').strip()
        file = data.get('file')
        
        if not content and not file:
            raise serializers.ValidationError(
                "Please provide either a message or attach a file."
            )
        
        return data
    
    def create(self, validated_data):
        request = self.context.get('request')
        
        # Get admin user as recipient
        admin_user = CustomUser.objects.filter(role='admin').first()
        
        if not admin_user:
            raise serializers.ValidationError("No admin user found to send message to.")
        
        message = Message.objects.create(
            sender=request.user,
            recipient=admin_user,
            content=validated_data.get('content', ''),
            file=validated_data.get('file'),
            message_type=validated_data.get('message_type', 'enquiry'),
            reply_to=validated_data.get('reply_to'),
            status='sent'
        )
        
        return message


class MessageListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for message lists"""
    sender_name = serializers.SerializerMethodField()
    sender_role = serializers.CharField(source='sender.role', read_only=True)
    is_sender = serializers.SerializerMethodField()
    file_url = serializers.SerializerMethodField()
    file_type = serializers.SerializerMethodField()
    time_ago = serializers.SerializerMethodField()
    sender_avatar = serializers.SerializerMethodField()
    
    class Meta:
        model = Message
        fields = [
            'id', 'sender_name', 'sender_role', 'content', 'file_url',
            'file_type', 'date_sent', 'time_ago', 'is_read', 'status',
            'is_sender', 'deleted_for_everyone', 'deleted_for_everyone_at',
            'sender_avatar'
        ]
    
    def get_sender_name(self, obj):
        return obj.sender.get_full_name() if obj.sender else 'Unknown'
    
    def get_is_sender(self, obj):
        request = self.context.get('request')
        if request and request.user:
            return obj.sender == request.user
        return False
    
    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None
    
    def get_file_type(self, obj):
        if obj.file:
            name = obj.file.name.lower()
            if any(ext in name for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']):
                return 'image'
            elif '.pdf' in name:
                return 'pdf'
            elif any(ext in name for ext in ['.doc', '.docx']):
                return 'document'
            else:
                return 'file'
        return None

    def get_sender_avatar(self, obj):
        sender = getattr(obj, 'sender', None)
        role = getattr(sender, 'role', '') if sender else ''
        profile_image = getattr(sender, 'profile_image', None) if sender else None
        if profile_image:
            url = getattr(profile_image, 'url', '') or ''
            if not url:
                return None
            request = self.context.get('request')
            if request and not url.startswith('http'):
                return request.build_absolute_uri(url)
            return url
        if role.lower() in {'admin', 'support'}:
            return 'asset://assets/logo.png'
        return None
    
    def get_time_ago(self, obj):
        return timesince(obj.date_sent)


class ChatUnreadCountSerializer(serializers.Serializer):
    """Serializer for unread message count"""
    unread_count = serializers.IntegerField()
    last_message = MessageListSerializer(allow_null=True)
