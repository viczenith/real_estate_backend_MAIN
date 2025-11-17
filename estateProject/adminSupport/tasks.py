import logging
from datetime import date
from django.conf import settings

from django.utils import timezone
from django.contrib.auth import get_user_model
from django.db import transaction, IntegrityError
from django.core.mail import EmailMultiAlternatives
from django.db import transaction
from django.template.loader import render_to_string

from .models import *
from .utils import *

logger = logging.getLogger(__name__)
User = get_user_model()

try:
    from celery import shared_task
    CELERY_AVAILABLE = True
except Exception:
    CELERY_AVAILABLE = False


def users_with_birthday_today(audience='all', celebrate_feb29_on_feb28=True):
    """
    Return queryset/list of users whose birthday falls on today's month/day.

    - audience: 'clients' | 'marketers' | 'all'
    - celebrate_feb29_on_feb28: if True, users born on Feb 29 will be included on Feb 28 in non-leap years.
    """
    today = timezone.localdate()
    qs = User.objects.all()
    if audience == 'clients':
        qs = qs.filter(role='client')
    elif audience == 'marketers':
        qs = qs.filter(role='marketer')
    elif audience in ('royal_elite', 'estate_ambassador'):
        # segment within clients by rank
        qs = qs.filter(role='client')
        # annotate via ClientUser rank_tag property
        # We cannot annotate Python property easily; filter in Python below

    matches = []
    is_leap_year = (today.year % 4 == 0 and (today.year % 100 != 0 or today.year % 400 == 0))

    for u in qs:
        dob = getattr(u, 'date_of_birth', None)
        if not dob:
            continue

        try:
            # direct match
            if dob.month == today.month and dob.day == today.day:
                # for segmented audiences, enforce rank condition
                if audience == 'royal_elite':
                    try:
                        if getattr(u, 'clientuser', None) and u.clientuser.rank_tag == 'Royal Elite':
                            matches.append(u)
                    except Exception:
                        pass
                elif audience == 'estate_ambassador':
                    try:
                        if getattr(u, 'clientuser', None) and u.clientuser.rank_tag == 'Estate Ambassador':
                            matches.append(u)
                    except Exception:
                        pass
                else:
                    matches.append(u)
                continue

            # handle Feb 29 birthdays in non-leap years (optional)
            if celebrate_feb29_on_feb28 and dob.month == 2 and dob.day == 29 and not is_leap_year:
                # include on Feb 28
                if today.month == 2 and today.day == 28:
                    if audience == 'royal_elite':
                        try:
                            if getattr(u, 'clientuser', None) and u.clientuser.rank_tag == 'Royal Elite':
                                matches.append(u)
                        except Exception:
                            pass
                    elif audience == 'estate_ambassador':
                        try:
                            if getattr(u, 'clientuser', None) and u.clientuser.rank_tag == 'Estate Ambassador':
                                matches.append(u)
                        except Exception:
                            pass
                    else:
                        matches.append(u)
                    continue
        except Exception:
            # skip malformed entries
            continue

    return matches


