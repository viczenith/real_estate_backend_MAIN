import uuid
from django.conf import settings
from django.db import models
from django.utils import timezone
from django.core.exceptions import ValidationError


AUTH_USER_MODEL = settings.AUTH_USER_MODEL

CHANNEL_CHOICES = [
    ('inapp', 'In-App'),
    ('sms', 'SMS'),
    ('email', 'Email'),
    ('whatsapp', 'WhatsApp'),
    ('push', 'Push Notification'),
    ('multi', 'Multi-Channel'),
]

AUDIENCE_CHOICES = [
    ('all', 'All Users'),
    ('clients', 'Clients'),
    ('marketers', 'Marketers'),
    ('top_clients', 'VIP Clients'),
    ('new_clients', 'New Clients'),
    ('inactive_clients', 'Inactive Clients'),
    ('top_marketers', 'Top Performers'),
    ('new_marketers', 'New Marketers'),
    ('residential_marketers', 'Residential Specialists'),
    ('commercial_marketers', 'Commercial Specialists'),
]

TRIGGER_TYPES = [
    ('birthday', 'Birthday'),
    ('anniversary', 'Work Anniversary'),
    ('special_day', 'Special Day/Holiday'),
    ('milestone', 'Achievement Milestone'),
    ('follow_up', 'Follow-up Sequence'),
    ('property_alert', 'Property Alert'),
    ('market_update', 'Market Update'),
    ('commission_alert', 'Commission Alert'),
]

SPECIAL_DAYS = [
    ('new_year', 'New Year'),
    ('valentine', 'Valentine\'s Day'),
    ('mothers_day', 'Mother\'s Day'),
    ('fathers_day', 'Father\'s Day'),
    ('workers_day', 'Workers\' Day'),
    ('children_day', 'Children\'s Day'),
    ('independence_day', 'Independence Day'),
    ('christmas', 'Christmas'),
    ('boxing_day', 'Boxing Day'),
    ('eid_fitr', 'Eid al-Fitr'),
    ('eid_adha', 'Eid al-Adha'),
    ('ramadan_start', 'Ramadan Start'),
    ('easter', 'Easter'),
    ('good_friday', 'Good Friday'),
    ('custom', 'Custom Event'),
]

THEME_TYPES = [
    ('default', 'Default'),
    ('holiday', 'Holiday'),
    ('seasonal', 'Seasonal'),
    ('campaign', 'Campaign'),
    ('special', 'Special Highlight'),
]

OUTBOUND_STATUS = [
    ('queued', 'Queued'),
    ('sending', 'Sending'),
    ('sent', 'Sent'),
    ('delivered', 'Delivered'),
    ('failed', 'Failed'),
    ('cancelled', 'Cancelled'),
]

class MessageTemplate(models.Model):
    """
    Reusable templates for broadcasts or scheduled sends.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    channel = models.CharField(max_length=10, choices=CHANNEL_CHOICES, default='inapp')
    audience = models.CharField(max_length=30, choices=AUDIENCE_CHOICES, default='clients')
    subject = models.CharField(max_length=255, blank=True, null=True)
    body = models.TextField()

    enabled = models.BooleanField(default=True)

    send_time = models.TimeField(blank=True, null=True, help_text="Optional daily send time (local)")
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='support_created_templates')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['is_active', 'channel']),
        ]
        verbose_name = "Message Template"
        verbose_name_plural = "Message Templates"

    def __str__(self):
        return f"{self.name} · {self.get_channel_display()} · [{self.channel}]"


class OutboundMessage(models.Model):
    """
    A queue entry representing a broadcast or scheduled send.
    A worker (Celery/RQ) should pick queued rows and process them.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    channel = models.CharField(max_length=10, choices=CHANNEL_CHOICES, default='inapp')
    audience = models.CharField(max_length=30, choices=AUDIENCE_CHOICES, default='clients')
    subject = models.CharField(max_length=255, blank=True, null=True)
    body = models.TextField()
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='support_outbounds')
    scheduled_for = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=OUTBOUND_STATUS, default='queued')
    message_type = models.CharField(max_length=30, default='generic', db_index=True,
                                    help_text="Categorizes the automation source (e.g., birthday, special_day, newsletter)")
    recipients_count = models.PositiveIntegerField(default=0)
    recipients_sample = models.JSONField(default=list, blank=True, help_text="Small sample for preview")

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Outbound Message"
        verbose_name_plural = "Outbound Messages"

    def __str__(self):
        return f"{self.get_channel_display()} → {self.recipients_count} ({self.status})"


