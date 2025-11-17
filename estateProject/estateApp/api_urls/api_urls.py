from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework.authtoken.views import obtain_auth_token


from estateApp.api_views.api_viewsets import (
    CustomUserViewSet, MessageViewSet, PlotSizeViewSet, PlotNumberViewSet, EstateViewSet,
    PlotSizeUnitsViewSet, EstatePlotViewSet, PlotAllocationViewSet, NotificationViewSet,
    UserNotificationViewSet, EstateFloorPlanViewSet, EstatePrototypeViewSet, EstateAmenitieViewSet,
    EstateLayoutViewSet, EstateMapViewSet, ProgressStatusViewSet, PropertyRequestViewSet
)
from estateApp.api_views.custom_token_auth import CustomAuthToken
from estateApp.api_views.dashboard_views import admin_dashboard_data
# from estateApp.api_views.admin_estate_views import admin_estate_list
from estateApp.api_views.admin_estate_allocated_view import get_estate_full_allocation_details, update_allocated_plot_for_estate
from estateApp.api_views.edit_estate_plot_views import edit_estate_plot
from estateApp.api_views.update_allocated_plot import (
    update_allocated_plot, 
    load_plots)


from estateApp.api_views.estate_layout_upload import upload_estate_layout
from estateApp.api_views.estate_plot_prototype_upload import upload_estate_prototype
from estateApp.api_views.add_floor_plan import upload_floor_plan, get_plot_sizes
from estateApp.api_views.add_amenity_views import update_estate_amenities, get_available_amenities
from estateApp.api_views.add_progress_status_views import update_work_progress
from estateApp.api_views.add_estate_map_views import update_estate_map
from estateApp.api_views.estate_detail_views import (
    # estate_detail,
    get_estate_details,
    estate_list,
    estate_floor_plans,
    estate_prototypes,
    # estate_allocations,
    estate_map_detail,
    # get_estate_plot,
    update_estate_plot
)
from estateApp.api_views.add_estate_views import AddEstateView
# from estateApp.api_views.plot_size_number_views import PlotSizeView, PlotNumberView

from estateApp.api_views.chat_list_views import ClientChatListView
from estateApp.api_views.load_plots import load_plots
from estateApp.api_views.plot_allocation_delete import delete_allocation
from estateApp.api_views.download_allocations import download_allocations
from estateApp.api_views.download_estate_pdf import download_estate_pdf
from estateApp.api_views.user_registration_views import admin_user_registration
from estateApp.api_views.marketer_views import marketer_list, marketer_detail
from estateApp.api_views.client_views import client_list, client_detail
from estateApp.api_views.add_estate_plot_views import AddEstatePlotView, get_add_estate_plot_details
from estateApp.api_views.estate_list_views import get_estate_list, update_estate

from estateApp.api_views.plot_allocation_views  import (
    check_availability, available_plot_numbers, load_plots_for_plot_allocation, update_allocation
)


router = DefaultRouter()
router.register(r'users', CustomUserViewSet, basename='customuser')
router.register(r'messages', MessageViewSet, basename='message')
router.register(r'plot-sizes', PlotSizeViewSet, basename='plot-sizes')
router.register(r'plot-numbers', PlotNumberViewSet, basename='plot-numbers')
router.register(r'estates', EstateViewSet, basename='estate')
router.register(r'plotsizeunits', PlotSizeUnitsViewSet, basename='plotsizeunit')
router.register(r'estateplots', EstatePlotViewSet, basename='estateplot')
router.register(r'plotallocations', PlotAllocationViewSet, basename='plotallocation')
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'usernotifications', UserNotificationViewSet, basename='usernotification')
router.register(r'estatefloorplans', EstateFloorPlanViewSet, basename='estatefloorplan')
router.register(r'estateprototypes', EstatePrototypeViewSet, basename='estateprototype')
router.register(r'estateamenities', EstateAmenitieViewSet, basename='estateamenitie')
router.register(r'estatelayouts', EstateLayoutViewSet, basename='estatelayout')
router.register(r'estatemaps', EstateMapViewSet, basename='estatemap')
router.register(r'progressstatuses', ProgressStatusViewSet, basename='progressstatus')
router.register(r'propertyrequests', PropertyRequestViewSet, basename='propertyrequest')

