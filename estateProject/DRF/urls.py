from django.urls import path

from DRF.clients.api_views.client_dashboard_views import ActivePromotionsListAPIView, ClientDashboardAPIView, EstateListAPIView, PriceUpdateDetailAPIView, PromotionDetailAPIView, PromotionsListAPIView
from DRF.clients.api_views.client_estate_detail_views import EstateDetailAPIView, EstateListAPIView as ClientEstateListAPIView

from DRF.clients.api_views.client_profile_views import (
    ClientPaymentReceiptByReferenceAPIView, ClientProfileView, ClientProfileUpdateView, ClientPropertiesView,
    ClientAppreciationView, ChangePasswordView, ClientTransactionReceiptByIdAPIView, ClientTransactionsView, ReceiptDownloadTokenAPIView,
    TransactionDetailView, TransactionPaymentsView
)
from DRF.clients.api_views.client_notification_views import (
    ClientNotificationDetailAPI,
    ClientNotificationListAPI,
    MarkAllReadAPI,
    MarkReadAPI,
    MarkUnreadAPI,
    UnreadCountAPI,
)
from DRF.marketers.api_views.marketer_notification_views import (
    MarketerMarkAllReadAPI,
    MarketerMarkReadAPI,
    MarketerMarkUnreadAPI,
    MarketerNotificationDetailAPI,
    MarketerNotificationListAPI,
    MarketerUnreadCountAPI,
)
from DRF.marketers.api_views.marketer_chat_views import (
    MarketerChatDeleteAPIView,
    MarketerChatDeleteForEveryoneAPIView,
    MarketerChatDetailAPIView,
    MarketerChatListAPIView,
    MarketerChatMarkAsReadAPIView,
    MarketerChatPollAPIView,
    MarketerChatSendAPIView,
    MarketerChatUnreadCountAPIView,
)
from DRF.clients.api_views.client_chat_views import (
    ClientChatListAPIView,
    ClientChatDetailAPIView,
    ClientChatSendAPIView,
    ClientChatDeleteAPIView,
    ClientChatDeleteForEveryoneAPIView,
    ClientChatUnreadCountAPIView,
    ClientChatMarkAsReadAPIView,
    ClientChatPollAPIView,
)
from DRF.marketers.api_views.client_record_views import MarketerClientDetailAPIView, MarketerClientListAPIView
from DRF.marketers.api_views.marketer_dashboard_views import MarketerChartRangeAPIView, MarketerDashboardAPIView
from DRF.marketers.api_views.marketer_profile_views import (
    MarketerChangePasswordView,
    MarketerProfileUpdateView,
    MarketerProfileView,
    MarketerTransactionsView,
)
from DRF.shared_drf.shared_header_views import (
    AdminClientChatListAPIView,
    AdminMarketerChatListAPIView,
    ChatUnreadCountAPIView,
    HeaderDataAPIView,
    MarkNotificationReadAPIView,
    NotificationsListAPIView,
)
from DRF.admin_support.api_views.chat_views import (
    SupportChatDeleteMessageAPIView,
    SupportChatMarkReadAPIView,
    SupportChatPollAPIView,
    SupportChatThreadAPIView,
)
from DRF.clients.api_views.device_token_views import DeviceTokenListView, DeviceTokenRegisterView

app_name = 'drf'