def run_send_birthday_messages():
    """
    Worker that:
      - reads messaging settings (auto_birthday toggle)
      - for each enabled BirthdayTemplate:
          - computes recipients who have birthday today
          - creates aggregated OutboundMessage
          - creates per-recipient OutboundMessageItem rows
          - attempts to send (email / sms / inapp)
          - marks per-item status and updates aggregated status
    Returns summary dict.
    """
    res = {'templates': 0, 'outbounds_created': 0, 'items_created': 0, 'sent': 0, 'failed': 0, 'skipped': False}

    # Use MessagingSettings singleton (get_or_create ensures a row exists)
    try:
        settings_obj, _created = MessagingSettings.objects.get_or_create(pk=1)
    except Exception as exc:
        # If settings table missing for any reason, log and continue (assume enabled)
        logger.exception("run_send_birthday_messages: failed to get MessagingSettings, assuming enabled. Error: %s", exc)
        settings_obj = None

    # If settings present and auto_birthday disabled, skip processing
    if settings_obj is not None and not getattr(settings_obj, 'auto_birthday', True):
        res['skipped'] = True
        return res

    now = timezone.now()
    templates = BirthdayTemplate.objects.filter(enabled=True, template_type=BirthdayTemplate.TEMPLATE_TYPE_BIRTHDAY)

    for tpl in templates:
        res['templates'] += 1
        try:
            recipients = users_with_birthday_today(tpl.audience)
        except Exception as e:
            logger.exception("Error computing recipients for template %s: %s", getattr(tpl, 'id', tpl), e)
            recipients = []

        if not recipients:
            continue

        # Create aggregated OutboundMessage + per-recipient items in a transaction
        try:
            with transaction.atomic():
                om = OutboundMessage.objects.create(
                    channel=tpl.channel,
                    audience=tpl.audience,
                    subject=(tpl.subject or tpl.name or "Happy Birthday"),
                    body=(tpl.message or ''),
                    created_by=None,
                    scheduled_for=now,
                    status='queued',
                    message_type='birthday',
                    recipients_count=len(recipients),
                    recipients_sample=[f"{u.first_name or ''} {u.last_name or ''}".strip() for u in recipients[:3]],
                )
                res['outbounds_created'] += 1

                # Prepare items
                items = []
                for user in recipients:
                    subj = substitute_placeholders(tpl.subject or tpl.name or '', user)
                    body = substitute_placeholders(tpl.message or '', user)
                    items.append(OutboundMessageItem(
                        outbound=om,
                        recipient=user,
                        channel=tpl.channel,
                        subject=subj,
                        body=body,
                        status='queued'
                    ))

                # bulk_create with compatibility fallback
                created_items_count = 0
                if items:
                    try:
                        # Preferred: ignore_conflicts if available (Django 2.2+)
                        OutboundMessageItem.objects.bulk_create(items, ignore_conflicts=True)
                        created_items_count = len(items)
                    except TypeError:
                        # older Django where ignore_conflicts not supported: try plain bulk_create
                        try:
                            OutboundMessageItem.objects.bulk_create(items)
                            created_items_count = len(items)
                        except IntegrityError:
                            # fallback: create one-by-one, ignoring duplicates
                            created_items_count = 0
                            for it in items:
                                try:
                                    OutboundMessageItem.objects.create(
                                        outbound=it.outbound,
                                        recipient=it.recipient,
                                        channel=it.channel,
                                        subject=it.subject,
                                        body=it.body,
                                        status=it.status
                                    )
                                    created_items_count += 1
                                except IntegrityError:
                                    # likely unique constraint conflict; ignore
                                    continue

                res['items_created'] += created_items_count

        except Exception as exc:
            logger.exception("Failed to create OutboundMessage/items for template %s: %s", getattr(tpl, 'id', tpl), exc)
            # skip sending for this template
            continue

        # Send each item (iterate items from DB)
        try:
            items_qs = om.items.select_related('recipient').filter(status='queued')
        except Exception:
            # fallback to all items
            items_qs = om.items.select_related('recipient').all()

        for item in items_qs:
            try:
                ok = False
                err = None
                if item.channel == 'email':
                    ok, err = send_email_message(item.subject or 'PrimeEstate NG', item.body, getattr(item.recipient, 'email', None))
                elif item.channel == 'sms':
                    ok, err = send_sms_message(item.body, getattr(item.recipient, 'phone', None))
                else:
                    ok, err = send_inapp_message(item.body, item.recipient)

                if ok:
                    try:
                        item.mark_sent()
                    except Exception:
                        # fallback: update fields directly
                        item.status = 'sent'
                        item.sent_at = timezone.now() if hasattr(item, 'sent_at') else None
                        item.save(update_fields=['status'])
                    res['sent'] += 1
                else:
                    try:
                        item.mark_failed(error_text=err)
                    except Exception:
                        item.status = 'failed'
                        item.error = str(err) if err else ''
                        item.save(update_fields=['status', 'error'])
                    res['failed'] += 1

            except Exception as exc:
                logger.exception("Error sending OutboundMessageItem id=%s: %s", getattr(item, 'pk', None), exc)
                try:
                    item.mark_failed(error_text=str(exc))
                except Exception:
                    item.status = 'failed'
                    try:
                        item.save(update_fields=['status'])
                    except Exception:
                        pass
                res['failed'] += 1

        # Recalculate aggregated status
        try:
            total_items = om.items.count()
            total_failed = om.items.filter(status='failed').count()
            total_sent = om.items.filter(status='sent').count()

            # Determine final status: if everything failed -> failed; if any sent -> sent (we mark sent_at)
            if total_items == 0:
                om.status = 'queued'
            elif total_failed == total_items:
                om.status = 'failed'
            else:
                # some or all sent -> treat as sent (you may want a 'partial' state)
                om.status = 'sent' if total_sent > 0 else 'queued'

            if total_sent > 0:
                om.sent_at = timezone.now()

            om.save(update_fields=['status', 'sent_at'])
        except Exception as exc:
            logger.exception("Failed to finalize OutboundMessage status for id=%s: %s", getattr(om, 'id', None), exc)

    return res