class SupportConversation(models.Model):
    """
    Conversation between support (or staff) and one or more users.
    Each conversation is a thread; support staff can reply, etc.
    """
    subject = models.CharField(max_length=255, blank=True, null=True)
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='support_started_conversations')
    participants = models.ManyToManyField(AUTH_USER_MODEL, related_name='support_conversations', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Support Conversation"
        verbose_name_plural = "Support Conversations"

    def __str__(self):
        return f"Conv: {self.subject or self.pk}"


class SupportMessage(models.Model):
    """
    Chat messages inside a SupportConversation — stores status, reply-to and attachments.
    Note: the estate app already has a Message model; this is an explicit support chat.
    """
    conversation = models.ForeignKey(SupportConversation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='support_sent_messages')
    body = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_system = models.BooleanField(default=False)
    reply_to = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='replies')
    # message delivery/read status stored per recipient in SupportMessageReceipt
    attachments = models.JSONField(default=list, blank=True, help_text="Attachment metadata list")

    class Meta:
        ordering = ['created_at']
        verbose_name = "Support Message"
        verbose_name_plural = "Support Messages"

    def __str__(self):
        who = self.sender.get_full_name() if self.sender else "System"
        body_preview = (self.body[:60] + '...') if self.body and len(self.body) > 60 else (self.body or '')
        return f"{who}: {body_preview}"


class SupportMessageReceipt(models.Model):
    """
    Per-user read/delivery status for SupportMessage.
    """
    message = models.ForeignKey(SupportMessage, on_delete=models.CASCADE, related_name='receipts')
    user = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='support_receipts')
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['message', 'user'], name='unique_message_user_receipt')
        ]
        verbose_name = "Support Message Receipt"
        verbose_name_plural = "Support Message Receipts"

    def save(self, *args, **kwargs):
        # If being marked read now and read_at not set, set timestamp
        if self.is_read and self.read_at is None:
            self.read_at = timezone.now()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Receipt: msg={self.message_id} user={self.user_id} read={self.is_read}"


class InAppMessage(models.Model):
    """
    Standalone in-app message (broadcast or admin-sent) persisted to recipients' inboxes.
    This differs from conversation messages which are threaded.
    """
    sender = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='support_inapp_sent')
    recipients = models.ManyToManyField(AUTH_USER_MODEL, related_name='support_inapp_inbox', blank=True)
    subject = models.CharField(max_length=255, blank=True, null=True)
    body = models.TextField()
    is_draft = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    scheduled_for = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "In-App Message"
        verbose_name_plural = "In-App Messages"

    def __str__(self):
        return f"InApp: {self.subject or '(no subject)'}"


class InboxEntry(models.Model):
    """
    per-user inbox entry / read status for InAppMessage.
    """
    user = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='support_inbox_entries')
    message = models.ForeignKey(InAppMessage, on_delete=models.CASCADE, related_name='entries')
    is_read = models.BooleanField(default=False)
    archived = models.BooleanField(default=False)
    last_read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['user', 'message'], name='unique_inbox_user_message')
        ]
        ordering = ['-message__created_at']
        verbose_name = "Inbox Entry"
        verbose_name_plural = "Inbox Entries"

    def mark_read(self):
        if not self.is_read:
            self.is_read = True
            self.last_read_at = timezone.now()
            self.save(update_fields=['is_read', 'last_read_at'])


class StaffRoster(models.Model):
    """
    Tracks internal staff members managed by the adminSupport module.
    This is the authoritative list used by the Staff Directory; it prevents
    leaking clients/marketers/other app users into staff views.
    """
    user = models.OneToOneField(
        AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='staff_roster'
    )
    active = models.BooleanField(default=True)
    created_by = models.ForeignKey(
        AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='staff_roster_created'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['active']),
        ]
        verbose_name = 'Staff Roster Entry'
        verbose_name_plural = 'Staff Roster'

    def __str__(self):
        return f"Staff: {getattr(self.user, 'email', self.user_id)} ({'active' if self.active else 'inactive'})"


class StaffMember(models.Model):
    """
    Independent staff directory record, decoupled from estateApp users.
    Only records created via Add Staff modal or CSV/Excel import should appear
    in the Staff Directory. This model is the single source of truth for that UI.
    """
    full_name = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=50, blank=True)
    whatsapp = models.CharField(max_length=50, blank=True, help_text='WhatsApp number (optional)')
    address = models.CharField(max_length=255, blank=True)
    role = models.CharField(max_length=120, blank=True, help_text='Role/Position')
    employment_date = models.DateField(null=True, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    active = models.BooleanField(default=True)

    created_by = models.ForeignKey(
        AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='adminsupport_created_staff'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Staff Member'
        verbose_name_plural = 'Staff Members'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['active']),
            models.Index(fields=['role']),
            models.Index(fields=['email']),
        ]


class ActivityLog(models.Model):
    """
    Human-readable activity items for the dashboard.
    """
    actor = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='support_activities')
    action = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Activity Log"
        verbose_name_plural = "Activity Logs"

    def __str__(self):
        who = self.actor.get_full_name() if self.actor else "System"
        return f"{who}: {self.action[:120]}"


