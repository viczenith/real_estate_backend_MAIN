from __future__ import annotations

import json
from typing import Optional

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import UserNotification, Message


def _serialize_notification(instance: UserNotification) -> dict:
    data = instance.serialize()

    # Aggregate counts so clients can keep badges in sync without extra polling
    unread_notifications_count = UserNotification.objects.filter(
        user=instance.user,
        read=False,
    ).count()
    global_message_count = Message.objects.filter(
        recipient=instance.user,
        is_read=False,
    ).count()

    data.update(
        {
            'unread_notifications_count': unread_notifications_count,
            'global_message_count': global_message_count,
        }
    )

    return {
        'type': 'new_notification',
        'data': data,
        'meta': {
            'unread_notifications_count': unread_notifications_count,
            'global_message_count': global_message_count,
        },
    }


def broadcast_user_notification(instance: UserNotification) -> None:
    """Send a user notification over the WebSocket channel for that user."""
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    payload = _serialize_notification(instance)

    try:
        async_to_sync(channel_layer.group_send)(
            f'notifications_{instance.user_id}',
            {
                'type': 'send_notification',
                'data': payload,
            },
        )
    except Exception:
        # Avoid raising errors in calling context (signals, views, etc.)
        pass