urlpatterns = [
    path('', include(router.urls)),
    path('api-token-auth/', CustomAuthToken.as_view(), name='api_token_auth'),
    path('admin-user-registration/', admin_user_registration, name='admin_user_registration'),
    

    #ADMIN SIDE
    path('admin/dashboard-data/', admin_dashboard_data, name='admin_dashboard_data'),
    # path('admin/estate-list/', admin_estate_list, name='admin_estate_list'),
    path('estate-full-allocation-details/<int:estate_id>/', get_estate_full_allocation_details, name='get_estate_full_allocation_details'),
    path('update-allocated-plot-for-estate/<int:pk>/', update_allocated_plot_for_estate, name='update_allocated_plot_for_estate'),

    path('load-plots/', load_plots, name='load_plots'),
    path('delete-allocation/', delete_allocation, name='delete_allocation'),
    path('download-allocations/', download_allocations, name='download_allocations'),
    path('download-estate-pdf/<int:estate_id>/', download_estate_pdf, name='download_estate_pdf'),
    path('edit-estate-plot/<int:plot_id>/', edit_estate_plot, name='edit-estate-plot'),
    # path('update-allocated-plot/', update_allocated_plot, name='update_allocated_plot'),
    path('upload-estate-layout/', upload_estate_layout, name='upload-estate-layout'),
    path('upload-prototype/', upload_estate_prototype, name='upload-prototype'),
    path('get-plot-sizes/<int:estate_id>/', get_plot_sizes, name='get-plot-sizes'),
    path('upload-floor-plan/', upload_floor_plan, name='upload-floor-plan'),
    path('update-estate-amenities/', update_estate_amenities, name='update-estate-amenities'),
    path('get-available-amenities/', get_available_amenities, name='get-available-amenities'),
    path('update-work-progress/<int:estate_id>/', update_work_progress, name='upda.te-work-progress'),
    path('update-estate-map/<int:estate_id>/', update_estate_map, name='update_estate_map'),

    path('marketers/', marketer_list, name='marketer_list'),
    # path('marketers/<int:pk>/', marketer_detail, name='admin-marketer-profile'),
    #  path('marketers/<int:pk>/', MarketerDetailView.as_view(), name='marketer-detail'),
    path('clients/', client_list, name='client-list'),
    path('client/<int:pk>/', client_detail, name='client-detail'),

    # ESTATE DETAILS
    path('estates/', estate_list, name='estate-list'),
    path('estates/<int:pk>/', update_estate, name='estate-detail'),

    # estate plot update
    # path('estates/<int:estate_id>/plot/', get_estate_plot, name='get-estate-plot'),
    # path('estates/<int:estate_id>/plot/update/', update_estate_plot, name='update-estate-plot'),
    path('estates/<int:estate_id>/plot/', update_estate_plot, name='edit-estate-plot'),


    path('estate-details/<int:estate_id>/', get_estate_details, name='get_estate_details'),
    path('estate-map/<int:estate_id>/', estate_map_detail, name='get_estate_map_detail'),
    path('estate-list/', estate_list, name='estate_list'),
    path('estate-floor-plans/<int:estate_id>/', estate_floor_plans, name='estate_floor_plans'),
    path('estate-prototypes/<int:estate_id>/', estate_prototypes, name='estate_prototypes'),
    # path('estate-allocations/<int:estate_id>/', estate_allocations, name='estate_allocations'),


    # path('get-add-estate-plot-details/<int:estate_id>/', get_add_estate_plot_details, name='get-add-estate-plot-details'),
    # path('add-estate-plot/', AddEstatePlotView.as_view(), name='api-add-estate-plot'),
    
    # ADD ESTATE
    # path('add-estate/', AddEstateView.as_view(), name='add-estate'),
    # path('add-estate-plot/', AddEstatePlotView.as_view(), name='add-estate-plot'),

    # # PLOT ALLOCATION
    path('load-plots-for-plot-allocation/', load_plots_for_plot_allocation, name='load-plots-for-plot-allocation'),
    path('check-availability/<int:size_id>/', check_availability, name='check_availability'),
    path('available-plot-numbers/<int:estate_id>/', available_plot_numbers, name='available_plot_numbers'),
    path('update-allocation/', update_allocation, name='update_allocation'),

    # ADD ALLOCATED PLOT
    path('get-add-estate-plot-details/<int:estate_id>/', get_add_estate_plot_details, name='get_add_estate_plot_details'),
    path('add-estate-plot/', AddEstatePlotView.as_view(), name='api-add-estate-plot'),
    path('estates/', get_estate_list, name='get_estate_list'),

    # CLIENT CHAT LIST
    # path('client-chats/', ClientChatListView.as_view(), name='admin_client_chat_list'),
    
    # path('client-chats/<uuid:client_id>/', ChatThreadView.as_view(), name='admin_chat_thread'),


]