class ScheduledTrigger(models.Model):
    """
    Triggers convert templates into OutboundMessage entries when run.
    For serious scheduling use Celery + periodic tasks; this model allows manual/one-shot triggers.
    """
    template = models.ForeignKey(MessageTemplate, on_delete=models.CASCADE, related_name='scheduled_triggers')
    enabled = models.BooleanField(default=True)
    daily = models.BooleanField(default=False)
    time_of_day = models.TimeField(blank=True, null=True)
    one_shot_at = models.DateTimeField(blank=True, null=True)
    last_run = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-id']
        verbose_name = "Scheduled Trigger"
        verbose_name_plural = "Scheduled Triggers"

    def __str__(self):
        mode = 'daily' if self.daily else 'one-shot'
        return f"Trigger {self.template.name} · {mode}"


#BIRTHDAT TEMPLATE
class BirthdayTemplate(models.Model):
    CHANNEL_SMS = 'sms'
    CHANNEL_EMAIL = 'email'
    CHANNEL_INAPP = 'inapp'
    CHANNEL_CHOICES = [
        (CHANNEL_SMS, 'SMS'),
        (CHANNEL_EMAIL, 'Email'),
        (CHANNEL_INAPP, 'In-App'),
    ]

    TEMPLATE_TYPE_BIRTHDAY = 'birthday'
    TEMPLATE_TYPE_SPECIAL = 'special'
    TEMPLATE_TYPE_CHOICES = [
        (TEMPLATE_TYPE_BIRTHDAY, 'Birthday'),
        (TEMPLATE_TYPE_SPECIAL, 'Special Day'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=180, blank=True)
    channel = models.CharField(max_length=16, choices=CHANNEL_CHOICES, default=CHANNEL_SMS)
    audience = models.CharField(max_length=80, default='clients', help_text='Audience (clients/marketers/all)')
    subject = models.CharField(max_length=255, blank=True, null=True, help_text="Optional subject (for email)")
    message = models.TextField()
    time = models.TimeField(null=True, blank=True)
    enabled = models.BooleanField(default=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                   on_delete=models.SET_NULL, related_name='birthday_templates')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # NEW: distinguish birthday vs special-day
    template_type = models.CharField(max_length=20, choices=TEMPLATE_TYPE_CHOICES,
                                     default=TEMPLATE_TYPE_BIRTHDAY)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.name or f'{self.channel} template ({self.template_type})'


class OutboundMessageItem(models.Model):
    STATUS_CHOICES = [
        ('queued', 'Queued'),
        ('sending', 'Sending'),
        ('sent', 'Sent'),
        ('delivered', 'Delivered'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]

    outbound = models.ForeignKey(
        'OutboundMessage',
        on_delete=models.CASCADE,
        related_name='items'
    )
    recipient = models.ForeignKey(
        AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='outbound_items'
    )
    channel = models.CharField(max_length=10, choices=(
        ('inapp','In-App'), ('sms','SMS'), ('email','Email'),
    ), default='inapp')
    subject = models.CharField(max_length=255, blank=True, null=True)
    body = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='queued')
    error = models.TextField(blank=True, null=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Outbound Message Item"
        verbose_name_plural = "Outbound Message Items"
        unique_together = ('outbound', 'recipient')

    def mark_sent(self):
        self.status = 'sent'
        self.sent_at = timezone.now()
        self.save(update_fields=['status','sent_at'])

    def mark_delivered(self):
        self.status = 'delivered'
        self.delivered_at = timezone.now()
        self.save(update_fields=['status','delivered_at'])

    def mark_failed(self, error_text=None):
        self.status = 'failed'
        if error_text:
            self.error = str(error_text)
        self.save(update_fields=['status','error'])


class MessagingSettings(models.Model):
    """
    Singleton-like settings row for messaging features.
    Use: MessagingSettings.objects.get_or_create(pk=1)
    """
    id = models.SmallIntegerField(primary_key=True, default=1)

    # toggles
    auto_birthday = models.BooleanField(default=True)
    auto_special_day = models.BooleanField(default=True)

    # optional: chosen templates for automated sends (nullable FK)
    birthday_template = models.ForeignKey(
        'BirthdayTemplate', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='+'
    )
    special_template = models.ForeignKey(
        'BirthdayTemplate', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='+'
    )

    # per-automation channel/time overrides (optional)
    birthday_channel = models.CharField(max_length=16, choices=[
        ('inapp','In-App'), ('sms','SMS'), ('email','Email')
    ], default='sms')
    special_channel = models.CharField(max_length=16, choices=[
        ('inapp','In-App'), ('sms','SMS'), ('email','Email')
    ], default='email')

    birthday_time = models.TimeField(null=True, blank=True)
    birthday_days_advance = models.PositiveIntegerField(default=0)
    special_time = models.TimeField(null=True, blank=True)

    # newsletter defaults
    newsletter_batch_size = models.PositiveIntegerField(default=50, help_text="Batch size when sending newsletters")
    newsletter_use_celery = models.BooleanField(default=True)
    newsletter_from_email = models.CharField(max_length=255, blank=True, null=True)

    # housekeeping
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Messaging Settings"
        verbose_name_plural = "Messaging Settings"

    def __str__(self):
        return f"MessagingSettings(auto_birthday={self.auto_birthday}, auto_special_day={self.auto_special_day})"


class AutoSpecialSetting(models.Model):
    """
    A tiny singleton-ish model storing whether auto special-day sending is enabled.
    Access with AutoSpecialSetting.objects.get_or_create(pk=1)
    """
    id = models.SmallIntegerField(primary_key=True, default=1)
    enabled = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Auto Special Day Setting"
        verbose_name_plural = "Auto Special Day Settings"

    def __str__(self):
        return "Auto special-day enabled" if self.enabled else "Auto special-day disabled"

# NEWSLETTER
class NewsletterCampaign(models.Model):
    STATUS_DRAFT = "draft"
    STATUS_QUEUED = "queued"
    STATUS_SENDING = "sending"
    STATUS_SENT = "sent"
    STATUS_FAILED = "failed"

    STATUS_CHOICES = [
        (STATUS_DRAFT, "Draft"),
        (STATUS_QUEUED, "Queued"),
        (STATUS_SENDING, "Sending"),
        (STATUS_SENT, "Sent"),
        (STATUS_FAILED, "Failed"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255, blank=True, help_text="Optional internal name")
    subject = models.CharField(max_length=255)
    html_body = models.TextField(help_text="HTML body (editor output)")
    plain_body = models.TextField(blank=True, null=True, help_text="Plain-text alternative (auto-generated if blank)")
    audience = models.CharField(max_length=30, choices=AUDIENCE_CHOICES, default='all', db_index=True)
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='newsletter_campaigns', db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    scheduled_for = models.DateTimeField(null=True, blank=True, db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_DRAFT, db_index=True)
    recipients_count = models.PositiveIntegerField(default=0)
    recipients_sample = models.JSONField(default=list, blank=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    error = models.TextField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Newsletter Campaign"
        verbose_name_plural = "Newsletter Campaigns"

    def __str__(self):
        return f"{(self.name or self.subject)[:60]} ({self.status})"

    def clean(self):
        # scheduled_for can't be in the past if set
        if self.scheduled_for and self.scheduled_for < timezone.now():
            raise ValidationError({"scheduled_for": "scheduled_for cannot be in the past."})

    def ensure_plain_text(self):
        """
        Minimal plain-text extractor from html. You can replace with better library (html2text).
        """
        if not self.plain_body:
            import re
            text = re.sub(r'<script[\s\S]*?</script>', '', self.html_body, flags=re.I)
            text = re.sub(r'<[^>]+>', '', text)
            text = re.sub(r'\s{2,}', ' ', text).strip()
            self.plain_body = text[:10000]  # cap length
            return True
        return False

    def mark_sent(self):
        self.status = self.STATUS_SENT
        self.sent_at = timezone.now()
        self.save(update_fields=['status', 'sent_at'])

    def mark_failed(self, err):
        self.status = self.STATUS_FAILED
        self.error = str(err)[:2000]
        self.save(update_fields=['status', 'error'])

    def queue_outbound(self, created_by=None, scheduled_for=None):
        """
        Create an OutboundMessage that the worker will expand and deliver.
        Returns the created OutboundMessage instance.
        """
        from .models import OutboundMessage  # import local OutboundMessage
        from django.contrib.auth import get_user_model
        User = get_user_model()

        # compute recipients queryset based on audience
        if self.audience == 'clients':
            qs = User.objects.filter(role='client')
        elif self.audience == 'marketers':
            qs = User.objects.filter(role='marketer')
        else:
            qs = User.objects.all()

        recipients_count = qs.count()
        sample = list(qs.values_list('email', flat=True)[:5])

        om = OutboundMessage.objects.create(
            channel='email',
            audience=self.audience,
            subject=self.subject,
            body=self.html_body,
            created_by=created_by or self.created_by,
            scheduled_for=scheduled_for or self.scheduled_for or timezone.now(),
            status='queued',
            recipients_count=recipients_count,
            recipients_sample=sample
        )

        # record recipients metadata on campaign too
        self.recipients_count = recipients_count
        self.recipients_sample = sample
        self.status = self.STATUS_QUEUED
        if scheduled_for:
            self.scheduled_for = scheduled_for
        self.save(update_fields=['recipients_count', 'recipients_sample', 'status', 'scheduled_for'])
        return om

# APP CONTENT MANAGEMENT

from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
import json
from datetime import date

class Holiday(models.Model):
    name = models.CharField(max_length=100)
    date = models.DateField()
    recurring = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.name} ({self.date})"
    
    class Meta:
        ordering = ['date']

class Season(models.Model):
    name = models.CharField(max_length=50)
    start_month = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(12)]
    )
    start_day = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(31)],
        default=1
    )
    end_month = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(12)]
    )
    end_day = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(31)],
        default=28
    )
    
    def is_active(self, check_date=None):
        if check_date is None:
            check_date = date.today()
            
        start_date = date(check_date.year, self.start_month, self.start_day)
        end_date = date(check_date.year, self.end_month, self.end_day)
        
        # Handle seasons that cross year boundaries
        if start_date > end_date:
            if check_date >= start_date or check_date <= end_date:
                return True
        else:
            if start_date <= check_date <= end_date:
                return True
                
        return False
    
    def __str__(self):
        return self.name
    
    class Meta:
        ordering = ['start_month', 'start_day']


