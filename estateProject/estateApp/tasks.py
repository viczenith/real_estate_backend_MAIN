from __future__ import annotations

try:
    from celery import shared_task  # type: ignore
    HAS_CELERY = True
except ModuleNotFoundError:  # pragma: no cover - fallback for environments without Celery
    import functools

    HAS_CELERY = False

    def shared_task(*decorator_args, **decorator_kwargs):
        """Lightweight stand-in for celery.shared_task when Celery is unavailable."""

        def decorator(func):
            @functools.wraps(func)
            def wrapper(*args, **kwargs):
                return func(*args, **kwargs)

            # mimic the Celery API surface used inside the project
            wrapper.delay = lambda *args, **kwargs: func(*args, **kwargs)
            wrapper.apply_async = lambda args=None, kwargs=None, **opts: func(*(args or ()), **(kwargs or {}))
            wrapper.is_immediate = True
            return wrapper

        if decorator_args and callable(decorator_args[0]) and not decorator_kwargs:
            return decorator(decorator_args[0])
        return decorator


import logging
from dataclasses import dataclass
from typing import Iterable, Sequence

from django.db import transaction
from django.utils import timezone

from estateApp.models import Notification, NotificationDispatch, UserNotification
from estateApp.ws_utils import broadcast_user_notification
from DRF.shared_drf.push_service import send_user_notification_push


logger = logging.getLogger(__name__)

if not HAS_CELERY:
    logger.warning("Celery not available; notification tasks will run synchronously in-process")


BATCH_SIZE = 10_000


@dataclass
class NotificationBatch:
    notification_id: int
    user_ids: Sequence[int]


def _dispatch_notification_batch(dispatch_id: int, notification_id: int, user_ids: Iterable[int]) -> dict:
    user_ids = list(dict.fromkeys(int(uid) for uid in user_ids))
    if not user_ids:
        return {"created": 0}

    try:
        with transaction.atomic():
            notification = Notification.objects.select_for_update().get(pk=notification_id)
            dispatch = NotificationDispatch.objects.select_for_update().get(pk=dispatch_id)

            user_notifications = [
                UserNotification(user_id=user_id, notification=notification)
                for user_id in user_ids
            ]
            created = UserNotification.objects.bulk_create(
                user_notifications,
                ignore_conflicts=True,
            )

            now_ts = timezone.now()
            if dispatch.started_at is None:
                dispatch.started_at = now_ts
            dispatch.status = NotificationDispatch.STATUS_PROCESSING
            dispatch.processed_batches += 1
            created_count = len(created)
            if created_count:
                dispatch.processed_recipients += created_count
            dispatch.updated_at = now_ts
            dispatch.save(update_fields=[
                'status',
                'processed_batches',
                'processed_recipients',
                'started_at',
                'updated_at',
            ])

    except Exception as exc:
        NotificationDispatch.objects.filter(pk=dispatch_id).update(
            status=NotificationDispatch.STATUS_FAILED,
            last_error=str(exc)[:2000],
            finished_at=timezone.now(),
            updated_at=timezone.now(),
        )
        raise

    dispatch = NotificationDispatch.objects.get(pk=dispatch_id)

    for entry in created:
        try:
            broadcast_user_notification(entry)
        except Exception as exc:
            logger.warning("Failed to broadcast notification %s to user %s: %s", notification_id, entry.user_id, exc, exc_info=True)

        try:
            send_user_notification_push(entry)
        except Exception as exc:
            logger.warning("Failed to send push notification %s to user %s: %s", notification_id, entry.user_id, exc, exc_info=True)

    if dispatch.total_recipients > 0 and dispatch.processed_recipients >= dispatch.total_recipients:
        dispatch.mark_completed()
    elif dispatch.total_batches > 0 and dispatch.processed_batches >= dispatch.total_batches:
        dispatch.mark_completed()

    return {"created": len(created)}


def _dispatch_notification_stream(dispatch_id: int, notification_id: int, user_ids: Iterable[int]) -> dict:
    created_total = 0
    chunk: list[int] = []
    dispatch = NotificationDispatch.objects.get(pk=dispatch_id)
    dispatch.mark_processing()

    for uid in user_ids:
        chunk.append(int(uid))
        if len(chunk) >= BATCH_SIZE:
            result = _dispatch_notification_batch(dispatch_id, notification_id, chunk)
            created_total += result.get("created", 0)
            chunk.clear()

    if chunk:
        result = _dispatch_notification_batch(dispatch_id, notification_id, chunk)
        created_total += result.get("created", 0)

    if dispatch.total_recipients == 0:
        dispatch.mark_completed()

    return {"created": created_total}


@shared_task(name="notifications.dispatch_notification_batch")
def dispatch_notification_batch(dispatch_id: int, notification_id: int, user_ids: Iterable[int]) -> dict:
    return _dispatch_notification_batch(dispatch_id, notification_id, user_ids)


@shared_task(name="notifications.dispatch_notification_stream")
def dispatch_notification_stream(dispatch_id: int, notification_id: int, user_ids: Iterable[int]) -> dict:
    return _dispatch_notification_stream(dispatch_id, notification_id, user_ids)


def dispatch_notification_stream_sync(dispatch_id: int, notification_id: int, user_ids: Iterable[int]) -> dict:
    """Synchronous helper used when Celery workers/broker are unavailable."""
    return _dispatch_notification_stream(dispatch_id, notification_id, user_ids)


def is_celery_worker_available(timeout: float = 2.0) -> bool:
    """Return True if a Celery worker responds within *timeout* seconds."""
    if not HAS_CELERY:
        return False

    try:
        app = dispatch_notification_stream.app  # type: ignore[attr-defined]
    except AttributeError:  # pragma: no cover - fallback during runtime oddities
        from celery import current_app as app  # type: ignore  # noqa: WPS433

    try:
        inspector = app.control.inspect(timeout=timeout)  # type: ignore[attr-defined]
        if not inspector:
            return False
        ping = inspector.ping()
        return bool(ping)
    except Exception as exc:  # pragma: no cover - defensive logging
        logger.debug("Celery inspector ping failed: %s", exc, exc_info=True)
        return False