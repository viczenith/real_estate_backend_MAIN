from rest_framework import serializers

from DRF.clients.serializers.chat_serializers import (
    ChatUnreadCountSerializer as ClientChatUnreadCountSerializer,
    MessageCreateSerializer as ClientMessageCreateSerializer,
    MessageListSerializer as ClientMessageListSerializer,
    MessageSerializer as ClientMessageSerializer,
)


class MarketerMessageSerializer(ClientMessageSerializer):
    class Meta(ClientMessageSerializer.Meta):
        fields = ClientMessageSerializer.Meta.fields + [
            'deleted_for_everyone',
            'deleted_for_everyone_at',
        ]


class MarketerMessageCreateSerializer(ClientMessageCreateSerializer):
    class Meta(ClientMessageCreateSerializer.Meta):
        pass


class MarketerMessageListSerializer(ClientMessageListSerializer):
    class Meta(ClientMessageListSerializer.Meta):
        fields = ClientMessageListSerializer.Meta.fields + [
            'deleted_for_everyone',
        ]


class MarketerChatUnreadCountSerializer(ClientChatUnreadCountSerializer):
    pass


__all__ = [
    'MarketerMessageSerializer',
    'MarketerMessageCreateSerializer',
    'MarketerMessageListSerializer',
    'MarketerChatUnreadCountSerializer',
]