class CustomSpecialDay(models.Model):
    """Admin-created special day that should appear on calendars and campaigns."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=150)
    date = models.DateField()
    category = models.CharField(max_length=50, default='custom', blank=True)
    description = models.TextField(blank=True)
    country_code = models.CharField(max_length=10, default='NG', blank=True)
    is_recurring = models.BooleanField(default=False)
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['date', 'name']
        unique_together = ('name', 'date')

    def __str__(self):
        return f"{self.name} ({self.date})"


class SiteTheme(models.Model):
    name = models.CharField(max_length=100)
    theme_type = models.CharField(max_length=20, choices=THEME_TYPES, default='default')
    primary_color = models.CharField(max_length=7, default='#6A5AE0')
    secondary_color = models.CharField(max_length=7, blank=True)
    accent_color = models.CharField(max_length=7, default='#FFFFFF')
    hero_image = models.URLField(max_length=500)
    banner_text = models.CharField(max_length=200)
    
    # Gradient configuration
    gradient_colors = models.JSONField(default=list)
    gradient_stops = models.JSONField(default=list)
    gradient_begin = models.CharField(max_length=50, default='topCenter')
    gradient_end = models.CharField(max_length=50, default='bottomCenter')
    accent_gradient_colors = models.JSONField(default=list)
    
    # Theme applicability
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    priority = models.IntegerField(default=0, help_text="Higher priority themes override lower ones")
    
    # Relationships
    holiday = models.ForeignKey(
        Holiday, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        help_text="Associated holiday (if theme_type is holiday)"
    )
    season = models.ForeignKey(
        Season, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        help_text="Associated season (if theme_type is seasonal)"
    )
    
    is_active = models.BooleanField(default=True)
    
    def is_applicable_today(self):
        today = date.today()
        
        # Check if theme is active
        if not self.is_active:
            return False
            
        # Check date range if specified
        if self.start_date and self.end_date:
            if not (self.start_date <= today <= self.end_date):
                return False
                
        # Check holiday if specified
        if self.theme_type == 'holiday' and self.holiday:
            holiday_date = self.holiday.date
            # For recurring holidays, check if it's the same month and day
            if self.holiday.recurring:
                if (today.month, today.day) != (holiday_date.month, holiday_date.day):
                    return False
            else:
                if today != holiday_date:
                    return False
                    
        # Check season if specified
        if self.theme_type == 'seasonal' and self.season:
            if not self.season.is_active(today):
                return False
                
        return True
    
    def __str__(self):
        return f"{self.name} ({self.get_theme_type_display()})"
    
    class Meta:
        ordering = ['-priority', 'name']

class ThemeRule(models.Model):
    RULE_TYPES = [
        ('date_range', 'Date Range'),
        ('day_of_week', 'Day of Week'),
        ('specific_date', 'Specific Date'),
        ('custom_condition', 'Custom Condition'),
    ]
    
    name = models.CharField(max_length=100)
    rule_type = models.CharField(max_length=20, choices=RULE_TYPES)
    theme = models.ForeignKey(SiteTheme, on_delete=models.CASCADE)
    
    # For date_range
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    
    # For day_of_week
    days_of_week = models.JSONField(
        default=list,
        help_text="List of days (0=Sunday, 1=Monday, etc.)"
    )
    
    # For specific_date
    specific_date = models.DateField(null=True, blank=True)
    
    # For custom_condition
    custom_condition = models.TextField(
        blank=True,
        help_text="Custom Python expression that returns True/False. Use 'date' for current date."
    )
    
    priority = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    
    def evaluate(self, check_date=None):
        if check_date is None:
            check_date = date.today()
            
        if not self.is_active:
            return False
            
        if self.rule_type == 'date_range':
            if self.start_date and self.end_date:
                return self.start_date <= check_date <= self.end_date
                
        elif self.rule_type == 'day_of_week':
            return check_date.weekday() in self.days_of_week
            
        elif self.rule_type == 'specific_date':
            if self.specific_date:
                return check_date == self.specific_date
                
        elif self.rule_type == 'custom_condition':
            if self.custom_condition:
                try:
                    # Security note: In production, you'd want to sandbox this execution
                    return eval(self.custom_condition, {'date': check_date})
                except:
                    return False
                    
        return False
    
    def __str__(self):
        return f"{self.name} for {self.theme.name}"
    
    class Meta:
        ordering = ['-priority', 'name']


class Statistic(models.Model):
    homes_delivered = models.PositiveIntegerField(default=0)
    estates_developed = models.PositiveIntegerField(default=0)
    years_in_business = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return "Site Statistics"

class Project(models.Model):
    name = models.CharField(max_length=200)
    location = models.CharField(max_length=100)
    sold_percent = models.PositiveIntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        default=0
    )
    image = models.URLField(max_length=500)
    is_featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return self.name
    
    class Meta:
        ordering = ['-created_at']

class Update(models.Model):
    title = models.CharField(max_length=200)
    date = models.DateField(default=timezone.now)
    image = models.URLField(max_length=500)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return self.title
    
    class Meta:
        ordering = ['-date', '-created_at']

class DiasporaOffer(models.Model):
    title = models.CharField(max_length=200)
    icon = models.CharField(max_length=50, default='local_shipping')  # Matches Material Icons
    subtitle = models.CharField(max_length=200, blank=True)
    detail = models.TextField(blank=True)
    is_virtual = models.BooleanField(default=False)
    order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return self.title
    
    class Meta:
        ordering = ['order', 'title']

class SocialProof(models.Model):
    image = models.URLField(max_length=500)
    caption = models.CharField(max_length=200)
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)
    
    def __str__(self):
        return self.caption
    
    class Meta:
        ordering = ['order', 'caption']

class ContactInfo(models.Model):
    company_name = models.CharField(max_length=200)
    cac_number = models.CharField(max_length=50)
    address = models.TextField()
    whatsapp_number = models.CharField(max_length=20)
    phone_number = models.CharField(max_length=20)
    facebook_url = models.URLField(blank=True)
    instagram_url = models.URLField(blank=True)
    linkedin_url = models.URLField(blank=True)
    youtube_url = models.URLField(blank=True)
    
    def __str__(self):
        return self.company_name

class WheelPrize(models.Model):
    text = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)
    
    def __str__(self):
        return self.text
    
    class Meta:
        ordering = ['order', 'text']

class SpinLimit(models.Model):
    spins_per_day = models.PositiveIntegerField(default=3)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"Spin Limit: {self.spins_per_day} per day"


# ===================== ENTERPRISE CRM AUTOMATION MODELS =====================

class CRMSettings(models.Model):
    """Global CRM settings and configurations"""
    
    # Communication Channels
    sms_enabled = models.BooleanField(default=True)
    email_enabled = models.BooleanField(default=True)
    whatsapp_enabled = models.BooleanField(default=False)
    push_notifications_enabled = models.BooleanField(default=True)
    
    # SMS Configuration
    sms_provider = models.CharField(max_length=50, default='twilio')
    sms_api_key = models.CharField(max_length=255, blank=True)
    sms_sender_name = models.CharField(max_length=50, default='RealEstate')
    
    # Email Configuration
    email_provider = models.CharField(max_length=50, default='sendgrid')
    email_api_key = models.CharField(max_length=255, blank=True)
    email_sender_name = models.CharField(max_length=100, default='Real Estate Team')
    email_sender_address = models.EmailField(blank=True)
    
    # WhatsApp Configuration
    whatsapp_business_id = models.CharField(max_length=100, blank=True)
    whatsapp_access_token = models.CharField(max_length=500, blank=True)
    
    # Automation Settings
    birthday_campaigns_enabled = models.BooleanField(default=True)
    special_day_campaigns_enabled = models.BooleanField(default=True)
    follow_up_campaigns_enabled = models.BooleanField(default=True)
    
    # Timing Settings
    campaign_send_hour = models.IntegerField(default=9, help_text="Hour to send campaigns (24-hour format)")
    weekend_campaigns_enabled = models.BooleanField(default=False)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = "CRM Settings"
        verbose_name_plural = "CRM Settings"
    
    def __str__(self):
        return "CRM Configuration Settings"


class AutomationTrigger(models.Model):
    """Defines automated campaign triggers"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    trigger_type = models.CharField(max_length=20, choices=TRIGGER_TYPES)
    
    # Timing Configuration
    days_before = models.IntegerField(default=0, help_text="Days before event to trigger")
    days_after = models.IntegerField(default=0, help_text="Days after event to trigger")
    send_time = models.TimeField(help_text="Time to send the message")
    
    # Target Audience
    target_audience = models.CharField(max_length=30, choices=AUDIENCE_CHOICES)
    
    # Message Configuration
    message_template = models.ForeignKey(MessageTemplate, on_delete=models.CASCADE)
    channels = models.JSONField(default=list, help_text="List of channels to use")
    
    # Status
    is_active = models.BooleanField(default=True)
    priority = models.IntegerField(default=5, help_text="1=Highest, 10=Lowest")
    
    # Analytics
    total_sent = models.IntegerField(default=0)
    total_delivered = models.IntegerField(default=0)
    total_opened = models.IntegerField(default=0)
    total_clicked = models.IntegerField(default=0)
    
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['priority', 'name']
    
    def __str__(self):
        return f"{self.name} ({self.get_trigger_type_display()})"