def users_for_special_day(audience='all', users_list=None):
    qs = User.objects.all()
    if audience == 'clients':
        qs = qs.filter(role='client')
    elif audience == 'marketers':
        qs = qs.filter(role='marketer')
    return qs

def run_send_special_day_messages():
    res = {'templates': 0, 'outbounds_created': 0, 'items_created': 0, 'sent': 0, 'failed': 0}
    setting = AutoSpecialSetting.objects.first()
    if setting and not setting.enabled:
        return {**res, 'skipped': True}

    now = timezone.now()
    templates = BirthdayTemplate.objects.filter(enabled=True, template_type=BirthdayTemplate.TEMPLATE_TYPE_SPECIAL)
    for tpl in templates:
        res['templates'] += 1
        recipients = users_for_special_day(tpl.audience)
        if not recipients.exists():
            continue

        om = OutboundMessage.objects.create(
            channel=tpl.channel,
            audience=tpl.audience,
            subject=(tpl.subject or tpl.name or "Special Day Message"),
            body=(tpl.message or ''),
            created_by=None,
            scheduled_for=now,
            status='queued',
            message_type='special_day',
            recipients_count=recipients.count(),
            recipients_sample=[f"{u.first_name or ''} {u.last_name or ''}".strip() for u in recipients[:3]],
        )

        res['outbounds_created'] += 1

        items = []
        for u in recipients:
            subj = substitute_placeholders(tpl.subject or tpl.name or '', u)
            body = substitute_placeholders(tpl.message or '', u)
            items.append(OutboundMessageItem(
                outbound=om,
                recipient=u,
                channel=tpl.channel,
                subject=subj,
                body=body,
                status='queued'
            ))
        OutboundMessageItem.objects.bulk_create(items, ignore_conflicts=True)
        res['items_created'] += len(items)

        for item in om.items.select_related('recipient').all():
            try:
                ok, err = False, None
                if item.channel == 'email':
                    ok, err = send_email_message(item.subject or 'PrimeEstate NG', item.body, item.recipient.email)
                elif item.channel == 'sms':
                    ok, err = send_sms_message(item.body, item.recipient.phone)
                else:
                    ok, err = send_inapp_message(item.body, item.recipient)
                if ok:
                    item.mark_sent(); res['sent'] += 1
                else:
                    item.mark_failed(error_text=err); res['failed'] += 1
            except Exception as e:
                logger.exception("Error sending special outbound item id=%s", item.pk)
                item.mark_failed(error_text=str(e)); res['failed'] += 1

        total_items = om.items.count()
        total_failed = om.items.filter(status='failed').count()
        total_sent = om.items.filter(status='sent').count()
        if total_failed == 0 and total_sent > 0:
            om.status = 'sent'; om.sent_at = timezone.now()
        elif total_sent > 0 and total_failed > 0:
            om.status = 'sent'; om.sent_at = timezone.now()
        else:
            om.status = 'failed' if total_failed == total_items else 'queued'
            if total_sent > 0:
                om.sent_at = timezone.now()
        om.save(update_fields=['status', 'sent_at'])

    return res

# NEWSLETTER
from typing import List, Tuple

# Tunables
MAX_RECIPIENTS = getattr(settings, "NEWSLETTER_MAX_RECIPIENTS", 5000)
BATCH_SIZE = getattr(settings, "NEWSLETTER_BATCH_SIZE", 100)

def _get_recipient_qs(audience):
    """Return queryset filtered by audience and with non-empty email."""
    if audience == 'clients':
        return User.objects.filter(role='client').exclude(email__isnull=True).exclude(email__exact='')
    if audience == 'marketers':
        return User.objects.filter(role='marketer').exclude(email__isnull=True).exclude(email__exact='')
    return User.objects.exclude(email__isnull=True).exclude(email__exact='')


def _send_batch_emails(from_email: str, subject: str, html_body: str, recipients: List[Tuple[str, str]]) -> Tuple[int, List[dict]]:
    """
    Send emails. recipients is list of tuples (email, full_name).
    This implementation sends one email per recipient (personalized "to").
    Returns (sent_count, errors_list).
    NOTE: For production/bulk, replace this with your mail provider's bulk API.
    """
    sent = 0
    errors = []

    for email, name in recipients:
        try:
            plain_text = ''
            msg = EmailMultiAlternatives(
                subject=subject,
                body=plain_text or subject,
                from_email=from_email,
                to=[email]
            )
            msg.attach_alternative(html_body, "text/html")
            msg.send(fail_silently=False)
            sent += 1
        except Exception as exc:
            logger.exception("Failed to send newsletter to %s", email)
            errors.append({'email': email, 'error': str(exc)})

    return sent, errors