urlpatterns = [
    # SHARED HEADER
    path('header-data/', HeaderDataAPIView.as_view(), name='api-header-data'),
    path('chat-unread-count/', ChatUnreadCountAPIView.as_view(), name='chat_unread_count'),
    path('notifications/', NotificationsListAPIView.as_view(), name='api-notifications-list'),
    path('notifications/mark-read/<int:pk>/', MarkNotificationReadAPIView.as_view(), name='mark_notification_read_api'),
    path('admin/clients/unread/', AdminClientChatListAPIView.as_view(), name='admin_client_chat_list_api'),
    path('admin/marketers/unread/', AdminMarketerChatListAPIView.as_view(), name='admin_marketer_chat_list_api'),
    
    path('admin-support/chat/<str:role>/<int:participant_id>/', SupportChatThreadAPIView.as_view(), name='support_chat_thread_api'),
    path('admin-support/chat/<str:role>/<int:participant_id>/poll/', SupportChatPollAPIView.as_view(), name='support_chat_poll_api'),
    path('admin-support/chat/<str:role>/<int:participant_id>/mark-read/', SupportChatMarkReadAPIView.as_view(), name='support_chat_mark_read_api'),
    path('admin-support/chat/messages/<int:pk>/delete/', SupportChatDeleteMessageAPIView.as_view(), name='support_chat_delete_message_api'),


    # client dashboard
    path('client/dashboard-data/', ClientDashboardAPIView.as_view(), name='client-dashboard-data'),
    path('api/price-update/<int:pk>/', PriceUpdateDetailAPIView.as_view(), name='api-price-update'),
    path('estates/', EstateListAPIView.as_view(), name='estates-list'),
    path('promotions/active/', ActivePromotionsListAPIView.as_view(), name='active-promotions-list'),
    path('promotions/', PromotionsListAPIView.as_view(), name='promotions-list'),
    path('promotions/<int:pk>/', PromotionDetailAPIView.as_view(), name='promotion-detail'),

    # Profile
    path('clients/profile/', ClientProfileView.as_view(), name='client-profile'),
    path('clients/profile/update/', ClientProfileUpdateView.as_view(), name='client-profile-update'),
    path('clients/properties/', ClientPropertiesView.as_view(), name='client-properties'),
    path('clients/appreciation/', ClientAppreciationView.as_view(), name='client-appreciation'),
    path('clients/change-password/', ChangePasswordView.as_view(), name='client-change-password'),
    path('payment/receipt/<str:reference>/', ClientPaymentReceiptByReferenceAPIView.as_view(), name='drf-client-payment-receipt'),
    path('clients/receipts/download/', ClientPaymentReceiptByReferenceAPIView.as_view(), name='client-receipt-download'),
    path('clients/receipts/request-download/', ReceiptDownloadTokenAPIView.as_view(), name='client-receipt-request'),
    path('transaction/<int:transaction_id>/receipt/', ClientTransactionReceiptByIdAPIView.as_view(), name='client-transaction-receipt'),

    # transactions...
    path('clients/transactions/', ClientTransactionsView.as_view(), name='client-transactions'),
    path('clients/transaction/<int:transaction_id>/details/', TransactionDetailView.as_view(), name='client-transaction-detail'),
    path('clients/transaction/payments/', TransactionPaymentsView.as_view(), name='client-transaction-payments'),
    
    # transaction receipt
    path('payment/receipt/<str:reference>/', ClientPaymentReceiptByReferenceAPIView.as_view(), name='api-client-payment-receipt'),
    path('transaction/<int:transaction_id>/receipt/', ClientTransactionReceiptByIdAPIView.as_view(), name='api-client-transaction-receipt'),

    # Notifications
    # path('client/notifications/', UserNotificationListAPIView.as_view(), name='client_notifications_list'),
    # path('client/notifications/stats/', NotificationStatsAPIView.as_view(), name='client_notifications_stats'),
    # path('client/notifications/<int:pk>/', UserNotificationDetailAPIView.as_view(), name='client_notifications_detail'),
    # path('client/notifications/<int:pk>/mark-read/', MarkUserNotificationReadAPIView.as_view(), name='client_notifications_mark_read'),
    
    path('client/notifications/', ClientNotificationListAPI.as_view(), name='notifications-list'),
    path('client/notifications/unread-count/', UnreadCountAPI.as_view(), name='notifications-unread-count'),
    path('client/notifications/<int:pk>/', ClientNotificationDetailAPI.as_view(), name='notifications-detail'),
    path('client/notifications/<int:pk>/mark-read/', MarkReadAPI.as_view(), name='notifications-mark-read'),
    path('client/notifications/<int:pk>/mark-unread/', MarkUnreadAPI.as_view(), name='notifications-mark-unread'),
    path('client/notifications/mark-all-read/', MarkAllReadAPI.as_view(), name='notifications-mark-all-read'),

    path('marketers/notifications/', MarketerNotificationListAPI.as_view(), name='marketer-notifications-list'),
    path('marketers/notifications/unread-count/', MarketerUnreadCountAPI.as_view(), name='marketer-notifications-unread-count'),
    path('marketers/notifications/<int:pk>/', MarketerNotificationDetailAPI.as_view(), name='marketer-notifications-detail'),
    path('marketers/notifications/<int:pk>/mark-read/', MarketerMarkReadAPI.as_view(), name='marketer-notifications-mark-read'),
    path('marketers/notifications/<int:pk>/mark-unread/', MarketerMarkUnreadAPI.as_view(), name='marketer-notifications-mark-unread'),
    path('marketers/notifications/mark-all-read/', MarketerMarkAllReadAPI.as_view(), name='marketer-notifications-mark-all-read'),

    path('marketers/chat/', MarketerChatListAPIView.as_view(), name='marketer-chat-list'),
    path('marketers/chat/<int:pk>/', MarketerChatDetailAPIView.as_view(), name='marketer-chat-detail'),
    path('marketers/chat/send/', MarketerChatSendAPIView.as_view(), name='marketer-chat-send'),
    path('marketers/chat/<int:pk>/delete/', MarketerChatDeleteAPIView.as_view(), name='marketer-chat-delete'),
    path('marketers/chat/delete-for-everyone/', MarketerChatDeleteForEveryoneAPIView.as_view(), name='marketer-chat-delete-for-everyone'),
    path('marketers/chat/unread-count/', MarketerChatUnreadCountAPIView.as_view(), name='marketer-chat-unread-count'),
    path('marketers/chat/mark-read/', MarketerChatMarkAsReadAPIView.as_view(), name='marketer-chat-mark-read'),
    path('marketers/chat/poll/', MarketerChatPollAPIView.as_view(), name='marketer-chat-poll'),

    # CLIENT CHAT / MESSAGING
    path('client/chat/', ClientChatListAPIView.as_view(), name='client-chat-list'),
    path('client/chat/<int:pk>/', ClientChatDetailAPIView.as_view(), name='client-chat-detail'),
    path('client/chat/send/', ClientChatSendAPIView.as_view(), name='client-chat-send'),
    path('client/chat/<int:pk>/delete/', ClientChatDeleteAPIView.as_view(), name='client-chat-delete'),
    path('client/chat/delete-for-everyone/', ClientChatDeleteForEveryoneAPIView.as_view(), name='client-chat-delete-for-everyone'),
    path('client/chat/unread-count/', ClientChatUnreadCountAPIView.as_view(), name='client-chat-unread-count'),
    path('client/chat/mark-read/', ClientChatMarkAsReadAPIView.as_view(), name='client-chat-mark-read'),
    path('client/chat/poll/', ClientChatPollAPIView.as_view(), name='client-chat-poll'),

    # Device tokens
    path('device-tokens/', DeviceTokenListView.as_view(), name='device-token-list'),
    path('device-tokens/register/', DeviceTokenRegisterView.as_view(), name='device-token-register'),


    # MARKETERS SIDE
    # marketer profile
    path('marketers/profile/', MarketerProfileView.as_view(), name='marketer-profile'),
    path('marketers/profile/update/', MarketerProfileUpdateView.as_view(), name='marketer-profile-update'),
    path('marketers/change-password/', MarketerChangePasswordView.as_view(), name='marketer-change-password'),
    path('marketers/transactions/', MarketerTransactionsView.as_view(), name='marketer-transactions'),
    
    # marketer dashboard
    path('marketers/dashboard/', MarketerDashboardAPIView.as_view(), name='marketer-dashboard'),
    path('marketers/dashboard/data/', MarketerChartRangeAPIView.as_view(), name='marketer-dashboard-data'),

    # marketer clients records
    path('marketers/clients/', MarketerClientListAPIView.as_view(), name='marketer-client-list'),
    path('marketers/clients/<int:pk>/', MarketerClientDetailAPIView.as_view(), name='marketer-client-detail'),

    # client View Estate Plot Details 
    path('clients/estates/', ClientEstateListAPIView.as_view(), name='client-estate-list'),
    path('clients/estates/<int:pk>/', EstateDetailAPIView.as_view(), name='client-estate-detail'),


]
