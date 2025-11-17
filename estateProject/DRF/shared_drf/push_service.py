"""Utilities for sending Firebase Cloud Messaging (FCM) pushes."""

from __future__ import annotations

import json
import logging
import os
from threading import Lock
from typing import Iterable, Mapping, Sequence

from django.conf import settings

try:  # firebase_admin is optional until credentials are configured
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:  # pragma: no cover - firebase_admin optional in some environments
    firebase_admin = None  # type: ignore
    credentials = None  # type: ignore
    messaging = None  # type: ignore

from estateApp.models import Message, UserDeviceToken, UserNotification

logger = logging.getLogger(__name__)

_FIREBASE_APP_LOCK = Lock()
_FIREBASE_APP_INITIALISED = False
_FCM_BATCH_SIZE = 500  # Maximum tokens per FCM multicast request
_INVALID_TOKEN_CODES = {
    "registration-token-not-registered",
    "invalid-argument",
    "not-found",
    "mismatched-credential",
}
_INVALID_TOKEN_KEYWORDS = (
    "registration-token-not-registered",
    "requested entity was not found",
    "not a valid registration token",
    "mismatched sender",
)


def _ensure_firebase_app() -> firebase_admin.App | None:
    """Initialise and return the Firebase app instance if possible."""
    global _FIREBASE_APP_INITIALISED

    if firebase_admin is None:
        logger.warning("firebase_admin package not installed; push notifications are disabled.")
        return None

    with _FIREBASE_APP_LOCK:
        if firebase_admin._apps:  # App already initialised
            return firebase_admin.get_app()

        if _FIREBASE_APP_INITIALISED:
            return None

        cred_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", None)
        if not cred_path:
            logger.warning("FIREBASE_CREDENTIALS_PATH is not configured; push notifications are disabled.")
            _FIREBASE_APP_INITIALISED = True
            return None

        cred: credentials.Base
        try:
            if os.path.isfile(cred_path):
                cred = credentials.Certificate(cred_path)
            else:
                # Assume the environment variable contains a JSON string
                cred_dict = json.loads(cred_path)
                cred = credentials.Certificate(cred_dict)
        except FileNotFoundError:
            logger.exception("Firebase credentials file not found at %s", cred_path)
            _FIREBASE_APP_INITIALISED = True
            return None
        except json.JSONDecodeError:
            logger.exception("FIREBASE_CREDENTIALS_PATH is neither a file path nor valid JSON.")
            _FIREBASE_APP_INITIALISED = True
            return None
        except Exception:  # pragma: no cover - defensive guard
            logger.exception("Unable to load Firebase credentials.")
            _FIREBASE_APP_INITIALISED = True
            return None

        try:
            app = firebase_admin.initialize_app(cred)
            _FIREBASE_APP_INITIALISED = True
            logger.info("Firebase app initialised successfully for push notifications.")
            return app
        except Exception:  # pragma: no cover - defensive guard
            logger.exception("Failed to initialise Firebase app; push notifications disabled.")
            _FIREBASE_APP_INITIALISED = True
            return None


def _stringify_payload(data: Mapping[str, object]) -> dict[str, str]:
    return {key: str(value) for key, value in data.items() if value is not None}


def _build_android_config() -> messaging.AndroidConfig | None:
    if messaging is None:
        return None

    icon = getattr(settings, "FIREBASE_DEFAULT_ICON", None)
    color = getattr(settings, "FIREBASE_DEFAULT_COLOR", None)
    channel_id = getattr(settings, "FIREBASE_DEFAULT_CHANNEL_ID", None)
    sound = getattr(settings, "FIREBASE_DEFAULT_SOUND", None)

    android_kwargs: dict[str, object] = {"priority": "high"}
    notification_kwargs: dict[str, object] = {}

    if icon:
        notification_kwargs["icon"] = icon
    if color:
        notification_kwargs["color"] = color
    if channel_id:
        notification_kwargs["channel_id"] = channel_id
    if sound:
        notification_kwargs["sound"] = sound

    if notification_kwargs:
        android_kwargs["notification"] = messaging.AndroidNotification(**notification_kwargs)

    return messaging.AndroidConfig(**android_kwargs)


def _deactivate_tokens(token_ids: Sequence[int]) -> None:
    if not token_ids:
        return
    UserDeviceToken.objects.filter(id__in=token_ids).update(is_active=False)
    logger.info("Marked %s device token(s) inactive after FCM errors.", len(token_ids))


def _send_multicast(tokens: Sequence[UserDeviceToken], *, title: str | None, body: str | None,
                    data: Mapping[str, object]) -> int:
    if not tokens:
        return 0

    app = _ensure_firebase_app()
    if app is None or messaging is None:
        return 0

    payload = _stringify_payload(data)
    android_config = _build_android_config()

    batch_success = 0
    for start in range(0, len(tokens), _FCM_BATCH_SIZE):
        batch = tokens[start:start + _FCM_BATCH_SIZE]
        token_values = [token.token for token in batch]

        message_kwargs: dict[str, object] = {
            "tokens": token_values,
            "data": payload,
        }
        if title or body:
            message_kwargs["notification"] = messaging.Notification(title=title, body=body)
        if android_config is not None:
            message_kwargs["android"] = android_config

        multicast_message = messaging.MulticastMessage(**message_kwargs)
        try:
            response = messaging.send_multicast(multicast_message, app=app)
        except Exception:
            logger.exception("Failed to send FCM multicast message.")
            continue

        batch_success += response.success_count

        invalid_token_ids: list[int] = []
        for index, resp in enumerate(response.responses):
            if resp.success:
                continue
            exc = resp.exception
            if exc is None:
                continue

            code = getattr(exc, "code", "") or ""
            message_lower = str(exc).lower()
            invalid = False
            if code in _INVALID_TOKEN_CODES:
                invalid = True
            elif any(keyword in message_lower for keyword in _INVALID_TOKEN_KEYWORDS):
                invalid = True

            if invalid:
                invalid_token_ids.append(batch[index].id)
            else:
                logger.warning("Failed to deliver FCM message to token %s: %s", batch[index].token, exc)

        _deactivate_tokens(invalid_token_ids)

    return batch_success


