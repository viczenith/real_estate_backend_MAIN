from datetime import timedelta

from django.db.models import Q
from django.http import Http404
from django.template.loader import render_to_string
from django.utils import timezone

from rest_framework import permissions, status
from rest_framework.authentication import SessionAuthentication, TokenAuthentication
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from estateApp.models import CustomUser, Message
from DRF.admin_support.serializers.chat_serializers import (
    SupportMessageCreateSerializer,
    SupportMessageListSerializer,
    SupportMessageSerializer,
)

SUPPORT_ROLES = ("admin", "support")


class SupportAgentPermission(permissions.BasePermission):
    """Ensure the authenticated user is a support agent or admin."""

    def has_permission(self, request, view):  # pragma: no cover - simple predicate
        user = request.user
        if not (user and user.is_authenticated):
            return False
        role = getattr(user, "role", None)
        return role in SUPPORT_ROLES or getattr(user, "is_staff", False)


def _normalize_role(role: str) -> str:
    normalized = (role or "").lower()
    if normalized not in {"client", "marketer"}:
        raise Http404("Unsupported conversation role")
    return normalized


def _get_participant(role: str, participant_id: int) -> CustomUser:
    normalized = _normalize_role(role)
    try:
        return CustomUser.objects.get(id=participant_id, role=normalized)
    except CustomUser.DoesNotExist as exc:  # pragma: no cover - defensive
        raise Http404("Participant not found") from exc


def _conversation_queryset(participant: CustomUser):
    return (
        Message.objects.filter(
            Q(sender=participant, recipient__role__in=SUPPORT_ROLES)
            | Q(sender__role__in=SUPPORT_ROLES, recipient=participant)
        )
        .select_related("sender", "recipient")
        .order_by("date_sent")
    )


def _serialize_participant(participant: CustomUser, request) -> dict:
    avatar_url = None
    if getattr(participant, "profile_image", None):
        url = participant.profile_image.url
        if request and url and not url.startswith("http"):
            avatar_url = request.build_absolute_uri(url)
        else:
            avatar_url = url

    full_name = (
        participant.full_name
        or participant.get_full_name()
        or participant.username
        or "Unnamed"
    )

    initials = "".join([chunk[:1] for chunk in full_name.split()[:2]]).upper()

    last_seen = (
        participant.last_login
        or getattr(participant, "last_message_at", None)
        or participant.date_registered
    )

    return {
        "id": participant.id,
        "full_name": full_name,
        "email": participant.email,
        "role": participant.role,
        "avatar_url": avatar_url,
        "initials": initials,
        "last_seen": last_seen.isoformat() if last_seen else None,
    }


def _render_messages_html(messages, request) -> str:
    fragments = []
    for message in messages:
        fragments.append(
            render_to_string(
                "adminSupport/chat_message.html",
                {"msg": message, "request": request},
            )
        )
    return "".join(fragments)