class SpecialDayCalendar(models.Model):
    """Manages special days and holidays for automated campaigns"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    special_day_type = models.CharField(max_length=20, choices=SPECIAL_DAYS)
    
    # Date Configuration
    date = models.DateField(help_text="Specific date for the event")
    is_recurring = models.BooleanField(default=True)
    recurrence_pattern = models.CharField(
        max_length=20,
        choices=[
            ('yearly', 'Yearly'),
            ('monthly', 'Monthly'),
            ('custom', 'Custom Pattern'),
        ],
        default='yearly'
    )
    
    # Campaign Configuration
    automation_triggers = models.ManyToManyField(AutomationTrigger, blank=True)
    
    # Regional Settings
    is_national_holiday = models.BooleanField(default=True)
    is_religious_holiday = models.BooleanField(default=False)
    regions = models.JSONField(default=list, help_text="Specific regions where this applies")
    
    # Status
    is_active = models.BooleanField(default=True)
    
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['date', 'name']
        unique_together = ['name', 'date']
    
    def __str__(self):
        return f"{self.name} - {self.date.strftime('%B %d')}"


class CampaignSchedule(models.Model):
    """Scheduled campaigns with advanced targeting"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    
    # Campaign Type
    campaign_type = models.CharField(
        max_length=20,
        choices=[
            ('birthday', 'Birthday Campaign'),
            ('special_day', 'Special Day Campaign'),
            ('follow_up', 'Follow-up Campaign'),
            ('broadcast', 'Broadcast Campaign'),
            ('drip', 'Drip Campaign'),
            ('trigger', 'Trigger-based Campaign'),
        ]
    )
    
    # Scheduling
    scheduled_date = models.DateTimeField()
    is_recurring = models.BooleanField(default=False)
    recurrence_interval = models.CharField(
        max_length=20,
        choices=[
            ('daily', 'Daily'),
            ('weekly', 'Weekly'),
            ('monthly', 'Monthly'),
            ('quarterly', 'Quarterly'),
            ('yearly', 'Yearly'),
        ],
        blank=True
    )
    
    # Targeting
    target_segments = models.JSONField(default=list)
    exclude_segments = models.JSONField(default=list)
    location_targeting = models.JSONField(default=dict)
    
    # Message Configuration
    message_templates = models.ManyToManyField(MessageTemplate)
    channels = models.JSONField(default=list)
    
    # Advanced Settings
    send_limit = models.IntegerField(null=True, blank=True, help_text="Max recipients per batch")
    throttle_rate = models.IntegerField(default=100, help_text="Messages per minute")
    
    # Status
    status = models.CharField(
        max_length=20,
        choices=[
            ('draft', 'Draft'),
            ('scheduled', 'Scheduled'),
            ('running', 'Running'),
            ('paused', 'Paused'),
            ('completed', 'Completed'),
            ('failed', 'Failed'),
        ],
        default='draft'
    )
    
    # Analytics
    total_recipients = models.IntegerField(default=0)
    total_sent = models.IntegerField(default=0)
    total_delivered = models.IntegerField(default=0)
    total_failed = models.IntegerField(default=0)
    
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-scheduled_date']
    
    def __str__(self):
        return f"{self.name} ({self.get_status_display()})"


