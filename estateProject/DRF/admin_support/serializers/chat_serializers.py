from rest_framework import serializers

from estateApp.models import CustomUser, Message
from DRF.clients.serializers.chat_serializers import (
    MessageListSerializer as ClientMessageListSerializer,
    MessageSerializer as ClientMessageSerializer,
)


def _get_initials(full_name: str) -> str:
    """Return up to two-letter initials for a participant."""

    if not full_name:
        return ""

    tokens = [part.strip() for part in full_name.split() if part.strip()]
    if not tokens:
        return ""
    if len(tokens) == 1:
        return tokens[0][:2].upper()
    return (tokens[0][:1] + tokens[1][:1]).upper()


class SupportMessageSerializer(ClientMessageSerializer):
    """Detailed serializer geared towards support agents."""

    sender_name = serializers.SerializerMethodField()
    sender_role = serializers.SerializerMethodField()
    sender_avatar = serializers.SerializerMethodField()
    sender_initials = serializers.SerializerMethodField()
    is_support_sender = serializers.SerializerMethodField()

    class Meta(ClientMessageSerializer.Meta):
        fields = ClientMessageSerializer.Meta.fields + [
            "sender_name",
            "sender_role",
            "sender_avatar",
            "sender_initials",
            "is_support_sender",
        ]

    def get_sender_name(self, obj):  # pragma: no cover - trivial accessor
        sender = getattr(obj, "sender", None)
        if not sender:
            return ""
        return sender.full_name or sender.get_full_name() or sender.username or "Anonymous"

    def get_sender_role(self, obj):  # pragma: no cover - trivial accessor
        sender = getattr(obj, "sender", None)
        return getattr(sender, "role", "") if sender else ""

    def get_sender_avatar(self, obj):
        sender = getattr(obj, "sender", None)
        if sender and getattr(sender, "profile_image", None):
            request = self.context.get("request")
            url = sender.profile_image.url
            if request and url and not url.startswith("http"):
                return request.build_absolute_uri(url)
            return url
        return None

    def get_sender_initials(self, obj):
        return _get_initials(self.get_sender_name(obj))

    def get_is_support_sender(self, obj):
        sender_role = self.get_sender_role(obj)
        return sender_role in {"admin", "support"}


class SupportMessageListSerializer(ClientMessageListSerializer):
    """Lightweight serializer used for chat timelines."""

    sender_name = serializers.SerializerMethodField()
    sender_role = serializers.SerializerMethodField()
    sender_avatar = serializers.SerializerMethodField()
    sender_initials = serializers.SerializerMethodField()
    is_support_sender = serializers.SerializerMethodField()

    class Meta(ClientMessageListSerializer.Meta):
        fields = ClientMessageListSerializer.Meta.fields + [
            "sender_name",
            "sender_role",
            "sender_avatar",
            "sender_initials",
            "is_support_sender",
        ]

    def get_sender_name(self, obj):  # pragma: no cover - trivial accessor
        sender = getattr(obj, "sender", None)
        if not sender:
            return ""
        return sender.full_name or sender.get_full_name() or sender.username or "Anonymous"

    def get_sender_role(self, obj):
        sender = getattr(obj, "sender", None)
        return getattr(sender, "role", "") if sender else ""

    def get_sender_avatar(self, obj):
        sender = getattr(obj, "sender", None)
        if sender and getattr(sender, "profile_image", None):
            request = self.context.get("request")
            url = sender.profile_image.url
            if request and url and not url.startswith("http"):
                return request.build_absolute_uri(url)
            return url
        return None

    def get_sender_initials(self, obj):
        return _get_initials(self.get_sender_name(obj))

    def get_is_support_sender(self, obj):
        sender_role = self.get_sender_role(obj)
        return sender_role in {"admin", "support"}


class SupportMessageCreateSerializer(serializers.ModelSerializer):
    """Serializer for support agents creating new messages."""

    class Meta:
        model = Message
        fields = ["content", "file", "message_type", "reply_to"]

    def validate(self, data):
        content = (data.get("content") or "").strip()
        file = data.get("file")
        if not content and not file:
            raise serializers.ValidationError(
                "Please provide either a message body or attach a file."
            )
        if content:
            data["content"] = content
        return data

    def create(self, validated_data):
        request = self.context.get("request")
        participant = self.context.get("participant")

        if request is None or participant is None:
            raise serializers.ValidationError("Missing messaging context.")

        if not isinstance(participant, CustomUser):
            raise serializers.ValidationError("Invalid participant supplied.")

        message = Message.objects.create(
            sender=request.user,
            recipient=participant,
            content=validated_data.get("content", ""),
            file=validated_data.get("file"),
            message_type=validated_data.get("message_type", "enquiry"),
            reply_to=validated_data.get("reply_to"),
            status="sent",
        )

        return message