def _perform_send(campaign_id: str) -> dict:
    """
    Load campaign, compute recipients, create OutboundMessage entry and send in batches.
    Returns summary dict.
    """
    try:
        campaign = NewsletterCampaign.objects.get(id=campaign_id)
    except NewsletterCampaign.DoesNotExist:
        logger.error("NewsletterCampaign not found: %s", campaign_id)
        return {'ok': False, 'error': 'campaign not found'}

    # Mark sending
    campaign.status = NewsletterCampaign.STATUS_SENDING
    campaign.save(update_fields=['status'])

    # Gather recipients (limit for safety)
    qs = _get_recipient_qs(campaign.audience)
    total_recipients = qs.count()
    limited_count = min(total_recipients, MAX_RECIPIENTS)

    # Fetch sample & recipients (we fetch limited_count recipients to avoid OOM)
    sample_qs = qs.order_by('id')[:5].values_list('first_name', 'last_name', 'email')
    sample_list = [f"{(a or '').strip()} {(b or '').strip()}".strip() + (f" <{c}>" if c else '') for a, b, c in sample_qs]

    # Update campaign recipients summary
    campaign.recipients_count = total_recipients
    campaign.recipients_sample = sample_list
    campaign.save(update_fields=['recipients_count', 'recipients_sample'])

    # Create OutboundMessage row for UI/traceability
    om = OutboundMessage.objects.create(
        channel='email',
        audience=campaign.audience,
        subject=campaign.subject,
        body=campaign.html_body,
        created_by=campaign.created_by,
        recipients_count=campaign.recipients_count,
        recipients_sample=campaign.recipients_sample,
        scheduled_for=campaign.scheduled_for,
        status='sending'
    )

    # Prepare list of recipients (email, fullname) up to MAX_RECIPIENTS
    # We will chunk them in batches to send.
    recipients_tuples = []
    for a, b, c in qs.order_by('id').values_list('first_name', 'last_name', 'email')[:limited_count]:
        if not c:
            continue
        fullname = f"{(a or '').strip()} {(b or '').strip()}".strip()
        recipients_tuples.append((c, fullname))

    total_to_send = len(recipients_tuples)
    overall_sent = 0
    overall_errors = []

    from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@example.com')

    # Send in batches
    idx = 0
    while idx < total_to_send:
        batch = recipients_tuples[idx: idx + BATCH_SIZE]
        try:
            sent, errors = _send_batch_emails(from_email, campaign.subject, campaign.html_body, batch)
            overall_sent += sent
            overall_errors.extend(errors)
        except Exception as exc:
            logger.exception("Error sending batch starting at %s: %s", idx, exc)
            # Record as errors for each recipient in batch
            for recipient_email, _ in batch:
                overall_errors.append({'email': recipient_email, 'error': str(exc)})
        idx += BATCH_SIZE

    # Finalize statuses
    om.status = 'sent' if not overall_errors else 'failed'
    om.sent_at = timezone.now()
    om.save(update_fields=['status', 'sent_at'])

    campaign.status = NewsletterCampaign.STATUS_SENT if not overall_errors else NewsletterCampaign.STATUS_FAILED
    campaign.sent_at = timezone.now()
    campaign.error = None if not overall_errors else str(overall_errors[:6])
    campaign.save(update_fields=['status', 'sent_at', 'error'])

    logger.info("Newsletter campaign %s completed: sent=%s errors=%s", campaign.id, overall_sent, len(overall_errors))

    return {'ok': True, 'sent': overall_sent, 'errors': overall_errors[:10], 'outbound_id': str(om.id)}


# Exported task/function: either a Celery task or a plain function fallback
try:
    from celery import shared_task  # type: ignore
    CELERY_AVAILABLE = True
except Exception:
    shared_task = None
    CELERY_AVAILABLE = False

if CELERY_AVAILABLE and shared_task is not None:
    @shared_task(bind=False)
    def send_newsletter_task(campaign_id):
        """Celery task wrapper"""
        return _perform_send(campaign_id)
else:
    def send_newsletter_task(campaign_id):
        """Synchronous fallback callable"""
        return _perform_send(campaign_id)


        