class CampaignAnalytics(models.Model):
    """Detailed analytics for campaigns"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    campaign = models.ForeignKey(CampaignSchedule, on_delete=models.CASCADE, related_name='analytics')
    
    # Metrics
    date = models.DateField()
    sent_count = models.IntegerField(default=0)
    delivered_count = models.IntegerField(default=0)
    opened_count = models.IntegerField(default=0)
    clicked_count = models.IntegerField(default=0)
    bounced_count = models.IntegerField(default=0)
    unsubscribed_count = models.IntegerField(default=0)
    
    # Channel-specific metrics
    sms_sent = models.IntegerField(default=0)
    sms_delivered = models.IntegerField(default=0)
    email_sent = models.IntegerField(default=0)
    email_delivered = models.IntegerField(default=0)
    whatsapp_sent = models.IntegerField(default=0)
    whatsapp_delivered = models.IntegerField(default=0)
    
    # Revenue tracking (for real estate)
    leads_generated = models.IntegerField(default=0)
    appointments_booked = models.IntegerField(default=0)
    properties_viewed = models.IntegerField(default=0)
    sales_attributed = models.IntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['campaign', 'date']
        ordering = ['-date']

    def __str__(self):
        return f"Analytics for {self.campaign} on {self.date}"


class StaffBroadcast(models.Model):
    AUDIENCE_CHOICES = [
        ('all_staff', 'All Staff'),
        ('individuals', 'Specific Individuals'),
    ]

    STATUS_SCHEDULED = 'scheduled'
    STATUS_SENDING = 'sending'
    STATUS_SENT = 'sent'
    STATUS_CANCELLED = 'cancelled'
    STATUS_CHOICES = [
        (STATUS_SCHEDULED, 'Scheduled'),
        (STATUS_SENDING, 'Sending'),
        (STATUS_SENT, 'Sent'),
        (STATUS_CANCELLED, 'Cancelled'),
    ]

    REPEAT_NONE = 'none'
    REPEAT_DAILY = 'daily'
    REPEAT_WEEKLY = 'weekly'
    REPEAT_MONTHLY = 'monthly'
    REPEAT_QUARTERLY = 'quarterly'
    REPEAT_YEARLY = 'yearly'

    repeat_schedule = models.CharField(
        max_length=20,
        choices=[
            (REPEAT_NONE, 'No Repeat'),
            (REPEAT_DAILY, 'Daily'),
            (REPEAT_WEEKLY, 'Weekly'),
            (REPEAT_MONTHLY, 'Monthly'),
            (REPEAT_QUARTERLY, 'Quarterly'),
            (REPEAT_YEARLY, 'Yearly'),
        ],
        default=REPEAT_NONE,
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    template_name = models.CharField(max_length=255, blank=True)
    subject = models.CharField(max_length=255, blank=True)
    body = models.TextField()
    channels = models.JSONField(default=list, blank=True, help_text='List of channels e.g. ["email", "sms"]')
    audience_type = models.CharField(max_length=30, choices=AUDIENCE_CHOICES, default='all_staff')
    scheduled_for = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_SCHEDULED)
    total_recipients = models.PositiveIntegerField(default=0)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='staff_broadcasts'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Staff Broadcast'
        verbose_name_plural = 'Staff Broadcasts'

    def __str__(self):
        return self.template_name or self.subject or f"Broadcast {self.id}"


class StaffBroadcastRecipient(models.Model):
    STATUS_QUEUED = 'queued'
    STATUS_SENDING = 'sending'
    STATUS_SENT = 'sent'
    STATUS_DELIVERED = 'delivered'
    STATUS_FAILED = 'failed'
    STATUS_CANCELLED = 'cancelled'
    STATUS_CHOICES = [
        (STATUS_QUEUED, 'Queued'),
        (STATUS_SENDING, 'Sending'),
        (STATUS_SENT, 'Sent'),
        (STATUS_DELIVERED, 'Delivered'),
        (STATUS_FAILED, 'Failed'),
        (STATUS_CANCELLED, 'Cancelled'),
    ]

    CHANNEL_EMAIL = 'email'
    CHANNEL_SMS = 'sms'
    CHANNEL_WHATSAPP = 'whatsapp'
    CHANNEL_INAPP = 'inapp'
    CHANNEL_CHOICES = [
        (CHANNEL_EMAIL, 'Email'),
        (CHANNEL_SMS, 'SMS'),
        (CHANNEL_WHATSAPP, 'WhatsApp'),
        (CHANNEL_INAPP, 'In-App'),
    ]

    broadcast = models.ForeignKey(
        StaffBroadcast,
        related_name='recipients',
        on_delete=models.CASCADE
    )
    staff_member = models.ForeignKey(
        StaffMember,
        related_name='broadcast_deliveries',
        on_delete=models.CASCADE
    )
    channel = models.CharField(max_length=20, choices=CHANNEL_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_QUEUED)
    attempts = models.PositiveIntegerField(default=0)
    last_attempt_at = models.DateTimeField(null=True, blank=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    error = models.TextField(blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['channel']),
        ]
        verbose_name = 'Staff Broadcast Recipient'
        verbose_name_plural = 'Staff Broadcast Recipients'

    def __str__(self):
        return f"{self.staff_member.full_name} · {self.channel} ({self.get_status_display()})"


class UserSegment(models.Model):
    """Advanced user segmentation for targeted campaigns"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    
    # Segment Type
    segment_type = models.CharField(
        max_length=20,
        choices=[
            ('demographic', 'Demographic'),
            ('behavioral', 'Behavioral'),
            ('geographic', 'Geographic'),
            ('psychographic', 'Psychographic'),
            ('value_based', 'Value-based'),
            ('lifecycle', 'Lifecycle Stage'),
        ]
    )
    
    # Targeting Criteria
    criteria = models.JSONField(default=dict, help_text="Segmentation criteria as JSON")
    
    # Audience Type
    applies_to = models.CharField(max_length=30, choices=AUDIENCE_CHOICES)
    
    # Dynamic Settings
    is_dynamic = models.BooleanField(default=True, help_text="Auto-update segment members")
    refresh_frequency = models.CharField(
        max_length=20,
        choices=[
            ('realtime', 'Real-time'),
            ('hourly', 'Hourly'),
            ('daily', 'Daily'),
            ('weekly', 'Weekly'),
        ],
        default='daily'
    )
    
    # Stats
    member_count = models.IntegerField(default=0)
    last_refreshed = models.DateTimeField(null=True, blank=True)
    
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['name']
    
    def __str__(self):
        return f"{self.name} ({self.member_count} members)"


class CampaignPersonalization(models.Model):
    """Advanced personalization rules for campaigns"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    
    # Personalization Rules
    conditions = models.JSONField(default=dict, help_text="Conditions for personalization")
    content_variations = models.JSONField(default=dict, help_text="Different content variations")
    
    # A/B Testing
    is_ab_test = models.BooleanField(default=False)
    test_variants = models.JSONField(default=list, help_text="A/B test variants")
    traffic_split = models.JSONField(default=dict, help_text="Traffic distribution")
    
    # Performance
    conversion_goal = models.CharField(max_length=100, blank=True)
    winning_variant = models.CharField(max_length=50, blank=True)
    
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return self.name


