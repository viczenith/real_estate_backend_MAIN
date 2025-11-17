from __future__ import annotations

from typing import List, Dict

from django.db.models import Max, Q
from django.urls import reverse
from django.utils import timezone

from estateApp.models import CustomUser, Message


def _build_initials(name: str) -> str:
    if not name:
        return "--"
    parts = name.strip().split()
    if len(parts) >= 2:
        return (parts[0][0] + parts[1][0]).upper()
    return name[:2].upper()


def _build_last_message_preview(message: Message | None) -> str:
    if not message:
        return "No messages yet."

    if message.content:
        preview = message.content.strip()
        return preview if len(preview) <= 80 else preview[:77] + "..."

    if message.file:
        file_name = message.file.name.rsplit('/', 1)[-1]
        return f"Attachment: {file_name}"

    return "Sent a message"


def _collect_participants(role: str) -> List[Dict]:
    """Return chat row dictionaries for users with the given role."""
    participants = (
        CustomUser.objects
        .filter(role=role, sent_messages__recipient__role='admin')
        .distinct()
        .annotate(last_message_at=Max('sent_messages__date_sent'))
    )

    rows: List[Dict] = []
    for user in participants:
        conversation_qs = Message.objects.filter(
            Q(sender=user, recipient__role='admin') |
            Q(sender__role='admin', recipient=user)
        ).order_by('-date_sent')

        last_message = conversation_qs.first()
        last_ts = last_message.date_sent if last_message else user.last_message_at
        if last_ts is None:
            last_ts = timezone.now()

        full_name = user.get_full_name() or user.username or "Unknown"
        rows.append({
            'id': user.id,
            'name': full_name,
            'initials': _build_initials(full_name),
            'unread_count': Message.objects.filter(
                sender=user,
                recipient__role='admin',
                is_read=False,
            ).count(),
            'last_message': _build_last_message_preview(last_message),
            'last_message_ts': last_ts,
            'url': reverse('admin_chat', args=[user.id]) if role == 'client' else reverse('admin_marketer_chat', args=[user.id]),
            'role': role,
        })
    return rows


def build_chat_rows() -> List[Dict]:
    """Aggregate client and marketer conversations for the support inbox."""
    chat_rows = _collect_participants('client') + _collect_participants('marketer')
    chat_rows.sort(key=lambda row: row['last_message_ts'], reverse=True)
    return chat_rows
