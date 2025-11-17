from django.urls import path
from . import views

app_name = 'adminSupport'

urlpatterns = [
    path('support/', views.SupportMessagingDashboardView.as_view(), name='support_dashboard'),
    path('app-content-management/', views.contentManagementPage, name='app_content_management'),
    path('manage-app-content/', views.manageContentPage, name='manage_app_content'),
    path('newsletter/', views.newsletter, name='newsletter'),
    path('chat/', views.chat, name='chat'),
    path('chat/refresh/', views.chat_list_partial, name='chat_list_partial'),
    path('chat/<str:role>/<int:user_id>/', views.chat_conversation, name='chat_conversation'),
    path('chat/<str:role>/<int:user_id>/poll/', views.chat_poll, name='chat_poll'),
    path('chat/<str:role>/<int:user_id>/send/', views.chat_send_message, name='chat_send_message'),
    path('chat/delete/', views.chat_delete_message, name='chat_delete_message'),
    path('chat/search/clients/', views.chat_search_clients, name='chat_search_clients'),
    path('chat/search/marketers/', views.chat_search_marketers, name='chat_search_marketers'),
    path('api/client-chats/', views.chat_list_clients_api, name='chat_list_clients_api'),
    path('api/marketer-chats/', views.chat_list_marketers_api, name='chat_list_marketers_api'),

    # directories
    path('clients-directory/', views.clients_directory, name='clients_directory'),
    path('marketers-directory/', views.marketers_directory, name='marketers_directory'),

    # users
    path('api/users/', views.api_users, name='api_users'),

    # staff management
    path('api/staff/stats/', views.api_staff_stats, name='api_staff_stats'),
    path('api/staff/', views.api_staff_list, name='api_staff_list'),
    path('api/staff/former/', views.api_staff_former, name='api_staff_former'),
    path('api/staff/create/', views.api_staff_create, name='api_staff_create'),
    path('api/staff/<int:staff_id>/', views.api_staff_detail, name='api_staff_detail'),
    path('api/staff/remove/', views.api_staff_remove, name='api_staff_remove'),
    path('api/staff/reactivate/', views.api_staff_reactivate, name='api_staff_reactivate'),
    path('api/staff/import/', views.api_staff_import, name='api_staff_import'),
    path('api/staff/failed-messages/', views.api_staff_failed_messages, name='api_staff_failed_messages'),
    path('api/staff/failed-retry/', views.api_staff_failed_retry, name='api_staff_failed_retry'),
    path('api/staff/failed-retry-all/', views.api_staff_failed_retry_all, name='api_staff_failed_retry_all'),
    path('api/staff/failed-delete/', views.api_staff_failed_delete, name='api_staff_failed_delete'),

    # templates
    path('api/templates/', views.api_templates_list, name='api_templates_list'),
    path('api/templates/save/', views.api_templates_save, name='api_templates_save'),
    path('api/templates/delete/<int:tpl_id>/', views.api_templates_delete, name='api_templates_delete'),

    # outbound
    path('api/outbound/', views.api_outbound_list, name='api_outbound_list'),
    path('api/outbound/create/', views.api_outbound_create, name='api_outbound_create'),
    path('api/outbound/delete/<uuid:outbound_id>/', views.api_outbound_delete, name='api_outbound_delete'),

    # in-app messages (drafts / sent)
    path('api/messages/', views.api_messages_list, name='api_messages_list'),
    path('api/messages/status/', views.api_messages_status, name='api_messages_status'),
    path('api/messages/save/', views.api_messages_create_or_update, name='api_messages_save'),
    path('api/messages/delete/<int:msg_id>/', views.api_messages_delete, name='api_messages_delete'),

    # activity & stats & birthdays
    path('api/activity/', views.api_activity, name='api_activity'),
    path('api/stats/', views.api_stats, name='api_stats'),
    path('api/birthdays/', views.api_birthdays_upcoming, name='api_birthdays'),
    path('api/birthdays/summary/', views.api_birthdays_summary, name='api_birthdays_summary'),
    path('api/birthdays/counts/', views.api_birthdays_counts, name='api_birthdays_counts'),
    path('api/audience-options/', views.api_audience_options, name='api_audience_options'),

    # triggers
    path('api/run-triggers/', views.api_run_scheduled_triggers, name='api_run_triggers'),

    # conversations
    path('api/conversations/create/', views.api_conversation_create, name='api_conversation_create'),
    path('api/conversations/', views.api_conversation_list, name='api_conversation_list'),
    path('api/conversations/<int:conv_id>/messages/', views.api_conversation_messages, name='api_conversation_messages'),
    path('api/conversations/<int:conv_id>/send/', views.api_conversation_send_message, name='api_conversation_send_message'),

    # BIRTHDAY TEMPLATE
    path('templates/', views.autobirthday, name='templates'),
    path('run-triggers/', views.api_run_triggers, name='api_run_triggers'),
    path('api/birthday-templates/', views.api_templates_list_create, name='api_birthday_templates_list'),
    path('api/birthday-templates/<uuid:tpl_id>/', views.api_template_detail, name='api_birthday_templates_detail'),
    path('api/settings/auto_birthday/', views.api_auto_birthday, name='api_auto_birthday'),
    path('api/calendar-events/', views.api_calendar_events, name='api_calendar_events'),
    path('api/birthdays/failed/', views.api_birthday_failed, name='api_birthday_failed'),
    path('api/birthdays/retry/', views.api_birthday_retry, name='api_birthday_retry'),
    path('api/birthdays/retry-all/', views.api_birthday_retry_all, name='api_birthday_retry_all'),
    path('api/birthdays/delete-failed/', views.api_birthday_delete_failed, name='api_birthday_delete_failed'),

    path('special-days/', views.autoSpecialDay, name='auto_special_day'),
    path('auto-special-days/', views.autoSpecialDay, name='auto_special_day_template'),
    path('api/special-templates/', views.api_special_templates_list_create, name='api_special_templates_list'),
    path('api/special-templates/<uuid:tpl_id>/', views.api_special_template_detail, name='api_special_templates_detail'),
    path('api/special-days/', views.api_special_days, name='api_special_days'),
    path('api/special-days/summary/', views.api_special_days_summary, name='api_special_days_summary'),
    path('api/special-days/counts/', views.api_special_days_counts, name='api_special_days_counts'),
    path('api/settings/auto_special_day/', views.api_auto_special_day, name='api_auto_special_day'),
    path('api/custom-special-days/', views.api_custom_special_days, name='api_custom_special_days'),
    path('api/custom-special-days/<uuid:day_id>/', views.api_custom_special_day_detail, name='api_custom_special_day_detail'),

    # SEND MESSAGE
    path('messages/', views.messages, name='messages'),
    path('api/templates/<uuid:tpl_id>/', views.api_templates_detail, name='api_templates_detail'),
    path('api/messages/<int:msg_id>/', views.api_messages_detail, name='api_messages_detail'),
    path('api/outbound/<uuid:outbound_id>/', views.api_outbound_detail, name='api_outbound_detail'),

    # NEWSLETTER
    path('api/newsletter/preview/', views.api_newsletter_preview, name='api_newsletter_preview'),
    path('api/newsletter/send/', views.api_newsletter_send, name='api_newsletter_send'),
    path('api/upload-image/', views.api_upload_image, name='api_upload_image'),

    # SETTINGS
    path('settings/', views.settings, name='settings'),
    path('settings-page/', views.settings, name='settings_page'),
    path('api/settings/get/', views.api_settings_get, name='api_settings_get'),
    path('api/settings/update/', views.api_settings_update, name='api_settings_update'),
    path('api/settings/run-triggers/', views.api_settings_run_triggers, name='api_settings_run_triggers'),
    
    # ENTERPRISE CRM FEATURES
    path('crm-enterprise/', views.crm_enterprise_dashboard, name='crm_enterprise_dashboard'),
    path('special-days-manager/', views.special_days_manager, name='special_days_manager'),
    path('campaign-builder/', views.campaign_builder, name='campaign_builder'),
    path('audience-segments/', views.audience_segments, name='audience_segments'),
    path('crm-analytics/', views.crm_analytics, name='crm_analytics'),
    path('automation-settings/', views.automation_settings, name='automation_settings'),


]
