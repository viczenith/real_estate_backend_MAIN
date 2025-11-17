from django.urls import path
from django.conf import settings
from django.conf.urls.static import static
from .views import *
from django.contrib.auth.views import LoginView, LogoutView


urlpatterns = [
    # path('login/', LoginView.as_view(template_name='login.html'), name='login'),

    path('login/', CustomLoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(next_page='login'), name='logout'),
    path('register/', company_registration, name='register'),
    path('company-profile/', company_profile_view, name='company-profile'),
    path('company-profile/update/', company_profile_update, name='company-profile-update'),
    path('company-profile/admin/<int:user_id>/toggle-mute/', admin_toggle_mute, name='admin-toggle-mute'),
    path('company-profile/admin/<int:user_id>/delete/', admin_delete_admin, name='admin-delete-admin'),


    path('', login_required(HomeView.as_view()), name="home"),
    # path('login/', CustomLoginView.as_view(), name="login-here"),

    path('admin_dashboard/', admin_dashboard, name="admin-dashboard"),
    path('estate-allocation-data/', estate_allocation_data, name='estate_allocation_data'),
    
    # path('client_profile', client_profile, name='client-profile'),
    path('client_profile/<int:pk>/', client_profile, name='client-profile'),
    path('management-dashboard', management_dashboard, name='management-dashboard'),
    path('add-plotsize', add_plotsize, name='add-plotsize'),
    path('add-plotnumber', add_plotnumber, name='add-plotnumber'),
    path('delete-plotsize/<int:pk>/', delete_plotsize, name='delete-plotsize'),
    path('delete-plotnumber/<int:pk>/', delete_plotnumber, name='delete-plotnumber'),
    path('update-plotsize/', add_plotsize, name='update-plotsize'),
    path('update-plotnumber/', add_plotnumber, name='update-plotnumber'),
    

    
    path('plot-allocation', plot_allocation, name="plot-allocation"),

    path('fetch_plot_data', fetch_plot_data, name="fetch_plot_data"),
    # path('allocated-plot/<int:estate_id>/', allocated_plot, name='allocated_plot'),
    path('view-estate/<int:estate_id>/', allocated_plot, name='allocated_plot'),
    path('get-plot-sizes/<int:estate_id>/', get_plot_sizes, name='get_plot_sizes'),

    # path('plots/<int:estate_id>/', get_plot_allocation_data, name='get_plot_allocation_data'),

    path('load-plots/', load_plots, name='load_plots'),
    path('get-allocated-plots/', get_allocated_plots, name='get_allocated_plots'),

    path('user-registration', user_registration, name="user-registration"),
    path('add-estate', add_estate, name="add-estate"),
    path('add-estate-plot/', add_estate_plot, name='add-estate-plot'),
    path('get-estate-details/<int:estate_id>/', get_estate_details, name='get-estate-details'),
    




    path('allocate-units/', allocate_units, name='allocate-units'),

    path('view-estate', view_estate, name="view-estate"),

    path('view_estate/<int:estate_id>/', view_estate, name='view-estate'),
    path('view_allocated_plot/<int:estate_id>/', view_allocated_plot, name='view-allocated-plot'),

    path('estate-plots/<int:id>/edit/', edit_estate_plot, name='edit-estate-plot'),
    path('estates/<int:id>/allocations/', view_allocated_plot, name='view-allocated-plot'),

    path('update_allocated_plot/', update_allocated_plot, name='update_allocated_plot'),
    path('delete-allocation/', delete_allocation, name='delete_allocation'),
    path('download-allocations/', download_allocations, name='download_allocations'),
    path('get_allocated_plot/<int:allocation_id>/', get_allocated_plot, name='get_allocated_plot'),

    # path('view-allocated-plots/', view_allocated_plot, name='view-allocated-plot'),
    path('view-allocated-plots/<int:id>/', view_allocated_plot, name='view-allocated-plot'),
    path('download-estate-pdf/<int:estate_id>/', download_estate_pdf, name='download_estate_pdf'),



    # floor plans
    path("add-floor-plan/", add_floor_plan, name="add_floor_plan"),
    path("estate_details/", estate_details, name="estate_details"),
    path('get-plot-sizes-for-floor-plan/<int:estate_id>/', get_plot_sizes_for_floor_plan, name='get_plot_sizes-for-floor-plan'),
    
    # prototypes
    path("add-prototypes/", add_prototypes, name="add_prototypes"),
    path('get-plot-sizes-for-prototypes/<int:estate_id>/', get_plot_sizes_for_prototypes, name='get_plot_sizes_for_prototypes'),
    
    # amenities
    path('update-estate-amenities/', update_estate_amenities, name='update_estate_amenities'),

    # Estate Layout
    path('add-estate-layout/', add_estate_layout, name='add_estate_layout'),

    # Estate Map
    path('add-estate-map/', add_estate_map, name='add_estate_map'),

    # Estate work progress
    path('add-progress-status/', add_progress_status, name='add_progress_status'),





    path('marketer-list', marketer_list, name="marketer-list"),
    path('admin-marketer/<int:pk>/', admin_marketer_profile, name='admin-marketer-profile'),
    path('marketer/<int:pk>/soft-delete/', marketer_soft_delete, name='marketer-soft-delete'),
    path('marketer/<int:pk>/restore/', marketer_restore, name='marketer-restore'),
    path('client', client, name="client"),
    # path('client/edit/<int:pk>/', edit_client, name='edit-client'),
    path('client/<int:pk>/soft-delete/', client_soft_delete, name='client-soft-delete'),
    path('client/<int:pk>/restore/', client_restore, name='client-restore'),
    path('user-profile', user_profile, name="user-profile"),

  


    path('chat-admin/chat/<int:client_id>/', admin_chat_view, name='admin_chat'),
    path('chat-admin/marketer-chat/<int:marketer_id>/', admin_marketer_chat_view, name='admin_marketer_chat'),
    path('chat-admin/client-chats/', admin_client_chat_list, name='admin_client_chat_list'),
    path('api/search-clients/', search_clients_api, name='search_clients_api'),
    path('api/search-marketers/', search_marketers_api, name='search_marketers_api'),
    
    path('chat_unread_count/', chat_unread_count, name='chat_unread_count'),
    path('message/<int:message_id>/', message_detail, name='message_detail'),
    # path('message_counts/', message_counts, name='message_counts'),


    # path('chat-admin/', admin_client_chat_list, name='admin_client_chat_list'),
    # path('chat-admin/chat/', admin_chat_view, name='admin_chat'),

    # CLIENT SIDE
    path('client-dashboard', client_dashboard, name="client-dashboard"),
    path('my-client-profile', my_client_profile, name="my-client-profile"),

    # path('client/<int:client_id>/transaction/<int:txn_id>/details/', transaction_details, name='client-transaction-details'),
    # path('client/<int:client_id>/transaction/<int:txn_id>/history/', payment_history, name='client-payment-history'),


    # path('client-message', client_message, name="client-message"),
    path('chat/', chat_view, name='chat'),
    # path('chat/<int:client_id>/', chat_view, name='chat'),
    path('chat/delete/<int:message_id>/', delete_message, name='delete_message'),
    path('client-new-property-request', client_new_property_request, name="client-new-property-request"),
    path('view-all-requests', view_all_requests, name="view-all-requests"),
    path('property-list', property_list, name="property-list"),
    path('view-client-estate/<int:estate_id>/<int:plot_size_id>/', view_client_estate, name='view-client-estate'),

    path('marketer/chat/', marketer_chat_view, name='marketer-chat'),

    # PROMO
    path("estates/", EstateListView.as_view(), name="estates-list"),
    path("promotions/", PromotionListView.as_view(), name="promotions-list"),
    path("promotions/<int:pk>/", PromotionDetailView.as_view(), name="promotion-detail"),
    
    # PRICE UPDATE
    path('api/price-update/<int:pk>/', price_update_json, name='api-price-update'),



    # MARKETER SIDE
    path('marketer-dashboard', marketer_dashboard, name="marketer-dashboard"),
    path('marketer-profile', marketer_profile, name="marketer-profile"),
    # path('marketer-profile/<int:pk>/', marketer_profile, name='marketer-profile'),
    path('client-records', client_records, name="client-records"),

    # path('marketer-notification', marketer_notification, name="marketer-notification"),
    # path('client-notification', client_notification, name="client-notification"),


    # CONFIGURATION ROUTES
    path('dashboard/', dashboard, name='dashboard'),
    path('user_profile/', user_profile, name='user_profile'),


    #NOTIFICATIONS
    path('send-announcement/', announcement_form, name='announcement-form'),
    path('send-announcement/', send_announcement, name='send-announcement'),


    path('api/notify-clients-marketer/', notify_clients_marketer, name='notify_clients_marketer'),
    path('api/notification-dispatch/<int:dispatch_id>/status/', notification_dispatch_status, name='notification_dispatch_status'),


    # path('notifications/client/', notifications_all, name='client_notification'),
    # path('notifications/marketer/', notifications_all, name='marketer_notification'),
    # path('notifications/<int:un_id>/', notification_detail, name='notification_detail'),
    # path('notifications/<int:un_id>/mark-read/', mark_notification_read, name='mark_notification_read'),

    # single notifications endpoint
    path('notifications/', notifications_all, name='notifications_all'),
    path('notifications/<int:un_id>/', notification_detail, name='notification_detail'),
    path('notifications/<int:un_id>/mark-read/', mark_notification_read, name='mark_notification_read'),

    # ESTATE
    path('delete-estate/<int:pk>/', delete_estate, name='delete-estate'),
    path('edit-estate/<int:pk>/', update_estate, name='edit_estate'),


    # MANAGEMENT DASHBOARD
    # SALES VOLUME
    path('sales-volume-metrics/', sales_volume_metrics, name='sales_volume_metrics'),

    # <!-- Land Plot Transactions -->
    path("ajax/allocation-info/", ajax_allocation_info, name="ajax_allocation_info"),

    path("transactions/add/", add_transaction, name="add-transaction"),
    path("ajax/client-marketer/", ajax_client_marketer, name="ajax_client_marketer"),
    path("ajax/client-allocations/", ajax_client_allocations, name="ajax_client_allocations"),
    path("ajax/allocation-info/", ajax_allocation_info, name="ajax_allocation_info"),



    #PAYMENT RECORD
    path('ajax/unpaid-installments/', ajax_get_unpaid_installments, name='ajax_get_unpaid_installments'),
    path('ajax/record-payment/', ajax_record_payment, name='ajax_record_payment'),

    path('receipt/<int:transaction_id>/', generate_receipt_pdf, name='generate-receipt-pdf'),
    path('payment-history/', ajax_payment_history, name='ajax_payment_history'),
    path('send-receipt/', ajax_send_receipt, name='ajax_send_receipt'),
    path('transaction/<int:transaction_id>/details/', ajax_transaction_details, name='transaction-details'),
    path('ajax/existing-transaction/', ajax_existing_transaction, name='ajax_existing_transaction'),

    path('payment/receipt/<str:reference_code>/', payment_receipt, name='payment_receipt'),

    # MARKETERS PERFORMANCE
    path('marketer-performance/', MarketerPerformanceView.as_view(), name='marketer_performance'),
    path('api/performance-data/', PerformanceDataAPI.as_view(), name='performance_data_api'),
    path('api/set-target/', SetTargetAPI.as_view(), name='set_target_api'),
    path('api/get-target/', GetGlobalTargetAPI.as_view(), name='get_target_api'),
    path('api/set-commission/', SetCommissionAPI.as_view(), name='set_commission_api'),
    path('api/get-commission/', GetCommissionAPI.as_view(), name='get_commission_api'),
    path('api/export-performance/', ExportPerformanceAPI.as_view(), name='export_performance_api'),

    # VALUE EVALUATION
    path("api/estate/<int:estate_id>/plot-sizes/", estate_plot_sizes, name="estate-plot-sizes"),
    path("api/estate/<int:estate_id>/bulk-price-data/", estate_bulk_price_data, name="estate-bulk-price-data"),
    path("api/property-price/add/", property_price_add, name="property-price-add"),
    path("api/property-price/bulk-update/", property_price_bulk_update, name="property-price-bulk-update"),
    path("api/property-price/<int:pk>/edit/", property_price_edit, name="property-price-edit"),
    path("api/property-price/<int:pk>/history/", property_price_history, name="property-price-history"),
    path("api/promo/create/", promo_create, name="promo-create"),
    path('api/promo/<int:promo_id>/update/', promo_update, name='promo_update'),
    # path("api/notify/clients/", notify_clients, name="notify-clients"),
    path('api/property-price/save/', property_price_save, name='property_price_save'),
    path('api/property-row/<str:row_key>/', property_row_html, name='property-row-html'),
    path('api/promo/estate/<int:estate_id>/active/', get_active_promo_for_estate, name='get_active_promo_for_estate'),
    path('api/property-price/<int:pk>/', property_price_detail, name='property-price-detail'),
    # path('promotions/<int:pk>/details/', promo_details, name='promo-details'),

    # # MESSAGING AND BIRTHDAY.
        
]
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)