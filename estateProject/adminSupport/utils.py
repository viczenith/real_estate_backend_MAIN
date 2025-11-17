import re
import logging
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from .models import InAppMessage, InboxEntry
logger = logging.getLogger(__name__)

PLACEHOLDER_RE = re.compile(r'\{(\w+)\}')


def substitute_placeholders(template_text: str, user):
    """
    Replace placeholders like {firstName}, {lastName}, {fullName}, {email}, {phone}, {role}
    using the project's CustomUser fields.
    """
    if template_text is None:
        return ''

    mapping = {
        'firstName': getattr(user, 'first_name', '') or (getattr(user, 'full_name', '').split()[0] if getattr(user, 'full_name', None) else ''),
        'lastName': getattr(user, 'last_name', '') or '',
        'fullName': getattr(user, 'full_name', '') or f"{getattr(user,'first_name','')} {getattr(user,'last_name','')}".strip(),
        'email': getattr(user, 'email', '') or '',
        'phone': getattr(user, 'phone', '') or '',
        'role': getattr(user, 'role', '') or '',
    }

    def repl(m):
        key = m.group(1)
        return str(mapping.get(key, ''))

    return PLACEHOLDER_RE.sub(repl, template_text)


def send_email_message(subject, body, recipient_email):
    """
    Uses Django's send_mail to send an email. Returns (True, None) on success,
    (False, error_text) on failure.
    """
    if not recipient_email:
        return False, "No recipient email"
    try:
        send_mail(
            subject or settings.DEFAULT_FROM_EMAIL,
            body or '',
            settings.DEFAULT_FROM_EMAIL,
            [recipient_email],
            fail_silently=False
        )
        return True, None
    except Exception as e:
        logger.exception("Failed to send email to %s", recipient_email)
        return False, str(e)


def send_sms_message(body, phone_number):
    """
    Placeholder for SMS gateway integration. Returns (True, None) on simulated success.
    Replace with real provider code (e.g., Twilio, Africa's Talking, etc).
    """
    if not phone_number:
        return False, "No phone number"
    try:
        # TODO: integrate third-party SMS provider here
        # For now we simulate success.
        return True, None
    except Exception as e:
        logger.exception("Failed to send SMS to %s", phone_number)
        return False, str(e)


def send_inapp_message(body, user):
    """
    Create an InAppMessage and an InboxEntry for the user.
    Returns (True, None) on success, (False, error_text) on failure.
    """
    if user is None:
        return False, "No user provided"

    try:
        with transaction.atomic():
            msg = InAppMessage.objects.create(sender=None, subject=None, body=body or '', is_draft=False)
            # attach recipient(s)
            msg.recipients.add(user)
            # create InboxEntry row for the user
            InboxEntry.objects.create(user=user, message=msg)
        return True, None
    except Exception as e:
        logger.exception("Failed to create in-app message for user %s", getattr(user, 'id', None))
        return False, str(e)