def _tokens_for_users(user_ids: Iterable[int]) -> list[UserDeviceToken]:
    ids = list({int(user_id) for user_id in user_ids if user_id})
    if not ids:
        return []
    return list(UserDeviceToken.objects.filter(user_id__in=ids, is_active=True))


def send_push_to_users(user_ids: Iterable[int], *, title: str | None, body: str | None,
                       data: Mapping[str, object]) -> int:
    """Send a push notification to all active tokens owned by *user_ids*."""
    tokens = _tokens_for_users(user_ids)
    if not tokens:
        logger.debug("No active device tokens found for users %s", list(user_ids))
        return 0

    return _send_multicast(tokens, title=title, body=body, data=data)


def send_user_notification_push(user_notification: UserNotification) -> int:
    notification = user_notification.notification
    title = notification.title
    body = notification.message

    data = {
        "type": notification.notification_type,
        "user_notification_id": user_notification.id,
        "notification_id": notification.id,
        "title": title,
        "body": body,
        "created_at": notification.created_at.isoformat() if notification.created_at else "",
    }

    return send_push_to_users([user_notification.user_id], title=title, body=body, data=data)


def send_chat_message_push(message: Message) -> int:
    if not message.recipient_id:
        return 0

    sender = message.sender
    recipient = message.recipient
    if recipient is None:
        return 0

    title = (sender.get_full_name() or sender.email or "New Message") if sender else "New Message"
    content = message.content.strip() if message.content else ""
    if not content and message.file:
        content = "Sent you an attachment"
    elif not content:
        content = "You have a new message"

    sender_role = getattr(sender, "role", "") if sender else ""
    recipient_role = getattr(recipient, "role", "") if recipient else ""
    normalized_roles = {role.lower() for role in (sender_role, recipient_role) if role}

    marketer_id: int | None = None
    if sender_role.lower() == "marketer":
        marketer_id = message.sender_id
    elif recipient_role.lower() == "marketer":
        marketer_id = message.recipient_id

    if "marketer" in normalized_roles:
        chat_id = f"marketer_chat_{marketer_id}" if marketer_id else "marketer_chat"
    elif "client" in normalized_roles and recipient_role.lower() in {"admin", "support"}:
        chat_id = "client_chat"
    else:
        chat_id = "admin_chat"

    participant_role = sender_role if recipient_role.lower() in {"admin", "support"} else recipient_role
    participant_id = message.sender_id if recipient_role.lower() in {"admin", "support"} else message.recipient_id

    file_url = ""
    file_name = ""
    if message.file:
        try:
            file_url = message.file.url or ""
            file_name = os.path.basename(message.file.name or "")
        except Exception:  # pragma: no cover - defensive guard
            file_url = ""
            file_name = ""

    sender_avatar = ""
    if sender is not None:
        profile_image = getattr(sender, "profile_image", None)
        if profile_image:
            try:
                sender_avatar = profile_image.url or ""
            except Exception:  # pragma: no cover - defensive guard
                sender_avatar = ""

    data = {
        "type": "chat_message",
        "notification_type": "chat_message",
        "chat_id": chat_id,
        "chat_context": chat_id,
        "message_id": message.id,
        "message_type": getattr(message, "message_type", ""),
        "sender_id": message.sender_id,
        "sender_name": sender.get_full_name() if sender else "",
        "sender_role": sender_role,
        "recipient_role": recipient_role,
        "title": title,
        "body": content,
        "message": content,
        "sent_at": message.date_sent.isoformat() if message.date_sent else "",
        "file_url": file_url,
        "file_name": file_name,
        "conversation_participant_role": participant_role,
        "conversation_participant_id": str(participant_id) if participant_id else "",
        "is_sender": "false",
        "from_self": "false",
    }

    if sender_avatar:
        data["sender_avatar"] = sender_avatar

    return send_push_to_users([recipient.id], title=title, body=content, data=data)


def send_chat_message_deleted_push(message: Message) -> int:
    """Notify all conversation participants that a message was deleted for everyone."""

    participant_ids: set[int] = set()
    if message.sender_id:
        participant_ids.add(message.sender_id)
    if message.recipient_id:
        participant_ids.add(message.recipient_id)

    if not participant_ids:
        return 0

    sender_role = getattr(message.sender, "role", "") if getattr(message, "sender", None) else ""
    recipient_role = getattr(message.recipient, "role", "") if getattr(message, "recipient", None) else ""

    chat_context = "admin_chat"
    normalized_roles = {role.lower() for role in (sender_role, recipient_role) if role}
    if "marketer" in normalized_roles:
        chat_context = "marketer_chat"
    elif "client" in normalized_roles:
        chat_context = "client_chat"

    data = {
        "type": "chat_message_deleted",
        "chat_context": chat_context,
        "message_id": message.id,
        "deleted_for_everyone": True,
    }

    if message.deleted_for_everyone_at:
        data["deleted_for_everyone_at"] = message.deleted_for_everyone_at.isoformat()

    return send_push_to_users(participant_ids, title=None, body=None, data=data)