class SupportChatThreadAPIView(APIView):
    """Fetch or send messages for a support conversation."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (SupportAgentPermission,)
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def get(self, request, role: str, participant_id: int):
        participant = _get_participant(role, participant_id)
        queryset = _conversation_queryset(participant)

        last_msg_id = request.query_params.get("last_msg_id")
        if last_msg_id:
            try:
                queryset = queryset.filter(id__gt=int(last_msg_id))
            except (TypeError, ValueError):
                queryset = queryset.none()

        messages = list(queryset)

        if messages:
            participant_message_ids = [
                msg.id for msg in messages if msg.sender_id == participant.id
            ]
            if participant_message_ids:
                Message.objects.filter(
                    id__in=participant_message_ids,
                    sender=participant,
                    recipient__role__in=SUPPORT_ROLES,
                    is_read=False,
                ).update(is_read=True, status="read")

        serializer = SupportMessageListSerializer(
            messages, many=True, context={"request": request}
        )

        return Response(
            {
                "participant": _serialize_participant(participant, request),
                "count": len(messages),
                "messages": serializer.data,
                "messages_html": _render_messages_html(messages, request),
                "last_message_id": messages[-1].id if messages else None,
            }
        )

    def post(self, request, role: str, participant_id: int):
        participant = _get_participant(role, participant_id)
        serializer = SupportMessageCreateSerializer(
            data=request.data,
            context={"request": request, "participant": participant},
        )
        if not serializer.is_valid():
            return Response(
                {"success": False, "errors": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        message = serializer.save()
        detail_serializer = SupportMessageSerializer(
            message, context={"request": request}
        )

        return Response(
            {
                "success": True,
                "message": detail_serializer.data,
                "message_html": _render_messages_html([message], request),
            },
            status=status.HTTP_201_CREATED,
        )


class SupportChatPollAPIView(APIView):
    """Return new messages for a support conversation since last_msg_id."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (SupportAgentPermission,)

    def get(self, request, role: str, participant_id: int):
        participant = _get_participant(role, participant_id)
        try:
            last_msg_id = int(request.query_params.get("last_msg_id", 0))
        except (TypeError, ValueError):  # pragma: no cover - defensive
            last_msg_id = 0

        queryset = _conversation_queryset(participant).filter(id__gt=last_msg_id)
        messages = list(queryset)

        if messages:
            participant_message_ids = [
                msg.id for msg in messages if msg.sender_id == participant.id
            ]
            if participant_message_ids:
                Message.objects.filter(
                    id__in=participant_message_ids,
                    sender=participant,
                    recipient__role__in=SUPPORT_ROLES,
                    is_read=False,
                ).update(is_read=True, status="read")

        serializer = SupportMessageListSerializer(
            messages, many=True, context={"request": request}
        )

        updated_statuses = list(
            Message.objects.filter(
                sender__role__in=SUPPORT_ROLES,
                recipient=participant,
            ).values("id", "status")
        )

        return Response(
            {
                "count": len(messages),
                "new_messages": serializer.data,
                "new_messages_html": _render_messages_html(messages, request),
                "updated_statuses": updated_statuses,
                "last_message_id": messages[-1].id if messages else last_msg_id,
            }
        )


class SupportChatMarkReadAPIView(APIView):
    """Mark messages in a conversation as read."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (SupportAgentPermission,)

    def post(self, request, role: str, participant_id: int):
        participant = _get_participant(role, participant_id)
        message_ids = request.data.get("message_ids")
        mark_all = request.data.get("mark_all", False)

        queryset = Message.objects.filter(
            sender=participant,
            recipient__role__in=SUPPORT_ROLES,
            is_read=False,
        )

        if message_ids and not mark_all:
            if not isinstance(message_ids, (list, tuple)):
                return Response(
                    {"success": False, "error": "message_ids must be a list."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            queryset = queryset.filter(id__in=message_ids)

        updated = queryset.update(is_read=True, status="read")
        return Response({"success": True, "updated": updated})


class SupportChatDeleteMessageAPIView(APIView):
    """Allow support agents to delete a message for everyone within 24 hours."""

    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (SupportAgentPermission,)

    def delete(self, request, pk: int):
        try:
            message = Message.objects.select_related("sender", "recipient").get(pk=pk)
        except Message.DoesNotExist:
            return Response(
                {"success": False, "error": "Message not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if message.sender != request.user and message.recipient != request.user:
            return Response(
                {"success": False, "error": "You do not have permission to delete this message."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if message.date_sent < timezone.now() - timedelta(hours=24):
            return Response(
                {"success": False, "error": "Messages can only be deleted within 24 hours."},
                status=status.HTTP_403_FORBIDDEN,
            )

        message.deleted_for_everyone = True
        message.deleted_for_everyone_at = timezone.now()
        message.deleted_for_everyone_by = request.user
        message.save(update_fields=[
            "deleted_for_everyone",
            "deleted_for_everyone_at",
            "deleted_for_everyone_by",
        ])

        serializer = SupportMessageSerializer(message, context={"request": request})
        return Response({"success": True, "message": serializer.data})
