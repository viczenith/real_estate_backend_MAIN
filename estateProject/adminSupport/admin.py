from django.contrib import admin
from .models import (
    BirthdayTemplate,
    MessageTemplate,
    MessagingSettings,
    OutboundMessage,
    SupportConversation,
    SupportMessage,
    SupportMessageReceipt,
    InAppMessage,
    InboxEntry,
    ActivityLog,
    ScheduledTrigger,
    StaffMember,
    # StaffRoster is deprecated - use StaffMember instead
)


@admin.register(MessageTemplate)
class MessageTemplateAdmin(admin.ModelAdmin):
    list_display = ('name', 'channel', 'audience', 'is_active', 'created_by', 'created_at')
    list_filter = ('channel', 'audience', 'is_active')
    search_fields = ('name', 'body', 'subject', 'created_by__email')
    readonly_fields = ('created_at',)
    list_select_related = ('created_by',)
    list_per_page = 50
    date_hierarchy = 'created_at'


@admin.register(OutboundMessage)
class OutboundMessageAdmin(admin.ModelAdmin):
    list_display = ('short_id', 'channel', 'audience', 'status', 'recipients_count', 'created_by', 'created_at')
    list_filter = ('channel', 'status', 'audience')
    search_fields = ('body', 'subject', 'created_by__email')
    readonly_fields = ('id', 'created_at')
    actions = ['mark_as_sent', 'requeue']
    list_select_related = ('created_by',)
    list_per_page = 50
    date_hierarchy = 'created_at'

    @admin.display(description='Outbound ID')
    def short_id(self, obj):
        # show a shortened UUID for readability
        return str(obj.id)

    def mark_as_sent(self, request, queryset):
        updated = queryset.update(status='sent')
        self.message_user(request, f"{updated} outbound(s) marked as Sent.")
    mark_as_sent.short_description = "Mark selected as Sent"

    def requeue(self, request, queryset):
        updated = queryset.update(status='queued')
        self.message_user(request, f"{updated} outbound(s) re-queued.")
    requeue.short_description = "Requeue selected"


@admin.register(SupportConversation)
class SupportConversationAdmin(admin.ModelAdmin):
    list_display = ('id', 'subject', 'created_by', 'created_at', 'participants_count')
    search_fields = ('subject', 'created_by__email')
    readonly_fields = ('created_at',)
    filter_horizontal = ('participants',)
    list_select_related = ('created_by',)
    list_per_page = 50
    date_hierarchy = 'created_at'

    @admin.display(description='Participants', ordering='participants__count')
    def participants_count(self, obj):
        return obj.participants.count()


@admin.register(SupportMessage)
class SupportMessageAdmin(admin.ModelAdmin):
    list_display = ('short_body', 'sender', 'conversation', 'created_at', 'is_system')
    search_fields = ('body', 'sender__email', 'conversation__subject')
    readonly_fields = ('created_at',)
    list_select_related = ('sender', 'conversation')
    list_per_page = 50

    @admin.display(description='Message')
    def short_body(self, obj):
        return (obj.body or '')[:80]


@admin.register(SupportMessageReceipt)
class SupportMessageReceiptAdmin(admin.ModelAdmin):
    list_display = ('message', 'user', 'is_read', 'read_at', 'delivered_at')
    list_filter = ('is_read',)
    search_fields = ('user__email', 'message__body')
    list_select_related = ('user', 'message')
    list_per_page = 50


@admin.register(InAppMessage)
class InAppMessageAdmin(admin.ModelAdmin):
    list_display = ('subject', 'sender', 'is_draft', 'created_at')
    list_filter = ('is_draft',)
    search_fields = ('subject', 'body', 'sender__email')
    readonly_fields = ('created_at',)
    list_select_related = ('sender',)
    filter_horizontal = ('recipients',)
    list_per_page = 50
    date_hierarchy = 'created_at'


@admin.register(InboxEntry)
class InboxEntryAdmin(admin.ModelAdmin):
    list_display = ('user', 'message', 'is_read', 'archived', 'last_read_at')
    list_filter = ('is_read', 'archived')
    search_fields = ('user__email', 'message__subject', 'message__body')
    list_select_related = ('user', 'message')
    list_per_page = 50


@admin.register(ActivityLog)
class ActivityLogAdmin(admin.ModelAdmin):
    list_display = ('short_action', 'actor', 'created_at')
    search_fields = ('action', 'actor__email')
    readonly_fields = ('created_at',)
    list_select_related = ('actor',)
    list_per_page = 50
    date_hierarchy = 'created_at'

    @admin.display(description='Action')
    def short_action(self, obj):
        return (obj.action or '')[:120]


@admin.register(ScheduledTrigger)
class ScheduledTriggerAdmin(admin.ModelAdmin):
    list_display = ('template', 'enabled', 'daily', 'time_of_day', 'one_shot_at', 'last_run')
    list_filter = ('enabled', 'daily')
    search_fields = ('template__name',)
    list_select_related = ('template',)
    list_per_page = 50


#BIRTHDAY TEMPLATE
@admin.register(BirthdayTemplate)
class BirthdayTemplateAdmin(admin.ModelAdmin):
    list_display = ('name', 'channel', 'audience', 'enabled', 'created_by', 'created_at')
    list_filter = ('channel', 'audience', 'enabled')
    search_fields = ('name', 'message')


@admin.register(MessagingSettings)
class MessagingSettingsAdmin(admin.ModelAdmin):
    list_display = ('auto_birthday', 'updated_at')


@admin.register(StaffMember)
class StaffMemberAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'email', 'phone', 'role', 'active', 'employment_date', 'created_at')
    list_filter = ('active', 'role')
    search_fields = ('full_name', 'email', 'phone', 'address')
    readonly_fields = ('created_at', 'updated_at')
    list_per_page = 50
    date_hierarchy = 'created_at'
    
    # Customize the add/change form to match the Add Staff modal fields
    fieldsets = (
        ('Personal Information', {
            'fields': ('full_name', 'email', 'phone', 'date_of_birth')
        }),
        ('Employment Details', {
            'fields': ('role', 'employment_date', 'address')
        }),
        ('Status', {
            'fields': ('active', 'created_by', 'created_at', 'updated_at')
        }),
    )
    
    def save_model(self, request, obj, form, change):
        if not change:  # New object
            obj.created_by = request.user
        super().save_model(request, obj, form, change)


# StaffRoster is deprecated - it was used to link AUTH_USER_MODEL to staff directory
# but now StaffMember is a standalone model that stores all staff data independently
