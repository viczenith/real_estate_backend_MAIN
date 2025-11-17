from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth import login, authenticate
from .forms import *
from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from .models import *
import random
from types import SimpleNamespace
from django.contrib.auth import authenticate, update_session_auth_hash
from django.contrib.admin.views.decorators import staff_member_required
from django.views.decorators.csrf import csrf_exempt
from django.utils.timezone import now
from django.utils import timezone
import datetime as dt
from datetime import datetime, timedelta
from django.utils.dateparse import parse_date
from itertools import islice


from django.db import DatabaseError, IntegrityError, transaction
import csv
from django.http import Http404, HttpResponse, HttpResponseNotAllowed
from django.core.exceptions import ValidationError
import json
from django.http import JsonResponse, HttpResponseBadRequest

from django.db.models import Prefetch, Count, Max, Q, F, Value, Sum, DecimalField, OuterRef, Subquery, Exists, ExpressionWrapper
from django.db.models.functions import Concat, Coalesce

from django.contrib.auth.mixins import LoginRequiredMixin
from django.views.generic import TemplateView, FormView, View

from django.template.loader import render_to_string, get_template

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.platypus import Table, TableStyle


# NOTIFICATIONS
from django.core.mail import send_mail
from django.conf import settings
from django.utils.html import strip_tags
from django.views.generic.edit import FormView 
from django.views.decorators.csrf import csrf_protect
from django.contrib.auth.views import LoginView
from django.urls import reverse_lazy


# MANAGEMENT DASHBOARD
# from weasyprint import HTML, CSS  # Commented out due to Windows compatibility issues
from xhtml2pdf import pisa
from django.urls             import reverse
from django.views.decorators.http import require_http_methods, require_GET, require_POST, require_http_methods
from django.utils.decorators import method_decorator
from django.contrib.auth import get_user_model
import uuid
from io import BytesIO
User = get_user_model()
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation
from dateutil.relativedelta import relativedelta
import logging
from math import ceil
from .services.geoip import lookup_ip_location, extract_client_ip
from DRF.shared_drf.push_service import send_chat_message_push, send_user_notification_push
from .tasks import (
    BATCH_SIZE,
    dispatch_notification_stream,
    dispatch_notification_stream_sync,
    is_celery_worker_available,
)


logger = logging.getLogger(__name__)


SUPPORT_ROLES = ('admin', 'support')


def custom_csrf_failure_view(request, reason=""):
    return render(request, 'csrf_failure.html', {"reason": reason}, status=403)


# HOME VIEW
class HomeView(LoginRequiredMixin, TemplateView):
    template_name = 'home.html'


@login_required
def admin_dashboard(request):
    total_clients = CustomUser.objects.filter(role='client').count()
    total_marketers = CustomUser.objects.filter(role='marketer').count()
    
    # Estate Plots (existing code)
    estates = Estate.objects.prefetch_related(
        Prefetch('estate_plots__plotsizeunits',
                 queryset=PlotSizeUnits.objects.annotate(
                     allocated=Count('allocations', filter=Q(allocations__payment_type='full')),
                     reserved=Count('allocations', filter=Q(allocations__payment_type='part'))
                 ))
    ).all()

    # === NEW CHART DATA COLLECTION START ===
    # Prepare data for allocation chart
    estate_names = []
    allocated_data = []
    reserved_data = []
    total_data = []
    estate_names = []
    total_data = []

    
    for estate in estates:
        estate_total_allocated = 0
        estate_total_reserved = 0
        
        # Traverse through the estate plots and their plot size units
        for estate_plot in estate.estate_plots.all():
            for plot_size_unit in estate_plot.plotsizeunits.all():
                estate_total_allocated += getattr(plot_size_unit, 'allocated', 0)
                estate_total_reserved += getattr(plot_size_unit, 'reserved', 0)
        
        estate_names.append(estate.name)
        allocated_data.append(estate_total_allocated)
        reserved_data.append(estate_total_reserved)
        total_data.append(estate_total_allocated + estate_total_reserved)
    # === NEW CHART DATA COLLECTION END ===

    
    # Existing allocation counts
    total_allocations = PlotAllocation.objects.filter(
        payment_type='full',
        plot_number__isnull=False 
    ).count()

    pending_allocations = PlotAllocation.objects.filter(
        payment_type='part',
        plot_number__isnull=True
    ).count()

    # Global Notification (existing code)
    if request.user.role == 'admin':
        global_message_count = Message.objects.filter(sender__role='client', recipient=request.user, is_read=False).count()
        unread_messages = Message.objects.filter(sender__role='client', recipient=request.user, is_read=False).order_by('-date_sent')[:5]
    else:
        global_message_count = Message.objects.filter(sender__role='admin', recipient=request.user, is_read=False).count()
        unread_messages = Message.objects.filter(sender__role='admin', recipient=request.user, is_read=False).order_by('-date_sent')[:5]

    # Add chart data to context
    context = {
        'global_message_count': global_message_count,
        'unread_messages': unread_messages,
        'total_clients': total_clients,
        'total_marketers': total_marketers,
        'estates': estates,
        'total_allocations': total_allocations,
        'pending_allocations': pending_allocations,
        # === NEW CHART CONTEXT ADDITION ===
        'chart_data': {
            'estates': estate_names,
            'allocated': allocated_data,
            'reserved': reserved_data,
            'total': total_data
        }
    }
    return render(request, 'admin_side/index.html', context)

@login_required
def add_plotsize(request):
    from django.http import JsonResponse
    from .models import PlotSize, PlotSizeUnits, Estate
    from django.db.models import Count, Q
    
    if request.method == 'POST':
        if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
            action = request.POST.get('action', 'add')
            
            if action == 'add':
                size = request.POST.get('size', '').strip()
                
                if not size:
                    return JsonResponse({'success': False, 'message': 'Plot size is required'})
                
                # Check if plot size already exists
                if PlotSize.objects.filter(size__iexact=size).exists():
                    return JsonResponse({'success': False, 'message': f'Plot size "{size}" already exists'})
                
                try:
                    PlotSize.objects.create(size=size)
                    return JsonResponse({'success': True, 'message': f'Plot size "{size}" added successfully!'})
                except Exception as e:
                    return JsonResponse({'success': False, 'message': str(e)})
            
            elif action == 'update':
                plot_size_id = request.POST.get('plot_size_id')
                new_size = request.POST.get('new_size', '').strip()
                
                if not new_size:
                    return JsonResponse({'success': False, 'message': 'New plot size is required'})
                
                try:
                    plot_size = PlotSize.objects.get(id=plot_size_id)
                    old_size = plot_size.size
                    
                    # Check if new size already exists (excluding current)
                    if PlotSize.objects.filter(size__iexact=new_size).exclude(id=plot_size_id).exists():
                        return JsonResponse({'success': False, 'message': f'Plot size "{new_size}" already exists'})
                    
                    # Update the plot size
                    plot_size.size = new_size
                    plot_size.save()
                    
                    return JsonResponse({
                        'success': True, 
                        'message': f'Plot size updated from "{old_size}" to "{new_size}" across all estates and allocations!'
                    })
                except PlotSize.DoesNotExist:
                    return JsonResponse({'success': False, 'message': 'Plot size not found'})
                except Exception as e:
                    return JsonResponse({'success': False, 'message': str(e)})
    
    # Annotate plot sizes with estate count and estate names
    plot_sizes_data = []
    for plot_size in PlotSize.objects.all().order_by('size'):
        # Count estates using this plot size through PlotSizeUnits
        estate_count = PlotSizeUnits.objects.filter(plot_size=plot_size).values('estate_plot__estate').distinct().count()
        
        # Get estate names
        estate_names = []
        if estate_count > 0:
            estate_plots = PlotSizeUnits.objects.filter(plot_size=plot_size).select_related('estate_plot__estate').distinct()
            estate_names = [ep.estate_plot.estate.name for ep in estate_plots]
        
        plot_sizes_data.append({
            'id': plot_size.id,
            'size': plot_size.size,
            'estate_count': estate_count,
            'estate_names': estate_names,
            'is_assigned': estate_count > 0
        })
    
    return render(request, "admin_side/add_plotsize.html", {'plot_sizes': plot_sizes_data})

@login_required
def add_plotnumber(request):
    from django.http import JsonResponse
    from .models import PlotNumber, PlotAllocation
    from .ws_utils import broadcast_user_notification
    
    if request.method == 'POST':
        if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
            action = request.POST.get('action', 'add')
            
            if action == 'add':
                number = request.POST.get('number', '').strip()
                
                if not number:
                    return JsonResponse({'success': False, 'message': 'Plot number is required'})
                
                # Check if plot number already exists
                if PlotNumber.objects.filter(number__iexact=number).exists():
                    return JsonResponse({'success': False, 'message': f'Plot number "{number}" already exists'})
                
                try:
                    PlotNumber.objects.create(number=number)
                    return JsonResponse({'success': True, 'message': f'Plot number "{number}" added successfully!'})
                except Exception as e:
                    return JsonResponse({'success': False, 'message': str(e)})
            
            elif action == 'update':
                plot_number_id = request.POST.get('plot_number_id')
                new_number = request.POST.get('number', '').strip()
                
                if not new_number:
                    return JsonResponse({'success': False, 'message': 'New plot number is required'})
                
                try:
                    plot_number = PlotNumber.objects.get(id=plot_number_id)
                    old_number = plot_number.number
                    
                    # Check if new number already exists (excluding current)
                    if PlotNumber.objects.filter(number__iexact=new_number).exclude(id=plot_number_id).exists():
                        return JsonResponse({'success': False, 'message': f'Plot number "{new_number}" already exists'})
                    
                    # Update the plot number
                    plot_number.number = new_number
                    plot_number.save()
                    
                    return JsonResponse({
                        'success': True, 
                        'message': f'Plot number updated from "{old_number}" to "{new_number}" across all estates and client allocations!'
                    })
                except PlotNumber.DoesNotExist:
                    return JsonResponse({'success': False, 'message': 'Plot number not found'})
                except Exception as e:
                    return JsonResponse({'success': False, 'message': str(e)})
    
    # Annotate plot numbers with allocation data (client and estate info)
    plot_numbers_data = []
    for plot_number in PlotNumber.objects.all().order_by('number'):
        # Get all allocations for this plot number
        allocations = PlotAllocation.objects.filter(
            plot_number=plot_number
        ).select_related('client', 'estate').distinct()
        
        allocation_count = allocations.count()
        
        # Build detailed allocation info: "Client Name - Estate Name"
        allocation_details = []
        if allocation_count > 0:
            for alloc in allocations:
                client_name = alloc.client.full_name if alloc.client else "Unknown Client"
                estate_name = alloc.estate.name if alloc.estate else "Unknown Estate"
                allocation_details.append(f"{client_name} - {estate_name}")
        
        plot_numbers_data.append({
            'id': plot_number.id,
            'number': plot_number.number,
            'allocation_count': allocation_count,
            'allocation_details': allocation_details,
            'is_assigned': allocation_count > 0
        })
    
    return render(request, "admin_side/add_plotnumber.html", {'plot_numbers': plot_numbers_data})

@login_required
def delete_plotsize(request, pk):
    from django.http import JsonResponse
    from .models import PlotSize, PlotSizeUnits
    
    if request.method == 'POST':
        try:
            plot_size = PlotSize.objects.get(id=pk)
            size_name = plot_size.size
            
            # Check if plot size is assigned to any estate
            estate_count = PlotSizeUnits.objects.filter(plot_size=plot_size).values('estate_plot__estate').distinct().count()
            
            if estate_count > 0:
                return JsonResponse({
                    'success': False, 
                    'message': f'Cannot delete "{size_name}". It is currently assigned to {estate_count} estate(s). Please use the Edit function to modify it instead.'
                })
            
            plot_size.delete()
            return JsonResponse({'success': True, 'message': f'Plot size "{size_name}" deleted successfully!'})
        except PlotSize.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Plot size not found'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': f'Error: {str(e)}'})
    
    return JsonResponse({'success': False, 'message': 'Invalid request method'})

@login_required
def delete_plotnumber(request, pk):
    from django.http import JsonResponse
    from .models import PlotNumber, PlotAllocation
    
    if request.method == 'POST':
        try:
            plot_number = PlotNumber.objects.get(id=pk)
            number_name = plot_number.number
            
            # Check if plot number is allocated to any client/estate
            allocation_count = PlotAllocation.objects.filter(plot_number=plot_number).count()
            
            if allocation_count > 0:
                return JsonResponse({
                    'success': False, 
                    'message': f'Cannot delete "{number_name}". It is currently allocated to {allocation_count} client(s). Please use the Edit function to modify it instead.'
                })
            
            plot_number.delete()
            return JsonResponse({'success': True, 'message': f'Plot number "{number_name}" deleted successfully!'})
        except PlotNumber.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Plot number not found'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': f'Error: {str(e)}'})
    
    return JsonResponse({'success': False, 'message': 'Invalid request method'})

@login_required
def management_dashboard(request):
    STATUSES = ['Fully Paid', 'Part Payment', 'Pending', 'Overdue']

    transactions = Transaction.objects.select_related(
        'client', 'marketer',
        'allocation__estate',
        'allocation__plot_size_unit__plot_size'
    ).all()

    txn_qs = Transaction.objects.filter(allocation_id=OuterRef('pk'))
    pending_allocations = PlotAllocation.objects.annotate(
        has_txn=Exists(txn_qs)
    ).filter(has_txn=False).select_related('client', 'estate')

    today = date.today()
    active_promos_qs = PromotionalOffer.objects.filter(
        start__lte=today, end__gte=today
    )
    estates = Estate.objects.prefetch_related(
        'estate_plots__plotsizeunits__plot_size',
        Prefetch('promotional_offers', queryset=active_promos_qs, to_attr='active_promos')
    ).all()

    current_promos = PromotionalOffer.objects.filter(
        start__lte=today,
        end__gte=today
    ).prefetch_related('estates')


    existing_prices = {
        (pp.estate_id, pp.plot_unit_id): pp
        for pp in PropertyPrice.objects.select_related(
            'estate', 'plot_unit__plot_size'
        ).all()
    }

    rows = []
    for estate in estates:
        active = estate.active_promos[0] if getattr(estate, 'active_promos', []) else None
        for ep in estate.estate_plots.all():
            for unit in ep.plotsizeunits.all():
                key = (estate.id, unit.id)
                if key in existing_prices:
                    pp = existing_prices[key]
                    
                    # Convert current price to float for calculation
                    current_price = float(pp.current)
                    
                    # Apply promo discount if active
                    if active:
                        discount_factor = float(1 - active.discount / 100)
                        discounted_price = Decimal(str(current_price * discount_factor))
                    else:
                        discounted_price = pp.current
                    
                    # Calculate percentages using discounted price
                    if pp.previous:
                        percent_change = (float(discounted_price) - float(pp.previous)) / float(pp.previous) * 100
                        pp.percent_change = Decimal(str(percent_change))
                    if pp.presale:
                        overtime = (float(discounted_price) - float(pp.presale)) / float(pp.presale) * 100
                        pp.overtime = Decimal(str(overtime))
                    
                    # Store display values
                    pp.display_current = discounted_price
                    pp.active_promo = active
                    rows.append(pp)
                else:
                    class DummyPrice:
                        def __init__(self, est, unit, active_promo):
                            self.id = None
                            self.estate = est
                            self.plot_unit = unit
                            self.presale = None
                            self.previous = None
                            self.current = None
                            self.percent_change = None
                            self.overtime = None
                            self.display_current = None
                            self.effective = None
                            self.notes = None
                            self.active_promo = active_promo
                    rows.append(DummyPrice(estate, unit, active))

    context = {
        'all_clients': ClientUser.objects.all(),
        'estates': estates,
        'marketers': MarketerUser.objects.all(),
        'transactions': transactions,
        'pending_allocations': pending_allocations,
        'statuses': STATUSES,
        'rows': rows,
        'today': today,
        'current_promos': current_promos,
    }

    return render(request, "admin_side/management-dashboard.html", context)


def estate_allocation_data(request):
    estates = []
    allocated_data = []
    reserved_data = []
    total_data = []
    
    for estate in Estate.objects.all():
        total_allocated = 0
        total_reserved = 0
        
        for size_unit in estate.estate_plots.plotsizeunits.all():
            total_allocated += size_unit.full_allocations
            total_reserved += size_unit.part_allocations
        
        estates.append(estate.name)
        allocated_data.append(total_allocated)
        reserved_data.append(total_reserved)
        total_data.append(total_allocated + total_reserved)
    
    return JsonResponse({
        'estates': estates,
        'allocated': allocated_data,
        'reserved': reserved_data,
        'total': total_data
    })


def get_allocated_plots(request):
    allocated_plots = PlotAllocation.objects.values('estate_id', 'plot_size_id', 'plot_number_id')
    return JsonResponse(list(allocated_plots), safe=False)


def user_registration(request):
    # Fetch all users with the 'marketer' role
    marketers = CustomUser.objects.filter(role='marketer')

    if request.method == 'POST':
        # Extract form data
        full_name = request.POST.get('name')
        address = request.POST.get('address')
        phone = request.POST.get('phone')
        email = request.POST.get('email')
        role = request.POST.get('role')
        country = request.POST.get('country')
        
        # Only assign a marketer if the role is 'client'
        marketer = None
        if role == 'client':
            marketer_id = request.POST.get('marketer')
            if marketer_id:
                try:
                    marketer = CustomUser.objects.get(id=marketer_id)
                except CustomUser.DoesNotExist:
                    messages.error(request, f"Marketer with ID {marketer_id} does not exist.")
                    return render(request, 'admin_side/user_registration.html', {'marketers': marketers})
        
        date_of_birth = request.POST.get('date_of_birth')
        
        # Validate the email (check if it's already registered)
        if CustomUser.objects.filter(email=email).exists():
            messages.error(request, f"Email {email} is already registered.")
            return render(request, 'admin_side/user_registration.html', {'marketers': marketers})
        
        # Use the provided password or generate one
        password = request.POST.get('password')
        
        # Handle user creation based on role
        if role == 'admin':
            # Save to AdminUser table
            admin_user = AdminUser(
                email=email,
                full_name=full_name,
                address=address,
                phone=phone,
                date_of_birth=date_of_birth,
                country=country,
                is_staff=True,  # Admins are staff, but not superusers
            )
            admin_user.set_password(password)
            admin_user.save()
            messages.success(request, f"<strong>{full_name}</strong> has been successfully registered as <strong>Admin User</strong>!")
        
        elif role == 'client':
            # Validate marketer assignment - REQUIRED for clients
            marketer_id = request.POST.get('marketer')
            if not marketer_id:
                messages.error(request, "Please assign a marketer to this client. Marketer assignment is required.")
                return render(request, 'admin_side/user_registration.html', {'marketers': marketers})
            
            try:
                assigned_marketer = MarketerUser.objects.get(id=marketer_id)
            except MarketerUser.DoesNotExist:
                messages.error(request, f"Selected marketer does not exist. Please select a valid marketer.")
                return render(request, 'admin_side/user_registration.html', {'marketers': marketers})
            
            # Save to ClientUser table
            client_user = ClientUser(
                email=email,
                full_name=full_name,
                address=address,
                phone=phone,
                date_of_birth=date_of_birth,
                country=country,
                assigned_marketer=assigned_marketer
            )
            client_user.set_password(password)
            client_user.save()
            messages.success(request, f"<strong>{full_name}</strong> has been successfully registered and assigned to <strong>{assigned_marketer.full_name}!</strong>")
        
        elif role == 'marketer':
            # Save to MarketerUser table
            marketer_user = MarketerUser(
                email=email,
                full_name=full_name,
                address=address,
                phone=phone,
                date_of_birth=date_of_birth,
                country=country,
            )
            marketer_user.set_password(password)
            marketer_user.save()
            messages.success(request, f"Marketer, <strong>{full_name}</strong> has been successfully registered!")

        elif role == 'support':
            support_user = SupportUser(
                email=email,
                full_name=full_name,
                address=address,
                phone=phone,
                date_of_birth=date_of_birth,
                country=country,
            )
            support_user.set_password(password)
            support_user.save()
            messages.success(request, f"Support User, <strong>{full_name}</strong> has been successfully registered!")

        
        return redirect('user-registration')

    return render(request, 'admin_side/user_registration.html', {'marketers': marketers})


# ESTATE FUNCTIONS
@login_required
def view_estate(request):
    estates = Estate.objects.all().order_by('-date_added')
    context = {
        'estates': estates,  # Changed key from estate_plots to estates
    }
    return render(request, 'admin_side/view_estate.html', context)


@login_required
def update_estate(request, pk):
    # Fetch the estate instance or return a 404 if not found
    estate = get_object_or_404(Estate, pk=pk)

    if request.method == "POST":
        # Retrieve updated values from the form
        name = request.POST.get('name')
        location = request.POST.get('location')
        title_deed = request.POST.get('title_deed')
        estate_size = request.POST.get('estate_size')  # Retrieve estate size

        # Debugging: Print the received values
        print(f"Received Data -> Name: {name}, Location: {location}, Title Deed: {title_deed}, Estate Size: {estate_size}")

        # Ensure required fields are present
        if not name or not location or not title_deed or not estate_size:
            messages.error(request, "All fields are required.")
            return redirect('edit-estate', pk=pk)

        # Update the estate object
        estate.name = name
        estate.location = location
        estate.title_deed = title_deed
        estate.estate_size = estate_size  # Update the estate size
        estate.save()  # Save to the database

        messages.success(request, f"{estate.name} updated successfully.")
        return redirect('view-estate')  # Redirect to estates list or details page

    # Render the form with existing estate data
    context = {
        'estate': estate,
    }
    return render(request, 'admin_side/edit_estate.html', context)

@login_required
def delete_estate(request, pk):
    """Delete an estate and return a success message on the same page."""
    estate = get_object_or_404(Estate, pk=pk)
    if request.method == "POST":
        estate.delete()
        messages.success(request, "Estate deleted successfully!")
        return redirect('view-estate')
    messages.error(request, "Invalid request. Please try again.")
    return redirect('view-estate')

@csrf_exempt
def add_estate(request):
    if request.method == "POST":
        # Handle form submission and save the estate
        estate_name = request.POST.get('name')
        estate_location = request.POST.get('location')
        estate_size = request.POST.get('estate_size')
        estate_title_deed = request.POST.get('title_deed')
        
        # Create the Estate instance and save it
        estate = Estate.objects.create(
            name=estate_name,
            location=estate_location,
            estate_size=estate_size,
            title_deed=estate_title_deed
        )

        return JsonResponse({'message': f'{estate.name} added successfully!', 'estate_id': estate.id})

    # For GET request, render the form to add an estate
    return render(request, 'admin_side/add_estate.html', {})


# ESTATE PLOTS AND ALLOCATION FUNCTIONS

@login_required
def plot_allocation(request):
    if request.method == "POST":
        try:
            with transaction.atomic():
                # Lock the PlotSizeUnits record for update
                plot_size_unit = get_object_or_404(
                    PlotSizeUnits.objects.select_for_update(),
                    id=request.POST.get('plotSize')
                )
                
                # Calculate allocated + reserved units
                allocated_reserved = plot_size_unit.full_allocations + plot_size_unit.part_allocations
                
                # Check if available units are exhausted
                if allocated_reserved >= plot_size_unit.total_units:
                    raise ValidationError(
                        f"{plot_size_unit.plot_size.size} sqm units are completely allocated"
                    )
                
                client = get_object_or_404(CustomUser, id=request.POST.get('clientName'))

                # Create the allocation (note: each allocation is linked to an estate via the plot_size_unit)
                allocation = PlotAllocation(
                    plot_size_unit=plot_size_unit,
                    client=client,
                    estate=plot_size_unit.estate_plot.estate,
                    plot_size=plot_size_unit.plot_size,
                    payment_type=request.POST.get('paymentType'),
                    plot_number_id=request.POST.get('plotNumber')
                )

                allocation.full_clean()
                allocation.save()

                # Optionally, update available_units (if not using a property)
                plot_size_unit.available_units = plot_size_unit.total_units - (allocated_reserved + 1)
                plot_size_unit.save()

                messages.success(request, f"<strong>{client}</strong> Allocation successful")
                return redirect('plot-allocation')
        except ValidationError as e:
            messages.error(request, str(e))
        except Exception as e:
            messages.error(request, f"Allocation failed: {str(e)}")
        return redirect('plot-allocation')
    else:
        # GET request handling
        clients = CustomUser.objects.filter(role='client')
        estates = Estate.objects.all()
        context = {
            'clients': clients,
            'estates': estates,
            # Include any additional data your template might need
        }
        return render(request, 'admin_side/plot_allocation.html', context)

def load_plots(request):
    estate_id = request.GET.get('estate_id')
    allocation_id = request.GET.get('allocation_id')  # Get allocation ID for update scenarios
    
    plot_size_units = PlotSizeUnits.objects.filter(
        estate_plot__estate_id=estate_id,
        available_units__gt=0
    ).select_related('plot_size').annotate(
        formatted_size=Concat(F('plot_size__size'), Value(' sqm'))
    ).values('id', 'formatted_size', 'plot_size__id', 'available_units')
    
    # Get available plot numbers
    # If allocation_id is provided, include its plot number even if allocated
    if allocation_id:
        try:
            current_allocation = PlotAllocation.objects.get(id=allocation_id)
            current_plot_id = current_allocation.plot_number.id if current_allocation.plot_number else None
            
            # Get unallocated plots OR the current allocation's plot
            if current_plot_id:
                plot_numbers = PlotNumber.objects.filter(
                    estates__estate_id=estate_id
                ).filter(
                    Q(plotallocation__isnull=True) | Q(id=current_plot_id)
                ).distinct().values('id', 'number')
            else:
                plot_numbers = PlotNumber.objects.filter(
                    estates__estate_id=estate_id
                ).exclude(
                    plotallocation__isnull=False
                ).values('id', 'number')
        except PlotAllocation.DoesNotExist:
            plot_numbers = PlotNumber.objects.filter(
                estates__estate_id=estate_id
            ).exclude(
                plotallocation__isnull=False
            ).values('id', 'number')
    else:
        # Original behavior: only unallocated plots
        plot_numbers = PlotNumber.objects.filter(
            estates__estate_id=estate_id
        ).exclude(
            plotallocation__isnull=False
        ).values('id', 'number')
    
    
    return JsonResponse({
        'plot_size_units': list(plot_size_units),
        'plot_numbers': list(plot_numbers)
    })


def check_availability(request, size_id):
    try:
        size = PlotSizeUnits.objects.get(id=size_id)
        allocated_reserved = size.full_allocations + size.part_allocations
        available_units = size.total_units - allocated_reserved
        message = f"{size.plot_size.size} sqm units are available" if available_units > 0 else f"{size.plot_size.size} sqm units are completely allocated"
        return JsonResponse({'available': available_units, 'message': message})
    except PlotSizeUnits.DoesNotExist:
        return JsonResponse({'available': 0, 'message': 'Invalid plot size selected'}, status=404)


def available_plot_numbers(request, estate_id):
    plot_numbers = PlotNumber.objects.filter(
        estate_id=estate_id
    ).exclude(
        plotallocation__isnull=False  # Ensures the plot has not been allocated
    ).values('id', 'number')  # Retrieve only the necessary fields

    # Check if plot numbers exist
    if not plot_numbers:
        return JsonResponse({'error': 'No available plot numbers found.'}, status=404)

    return JsonResponse(list(plot_numbers), safe=False)


def get_allocation(request, allocation_id):
    allocation = get_object_or_404(PlotAllocation, id=allocation_id)
    return JsonResponse({
        'id': allocation.id,
        'client': allocation.client.full_name,
        'payment_type': allocation.payment_type,
        'plot_number': allocation.plot_number.id if allocation.plot_number else None
    })


def update_allocated_plot(request):
    User = get_user_model()

    if request.method == "POST":
        allocation_id = request.POST.get('allocation_id')
        client_id = request.POST.get('clientName')
        estate_id = request.POST.get('estateName')
        plot_size_unit_id = request.POST.get('plotSize')
        payment_type = request.POST.get('paymentType')
        plot_number_id = request.POST.get('plotNumber', None)

        try:
            if allocation_id:
                allocation = PlotAllocation.objects.get(id=allocation_id)

                # Assign new values
                allocation.client = User.objects.get(id=client_id)
                allocation.estate = Estate.objects.get(id=estate_id)
                allocation.plot_size_unit = PlotSizeUnits.objects.get(id=plot_size_unit_id)
                allocation.plot_size = allocation.plot_size_unit.plot_size
                allocation.payment_type = payment_type

                if payment_type == 'full':
                    if not plot_number_id:
                        raise ValueError("Plot number is required for full payment")
                    allocation.plot_number = PlotNumber.objects.get(id=plot_number_id)
                else:
                    allocation.plot_number = None

                allocation.save()
                messages.success(request, "Allocation updated successfully.")
            else:
                messages.error(request, "Update not successful.")
                return redirect(request.path)

            return redirect(request.path + "?allocation_id=" + str(allocation.id))

        except Exception as e:
            messages.error(request, str(e))
            fallback_url = request.path
            if allocation_id:
                fallback_url += "?allocation_id=" + str(allocation_id)
            return redirect(request.META.get('HTTP_REFERER', fallback_url))

    # GET: Render the update form.
    allocation = None
    allocation_id = request.GET.get('allocation_id')
    if allocation_id:
        try:
            allocation = PlotAllocation.objects.get(id=allocation_id)
        except PlotAllocation.DoesNotExist:
            messages.error(request, "Allocation not found.")

    # Only display plot sizes that are NOT completely allocated (i.e. all units allocated with full payment)
    if allocation and allocation.estate:
        qs = PlotSizeUnits.objects.filter(
            estate_plot__estate=allocation.estate
        ).annotate(
            full_alloc_count=Count(
                'allocations',
                filter=Q(allocations__payment_type='full', allocations__plot_number__isnull=False)
            )
        )
        # When editing, always include the currently assigned plot size unit.
        if allocation.plot_size_unit:
            qs = qs.filter(Q(full_alloc_count__lt=F('total_units')) | Q(id=allocation.plot_size_unit.id))
        else:
            qs = qs.filter(full_alloc_count__lt=F('total_units'))
        plot_size_units = qs.distinct()

        plot_numbers = PlotNumber.objects.filter(estates__estate=allocation.estate).distinct()
    else:
        plot_size_units = []
        plot_numbers = []

    context = {
        'clients': User.objects.filter(role='client'),
        'estates': Estate.objects.all(),
        'allocation': allocation,
        'plot_size_units': plot_size_units,
        'plot_numbers': plot_numbers,
    }
    return render(request, 'admin_side/update_allocated_plot.html', context)


def get_allocated_plot(request, allocation_id):
    allocation = get_object_or_404(PlotAllocation, id=allocation_id)
    data = {
        'client_id': allocation.client.id,
        'estate_id': allocation.estate.id,
        'plot_size_unit_id': allocation.plot_size_unit.id if allocation.plot_size_unit else None,
        'payment_type': allocation.payment_type,
        'plot_number_id': allocation.plot_number.id if allocation.plot_number else None,
    }
    return JsonResponse(data)


@login_required
def delete_allocation(request):
    if request.method == 'POST':
        try:
            allocation_id = json.loads(request.body).get('allocation_id')
            allocation = get_object_or_404(PlotAllocation, id=allocation_id)
            
            # Store related objects before deletion
            plot_size_unit = allocation.plot_size_unit
            plot_number = allocation.plot_number
            
            with transaction.atomic():
                # Delete the allocation
                allocation.delete()
                
                # Recalculate plot size unit availability
                plot_size_unit.save()  # Triggers save() which updates available_units
                
                # Free up plot number if it was a full allocation
                if plot_number:
                    plot_number.is_allocated = False
                    plot_number.save()
                    
            return JsonResponse({'success': True})
            
        except Exception as e:
            return JsonResponse({'success': False, 'error': str(e)}, status=400)
    
    return JsonResponse({'success': False, 'error': 'Invalid request'})

def download_allocations(request):
    estate_id = request.GET.get('estate_id')
    
    allocations = PlotAllocation.objects.all()
    estate_name = "All_Estates"

    if estate_id:
        try:
            estate = Estate.objects.get(id=estate_id)
            estate_name = estate.name.replace(" ", "_")  # Replace spaces with underscores for filename
            allocations = allocations.filter(estate=estate)
        except Estate.DoesNotExist:
            return HttpResponse("Estate not found", status=404)

    # Prepare CSV response
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = f'attachment; filename="{estate_name}_Allocation.csv"'

    writer = csv.writer(response)
    writer.writerow([
        'Client Name', 'Estate', 'Plot Size', 
        'Payment Type', 'Plot Number', 'Date Allocated'
    ])

    for alloc in allocations:
        writer.writerow([
            alloc.client.full_name,
            alloc.estate.name,
            f"{alloc.plot_size.size}",
            alloc.get_payment_type_display(),
            alloc.plot_number.number if alloc.plot_number else 'Reserved',
            alloc.date_allocated.strftime("%d-%b-%Y")
        ])

    return response


# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
@login_required
def view_allocated_plot(request, id):
    estate = get_object_or_404(
        Estate.objects.prefetch_related(
            Prefetch('estate_plots',
                queryset=EstatePlot.objects.prefetch_related(
                    Prefetch('plot_numbers', 
                        queryset=PlotNumber.objects.prefetch_related('plotallocation_set')
                    ),
                    Prefetch('plotsizeunits', 
                        queryset=PlotSizeUnits.objects.select_related('plot_size')
                    )
                )
            )
        ),
        id=id
    )

    context = {
        'estate': estate,
        'estate_plots': estate.estate_plots.all(),
    }
    return render(request, 'admin_side/view_allocated_plots.html', context)

@login_required
def delete_estate_plots(request):
    if request.method == 'POST':
        selected_ids = request.POST.getlist('selected')
        EstatePlot.objects.filter(id__in=selected_ids).delete()
        return redirect('estate_plot_list')

@login_required
def edit_estate_plot(request, id):
    estate_plot = get_object_or_404(EstatePlot, id=id)
    plot_sizes = PlotSize.objects.all()

    if request.method == 'POST':
        selected_plot_sizes = request.POST.getlist('plot_sizes[]')
        selected_plot_numbers = request.POST.getlist('plot_numbers[]')
        total_units = 0
        selected_units = {}

        for size in plot_sizes:
            if str(size.id) in selected_plot_sizes:
                unit_value = request.POST.get(f'plot_units_{size.id}', '0')
                try:
                    selected_units[size.id] = int(unit_value)
                    total_units += int(unit_value)
                except ValueError:
                    selected_units[size.id] = 0

        if total_units != len(selected_plot_numbers):
            messages.error(
                request,
                'Total plot size units must equal the total plot numbers selected. Please adjust your selection.'
            )
            context = {
                'estate_plot': estate_plot,
                'plot_sizes': plot_sizes,
                'plot_numbers': estate_plot.plot_numbers.all(),
                'selected_plot_sizes': selected_plot_sizes,
                'selected_units': selected_units,
                'selected_plot_numbers': selected_plot_numbers,
            }
            return render(request, 'admin_side/edit_estate_plot.html', context)

        # ---- UPDATE DATABASE ----
        # Update the plot numbers
        estate_plot.plot_numbers.set(selected_plot_numbers)

        # Clear existing plot size relationships
        estate_plot.plotsizeunits.all().delete()

        # Add new plot size relationships
        for size_id, unit_count in selected_units.items():
            plot_size = get_object_or_404(PlotSize, id=size_id)
            estate_plot.plotsizeunits.create(plot_size=plot_size, total_units=unit_count)

        estate_plot.save()

        messages.success(request, 'Estate plot updated successfully!')
        # return redirect('view-allocated-plot')  # Ensure this URL is correctly defined

    # Prepopulate selected data
    selected_plot_sizes = [str(unit.plot_size.id) for unit in estate_plot.plotsizeunits.all()]
    selected_units = {unit.plot_size.id: unit.total_units for unit in estate_plot.plotsizeunits.all()}
    selected_plot_numbers = [str(plot.id) for plot in estate_plot.plot_numbers.all()]

    context = {
        'estate_plot': estate_plot,
        'plot_sizes': plot_sizes,
        'plot_numbers': estate_plot.plot_numbers.all(),
        'selected_plot_sizes': selected_plot_sizes,
        'selected_units': selected_units,
        'selected_plot_numbers': selected_plot_numbers,
    }
    return render(request, 'admin_side/edit_estate_plot.html', context)

def download_estate_pdf(request, estate_id):
    # Fetch estate details and allocations
    estate = Estate.objects.get(id=estate_id)
    allocations = PlotAllocation.objects.filter(estate_id=estate_id)

    # Create response object
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="{estate.name}_Allocations.pdf"'

    # Create PDF
    pdf = canvas.Canvas(response, pagesize=A4)
    pdf.setTitle(f"{estate.name}\nAllocations Report")

    # Title Styling
    pdf.setFont("Helvetica-Bold", 18)
    pdf.setFillColor(colors.darkblue)
    title_width = pdf.stringWidth(estate.name, "Helvetica-Bold", 18)
    pdf.drawString((A4[0] - title_width) / 2, 800, estate.name)  # Center title on X-axis

    pdf.setFont("Helvetica-Bold", 14)
    pdf.setFillColor(colors.black)
    subtitle_width = pdf.stringWidth("Plot Allocations Report", "Helvetica-Bold", 14)
    pdf.drawString((A4[0] - subtitle_width) / 2, 780, "Plot Allocations Report")  # Center subtitle

    # Table Header
    data = [["#", "Client", "Phone", "Plot Size", "Payment Type", "Plot Number", "Date"]]

    # Add data rows with numbering
    for i, allocation in enumerate(allocations, start=1):
        data.append([
            str(i),  # Numbering column
            allocation.client.full_name,
            str(allocation.plot_size.size),
            allocation.get_payment_type_display(),
            allocation.plot_number.number if allocation.payment_type == "full" else "Reserved",
            allocation.date_allocated.strftime("%b %d, %Y")
        ])

    # Table Styling with Modern Colors
    table = Table(data, colWidths=[30, 120, 80, 100, 80, 80])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#003366")),  # Dark Blue Header
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),  # White Text in Header
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#f2f2f2"), colors.HexColor("#d9e1f2")]),  # Alternating Light Grey and Blue
    ]))

    # Draw table
    table.wrapOn(pdf, 500, 600)
    table.drawOn(pdf, 50, 650)

    # Save and return response
    pdf.save()
    return response


@csrf_exempt
def add_estate_plot(request):
    if request.method == "POST":
        try:
            estate_id = request.POST.get('estate')
            if not estate_id:
                return JsonResponse({'error': 'Please select an estate'}, status=400)
            
            estate = get_object_or_404(Estate, id=estate_id)
            new_plot_numbers = request.POST.getlist('plot_numbers[]', [])
            new_selected_plot_sizes = request.POST.getlist('plot_sizes[]', [])

            # Check for plot numbers already assigned to other estates
            conflict_plots = EstatePlot.objects.exclude(estate=estate)\
                .filter(plot_numbers__id__in=new_plot_numbers)\
                .values_list('plot_numbers__number', flat=True)
            if conflict_plots.exists():
                return JsonResponse({
                    'error': f'Plot numbers {list(conflict_plots)} already assigned to other estates'
                }, status=400)

            # Get or create the EstatePlot for this estate
            estate_plot, created = EstatePlot.objects.get_or_create(estate=estate)

            # Retrieve any existing PlotSizeUnits for this estate_plot
            existing_units_qs = PlotSizeUnits.objects.filter(estate_plot=estate_plot)
            existing_units = {str(unit.plot_size.id): unit for unit in existing_units_qs}

            # Process the new plot sizes & unit counts submitted
            new_plot_size_units = {}
            total_new_units = 0
            for size_id in new_selected_plot_sizes:
                plot_size = get_object_or_404(PlotSize, id=size_id)
                units_input = request.POST.get(f'plot_units_{size_id}', '0').strip()
                
                try:
                    new_units = int(units_input) if units_input else 0
                except ValueError:
                    return JsonResponse({
                        'error': f'Invalid number of units entered for {plot_size.size}. Please enter a whole number.'
                    }, status=400)
                
                if new_units < 1:
                    return JsonResponse({
                        'error': f'Number of units for {plot_size.size} must be at least 1'
                    }, status=400)
                
                new_plot_size_units[size_id] = new_units
                total_new_units += new_units

            # Validate plot size units against allocations
            for size_id, existing_unit in existing_units.items():
                if existing_unit.allocations.exists():
                    if size_id not in new_plot_size_units:
                        return JsonResponse({
                            'error': f'PLOT SIZE {existing_unit.plot_size.size} has existing allocations and cannot be removed'
                        }, status=400)
                    
                    total_allocated_reserved = existing_unit.full_allocations + existing_unit.part_allocations
                    
                    if new_plot_size_units[size_id] < total_allocated_reserved:
                        return JsonResponse({
                            'error': f'Cannot decrease PLOT SIZE {existing_unit.plot_size.size} below current allocations. '
                                    f'ALLOCATED: {existing_unit.full_allocations}, '
                                    f'RESERVED: {existing_unit.part_allocations}, '
                                    f'MINIMUM UNITS REQUIRED: {total_allocated_reserved}'
                        }, status=400)

            # Validate total units match plot numbers
            if total_new_units != len(new_plot_numbers):
                return JsonResponse({
                    'error': f'Total units ({total_new_units}) must match the number of plot numbers selected ({len(new_plot_numbers)})'
                }, status=400)

            # Check for allocated plot numbers that shouldn't be removed
            allocated_plot_numbers = set()
            for pn in estate_plot.plot_numbers.all():
                if pn.plotallocation_set.exists():
                    allocated_plot_numbers.add(str(pn.id))
            
            for allocated_id in allocated_plot_numbers:
                if allocated_id not in new_plot_numbers:
                    allocated_plot = PlotNumber.objects.get(id=allocated_id)
                    return JsonResponse({
                        'error': f'PLOT NUMBER {allocated_plot.number} IS ALREADY ALLOCATED AND CANNOT BE REMOVED'
                    }, status=400)

            # Update plot numbers
            estate_plot.plot_numbers.clear()
            estate_plot.plot_numbers.add(*PlotNumber.objects.filter(id__in=new_plot_numbers))

            # Update or create plot size units
            for size_id, new_units in new_plot_size_units.items():
                if size_id in existing_units:
                    unit = existing_units[size_id]
                    if new_units != unit.total_units:
                        unit.total_units = new_units
                        unit.available_units = new_units - (unit.full_allocations + unit.part_allocations)
                        unit.save()
                else:
                    plot_size = get_object_or_404(PlotSize, id=size_id)
                    PlotSizeUnits.objects.create(
                        estate_plot=estate_plot,
                        plot_size=plot_size,
                        total_units=new_units,
                        available_units=new_units
                    )
            
            # Remove unused plot size units (if no allocations)
            for size_id, existing_unit in existing_units.items():
                if size_id not in new_plot_size_units:
                    if existing_unit.allocations.exists():
                        return JsonResponse({
                            'error': f'PLOT SIZE {existing_unit.plot_size.size} has existing allocations and cannot be removed'
                        }, status=400)
                    existing_unit.delete()

            return JsonResponse({'message': 'Estate plots updated successfully!'})

        except Exception as e:
            error_message = str(e)
            if 'invalid literal for int() with base 10' in error_message:
                return JsonResponse({
                    'error': 'Invalid number entered. Please check all unit values and ensure they are whole numbers.'
                }, status=400)
            return JsonResponse({
                'error': 'An unexpected error occurred. Please try again or contact support.'
            }, status=400)

    # GET request handling
    allocated_plot_ids = list(EstatePlot.objects.exclude(plot_numbers=None)
                              .values_list('plot_numbers', flat=True).distinct())
    return render(request, 'admin_side/estate-plot.html', {
        'estates': Estate.objects.all(),
        'plot_sizes': PlotSize.objects.all(),
        'plot_numbers': PlotNumber.objects.all(),
        'allocated_plot_ids': allocated_plot_ids,
    })


def get_estate_details(request, estate_id):
    estate = get_object_or_404(Estate, id=estate_id)
    try:
        estate_plot = EstatePlot.objects.get(estate=estate)
        plot_sizes_units = list(estate_plot.plotsizeunits.values(
            'plot_size__id', 'total_units'
        ))
        current_plot_numbers = list(estate_plot.plot_numbers.values_list('id', flat=True))
    except EstatePlot.DoesNotExist:
        plot_sizes_units = []
        current_plot_numbers = []

    # Get plot numbers allocated to OTHER estates
    allocated_plot_ids = list(EstatePlot.objects.exclude(estate=estate)
                              .values_list('plot_numbers', flat=True).distinct())

    return JsonResponse({
        'plot_sizes': plot_sizes_units,
        'plot_numbers': current_plot_numbers,
        'allocated_plot_ids': allocated_plot_ids,
    })


def allocate_units(estate_plot_id, size_id, units_to_allocate):
    plot_size_unit = PlotSizeUnits.objects.get(
        estate_plot_id=estate_plot_id,
        plot_size_id=size_id
    )
    
    if plot_size_unit.available_units >= units_to_allocate:
        plot_size_unit.available_units -= units_to_allocate
        plot_size_unit.save()
    else:
        raise ValueError("Not enough units available for this plot size")

def allocated_plot(request, estate_id):
    estate = Estate.objects.get(id=estate_id)
    # Fetch all plot allocations for this estate
    plot_allocations = PlotAllocation.objects.filter(estate=estate)

    allocated_plots = plot_allocations.filter(payment_type='full')
    unallocated_plots = plot_allocations.filter(payment_type='part')

    # Fetch client details for those who have paid full and partial
    clients_allocated = []
    clients_not_allocated = []

    for allocation in allocated_plots:
        plot_number = allocation.plot_number.number if allocation.plot_number else 'Not Assigned'
        clients_allocated.append({
            'client_name': allocation.client.full_name,
            'payment_type': allocation.payment_type,
            'estate_name': allocation.estate.name,
            'plot_size': allocation.plot_size.size,
            'plot_number': plot_number,
            'status': 'Allocated',
            'action_url': f'/edit-client/{allocation.client.id}/'
        })

    for allocation in unallocated_plots:
        plot_number = allocation.plot_number.number if allocation.plot_number else 'Not Assigned'
        clients_not_allocated.append({
            'client_name': allocation.client.full_name,
            'payment_type': allocation.payment_type,
            'estate_name': allocation.estate.name,
            'plot_size': allocation.plot_size.size,
            'plot_number': plot_number,
            'status': 'Not Allocated',
            'action_url': f'/edit-client/{allocation.client.id}/'
        })

    return render(request, 'admin_side/allocated_plot.html', {
        'estate': estate,
        'allocated_plots': allocated_plots,
        'unallocated_plots': unallocated_plots,
        'clients_allocated': clients_allocated,
        'clients_not_allocated': clients_not_allocated
    })


def fetch_plot_data(request):
    # Allocated plots (with plot numbers assigned)
    allocated_plots = PlotAllocation.objects.filter(is_allocated=True).values('plot_number', 'client_name')
    
    # Reserved or unallocated plots (clients without plot numbers)
    reserved_plots_count = PlotAllocation.objects.filter(plot_number__isnull=True).count()

    data = {
        'allocated_plots': list(allocated_plots),
        'reserved_count': reserved_plots_count
    }
    return JsonResponse(data)


# FLOOR PLAN

def estate_property_list(request):
    return render(request, "admin_side/estate_property_list.html",)

def add_floor_plan(request):
    estate_id = request.GET.get('estate_id')
    estate = get_object_or_404(Estate, id=estate_id)
    
    # Get plot sizes available for this estate
    plot_sizes = PlotSize.objects.filter(
        plotsizeunits__estate_plot__estate=estate
    ).distinct()

    if request.method == "POST":
        # Handle form submission
        plot_size_id = request.POST.get('plot_size')
        floor_plan_image = request.FILES.get('floor_plan_image')
        plan_title = request.POST.get('plan_title')

        try:
            plot_size = PlotSize.objects.get(id=plot_size_id)
            
            # Create a new floor plan (multiple floor plans per estate/plot size are allowed)
            EstateFloorPlan.objects.create(
                estate=estate,
                plot_size=plot_size,
                floor_plan_image=floor_plan_image,
                plan_title=plan_title
            )
            messages.success(request, f"Floor plan for {plot_size} added successfully!")
            redirect_url = reverse('add_floor_plan') + f"?estate_id={estate_id}"
            return redirect(redirect_url)
        
        except Exception as e:
            messages.error(request, f"Error saving floor plan: {str(e)}")
            return redirect(request.META.get('HTTP_REFERER'))

    context = {
        'estate': estate,
        'plot_sizes': plot_sizes,
        'preselected_estate_id': estate_id,
    }
    return render(request, 'admin_side/add_floor_plan.html', context)


def get_plot_sizes_for_floor_plan(request, estate_id):
    plot_sizes = PlotSize.objects.filter(
        plotsizeunits__estate_plot__estate_id=estate_id
    ).distinct().values('id', 'size')
    
    return JsonResponse(list(plot_sizes), safe=False)


def estate_details(request):
    estate_id = request.GET.get("estate_id")
    if not estate_id:
        messages.error(request, "Estate ID is missing.")
        return redirect("view-estate")
    
    estate = get_object_or_404(Estate, id=estate_id)
    floor_plans = EstateFloorPlan.objects.filter(estate=estate)\
        .select_related("estate", "plot_size")\
        .order_by("-date_uploaded")
    
    prototypes = estate.prototypes.all()
    
    context = {
        "estate": estate,
        "floor_plans": floor_plans,
        "prototypes": prototypes,
    }
    return render(request, "admin_side/estate_details.html", context)



# protoTypes
def add_prototypes(request):
    estate_id = request.GET.get('estate_id')
    
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        messages.error(request, "Estate not found")
        return redirect('admin-dashboard')

    # Get plot sizes available for this estate
    plot_sizes = PlotSize.objects.filter(
        plotsizeunits__estate_plot__estate=estate
    ).distinct()

    if request.method == "POST":
        # Handle form submission
        plot_size_id = request.POST.get('plot_size')
        prototype_image = request.FILES.get('prototype_image')
        title = request.POST.get('title')
        description = request.POST.get('description', '')

        try:
            plot_size = PlotSize.objects.get(id=plot_size_id)
            
            # Create an estate prototype (using the correct model and field names)
            EstatePrototype.objects.create(
                estate=estate,
                plot_size=plot_size,
                prototype_image=prototype_image,
                Title=title,
                Description=description,
            )
            messages.success(request, f"{plot_size} prototype added successfully!")
            redirect_url = reverse('add_prototypes') + f"?estate_id={estate_id}"
            return redirect(redirect_url)
        
        except Exception as e:
            messages.error(request, f"Error saving prototype: {str(e)}")
            return redirect(request.META.get('HTTP_REFERER'))

    context = {
        'estate': estate,
        'plot_sizes': plot_sizes,
        'preselected_estate_id': estate_id,
    }
    return render(request, 'admin_side/add_prototype.html', context)


def get_plot_sizes_for_prototypes(request, estate_id):
    plot_sizes = PlotSize.objects.filter(
        plotsizeunits__estate_plot__estate_id=estate_id
    ).distinct().values('id', 'size')
    
    return JsonResponse(list(plot_sizes), safe=False)

# plot allocation
def get_plot_sizes(request, estate_id):
    try:
        estate = Estate.objects.get(id=estate_id)
        plot_sizes = estate.plot_sizes.all()
        data = {
            "plot_sizes": [{"id": plot_size.id, "size": plot_size.size} for plot_size in plot_sizes]
        }
        return JsonResponse(data)
    except Estate.DoesNotExist:
        return JsonResponse({"error": "Estate not found"}, status=404)

@login_required
def deallocate_plot(request, allocation_id):
    try:
        with transaction.atomic():
            allocation = PlotAllocation.objects.select_for_update().get(id=allocation_id)
            unit = allocation.plot_size_unit
            allocation.delete()
            unit.available_units += 1
            unit.save()
            messages.success(request, "Deallocation successful")
    except Exception as e:
        messages.error(request, str(e))
    return redirect('allocations-list')


# Estate Amenities
def update_estate_amenities(request):
    # Get estate_id from query parameters
    estate_id = request.GET.get('estate_id')
    if not estate_id:
        messages.error(request, "Estate ID is missing.")
        return redirect('appropriate_redirect_view')  # Replace with a valid redirect
    
    estate = get_object_or_404(Estate, id=estate_id)
    amenity_record, created = EstateAmenitie.objects.get_or_create(estate=estate)

    if request.method == "POST":
        form = AmenitieForm(request.POST, instance=amenity_record)
        if form.is_valid():
            amenity_obj = form.save(commit=False)
            amenity_obj.estate = estate
            amenity_obj.save()
            messages.success(request, "Amenities updated successfully.")
            # Redirect with the estate_id in the query string
            redirect_url = reverse('update_estate_amenities') + f'?estate_id={estate.id}'
            return redirect(redirect_url)
        else:
            messages.error(request, "Error updating amenities.")
    else:
        form = AmenitieForm(instance=amenity_record)

    available_amenities = [
        {'code': code, 'name': name, 'icon': AMENITY_ICONS.get(code, '')}
        for code, name in AMENITIES_CHOICES
    ]
    # selected_amenity_codes = amenity_record.amenities.split(',') if amenity_record.amenities else []
    selected_amenity_codes = amenity_record.amenities if amenity_record.amenities else []

    return render(request, "admin_side/estate_amenities.html", {
        "estate": estate,
        "form": form,
        "available_amenities": available_amenities,
        "selected_amenity_codes": selected_amenity_codes,
    })

# Estate Layout
def add_estate_layout(request):
    estate_id = request.GET.get('estate_id')
    if not estate_id:
        messages.error(request, "Estate ID is missing.")
        return redirect("admin-dashboard")

    estate = get_object_or_404(Estate, id=estate_id)

    if request.method == "POST":
        layout_image = request.FILES.get('layout_image')
        if layout_image:
            try:
                EstateLayout.objects.create(
                    estate=estate,
                    layout_image=layout_image,
                )
                messages.success(request, "Estate layout uploaded successfully!")
                # Redirect to a details page or any other page you choose
                redirect_url = reverse('add_estate_layout') + f"?estate_id={estate.id}"
                return redirect(redirect_url)
            except Exception as e:
                messages.error(request, f"Error saving estate layout: {str(e)}")
                return redirect(request.META.get('HTTP_REFERER'))
        else:
            messages.error(request, "No layout image provided.")
            return redirect(request.META.get('HTTP_REFERER'))

    context = {
        "estate": estate,
    }
    return render(request, "admin_side/add_estate_layout.html", context)

# Estate Map
def add_estate_map(request):
    estate_id = request.GET.get("estate_id")
    if not estate_id:
        messages.error(request, "Estate ID is missing.")
        return redirect("admin-dashboard")
    
    estate = get_object_or_404(Estate, id=estate_id)
    
    # Get or create the estate map record
    estate_map, created = EstateMap.objects.get_or_create(estate=estate)
    
    if request.method == "POST":
        latitude = request.POST.get("latitude")
        longitude = request.POST.get("longitude")
        google_map_link = request.POST.get("google_map_link")

        if latitude and longitude:
            estate_map.latitude = latitude
            estate_map.longitude = longitude
            if google_map_link:
                estate_map.google_map_link = google_map_link
            estate_map.save()
            messages.success(request, "Estate map updated successfully!")
            redirect_url = reverse("add_estate_map") + f"?estate_id={estate.id}"
            return redirect(redirect_url)
        else:
            messages.error(request, "Please provide both latitude and longitude.")
            return redirect(request.META.get("HTTP_REFERER"))
    
    context = {
        "estate": estate,
        "estate_map": estate_map,
    }
    return render(request, "admin_side/add_estate_map.html", context)

# Estate Work Progress
def add_progress_status(request):
    estate_id = request.GET.get('estate_id')
    if not estate_id:
        messages.error(request, "Estate ID is missing.")
        return redirect("admin-dashboard")

    estate = get_object_or_404(Estate, id=estate_id)

    if request.method == "POST":
        progress_text = request.POST.get('progress_status')
        if progress_text:
            ProgressStatus.objects.create(
                estate=estate,
                progress_status=progress_text,
            )
            messages.success(request, "Progress status updated successfully!")
            # Redirect back to the same page to show the updated list
            redirect_url = reverse('add_progress_status') + f"?estate_id={estate_id}"
            return redirect(redirect_url)
        else:
            messages.error(request, "Please enter a progress status.")
            return redirect(request.META.get('HTTP_REFERER'))

    # Retrieve progress updates for the estate, ordered by timestamp descending
    progress_list = estate.progress_status.all().order_by("-timestamp")

    context = {
        "estate": estate,
        "progress_list": progress_list,
    }
    return render(request, "admin_side/add_progress_status.html", context)


@login_required
def marketer_list(request):
    # Use MarketerUser model to access the 'clients' reverse relationship
    marketers = MarketerUser.objects.all().annotate(
        client_count=Count('clients', filter=Q(clients__is_deleted=False))
    )
    return render(request, 'admin_side/marketer_list.html', {'marketers': marketers})


@login_required
def admin_marketer_profile(request, pk):
    marketer = get_object_or_404(CustomUser, pk=pk, role='marketer')
    # marketer      = request.user
    now           = timezone.now()
    current_year  = now.year
    year_str      = str(current_year)
    current_month = now.strftime("%Y-%m")
    password_response = None


    lifetime_closed_deals = Transaction.objects.filter(
        marketer=marketer
    ).count()

    lifetime_commission = MarketerPerformanceRecord.objects.filter(
        marketer=marketer,
        period_type='monthly'
    ).aggregate(total=Sum('commission_earned'))['total'] or 0


    performance = {
        'closed_deals':      lifetime_closed_deals,
        'total_sales':       0,
        'commission_earned': lifetime_commission,
        'commission_rate':   0,
        'target_achievement': 0,
        'yearly_target_achievement': None,
    }

    # Latest commission rate
    comm = MarketerCommission.objects.filter(marketer=marketer).order_by('-effective_date').first()
    if comm:
        performance['commission_rate'] = comm.rate

    # Monthly target %
    mt = MarketerTarget.objects.filter(
        marketer=marketer,
        period_type='monthly',
        specific_period=current_month
    ).first()
    if mt and mt.target_amount:
        performance['target_achievement'] = min(
            100,
            performance['total_sales'] / mt.target_amount * 100
        )

    # Annual target achievement
    at = (
        MarketerTarget.objects.filter(marketer=marketer, period_type='annual', specific_period=year_str)
        .first()
        or
        MarketerTarget.objects.filter(marketer=None, period_type='annual', specific_period=year_str)
        .first()
    )
    if at and at.target_amount:
        total_year_sales = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__year=current_year
        ).aggregate(total=Sum('total_amount'))['total'] or 0
        performance['yearly_target_achievement'] = min(
            100,
            total_year_sales / at.target_amount * 100
        )

    # — Build leaderboard —
    sales_data = []
    for m in MarketerUser.objects.all():
        year_sales = Transaction.objects.filter(
            marketer=m,
            transaction_date__year=current_year
        ).aggregate(total=Sum('total_amount'))['total'] or 0

        tgt = (
            MarketerTarget.objects.filter(marketer=m, period_type='annual', specific_period=year_str).first()
            or
            MarketerTarget.objects.filter(marketer=None, period_type='annual', specific_period=year_str).first()
        )
        target_amt = tgt.target_amount if tgt else None
        pct = (year_sales / target_amt * 100) if target_amt else None

        sales_data.append({'marketer': m, 'total_sales': year_sales, 'target_amt': target_amt, 'pct': pct})

    sales_data.sort(key=lambda x: x['total_sales'], reverse=True)

    top3 = []
    for idx, e in enumerate(sales_data[:3], start=1):
        pct = e['pct']
        if pct is None:
            category = diff = None
        elif pct < 100:
            category, diff = 'Below Target', round(100 - pct, 1)
        elif pct == 100:
            category, diff = 'On Target', 0
        else:
            category, diff = 'Above Target', round(pct - 100, 1)

        top3.append({
            'rank': idx,
            'marketer': e['marketer'],
            'category': category,
            'diff_pct': diff,
            'has_target': e['target_amt'] is not None,
        })

    user_entry = None
    for idx, e in enumerate(sales_data, start=1):
        if e['marketer'].id == marketer.id:
            pct = e['pct']
            if pct is None:
                category = diff = None
            elif pct < 100:
                category, diff = 'Below Target', round(100 - pct, 1)
            elif pct == 100:
                category, diff = 'On Target', 0
            else:
                category, diff = 'Above Target', round(pct - 100, 1)

            user_entry = {
                'rank': idx,
                'marketer': marketer,
                'category': category,
                'diff_pct': diff,
                'has_target': e['target_amt'] is not None,
            }
            break

    if request.method == 'POST':
        # Profile update
        if request.POST.get("update_profile"):
            ok = update_profile_data(marketer, request)
            if ok:
                messages.success(request, "Your profile has been updated successfully!")
            else:
                messages.error(request, "Failed to update your profile.")

        # Password change
        elif request.POST.get('change_password'):
            password_response = change_password(request)
            cd = password_response.context_data
            if cd.get('success'):
                messages.success(request, cd['success'])
            elif cd.get('error'):
                messages.error(request, cd['error'])

        return redirect('marketer-profile')



    return render(request, 'admin_side/marketer_profile.html', {
        'password_response': password_response,
        'performance': performance,
        'top3':        top3,
        'user_entry':  user_entry,
        'current_year': current_year,
    })


# Admin Chat
@login_required
def admin_chat_view(request, client_id):
    # try:
    #     client = CustomUser.objects.get(id=client_id, role='client')
    # except CustomUser.DoesNotExist:
    #     messages.error(request, "The client you are trying to chat with does not exist.")
    #     return redirect('admin_client_chat_list')
        
    client = get_object_or_404(CustomUser, id=client_id, role='client')
    admin_user = request.user
    
    # Mark all unread messages from the client as read when ANY admin opens the chat.
    # This ensures unified dashboard - all admins see the same read/unread status
    Message.objects.filter(sender=client, recipient__role__in=SUPPORT_ROLES, is_read=False).update(is_read=True, status='read')
    
    # Query all messages between this client and ANY admin (unified dashboard)
    # This allows all admins to see the entire conversation history
    conversation = Message.objects.filter(
        Q(sender=client, recipient__role__in=SUPPORT_ROLES) |
        Q(sender__role__in=SUPPORT_ROLES, recipient=client)
    ).order_by('date_sent')
    
    # POLLING branch: if GET includes 'last_msg'
    if request.method == "GET" and 'last_msg' in request.GET:
        try:
            last_msg_id = int(request.GET.get('last_msg', 0))
        except ValueError:
            last_msg_id = 0
        new_messages = conversation.filter(id__gt=last_msg_id)

        messages_html = ""
        messages_list = []
        for msg in new_messages:
            messages_html += render_to_string('admin_side/chat_message.html', {'msg': msg, 'request': request})
            messages_list.append({'id': msg.id})
        
        # Also return updated statuses for all messages
        updated_statuses = []
        for m in conversation:
            updated_statuses.append({'id': m.id, 'status': m.status})
        
        return JsonResponse({
            'messages': messages_list,
            'messages_html': messages_html,
            'updated_statuses': updated_statuses
        })
    
    # POST: Admin sends a new message
    if request.method == "POST":
        message_content = request.POST.get('message_content', '').strip()
        file_attachment = request.FILES.get('file')
        
        if not message_content and not file_attachment:
            return JsonResponse({'success': False, 'error': 'Please enter a message or attach a file.'})
        
        # Admin sends message - recipient is the specific client
        new_message = Message.objects.create(
            sender=admin_user,
            recipient=client,
            message_type="enquiry",
            content=message_content,
            file=file_attachment,
            status='sent'
        )
        message_html = render_to_string('admin_side/chat_message.html', {'msg': new_message, 'request': request})
        return JsonResponse({'success': True, 'message_html': message_html})
    
    context = {
        'client': client,
        'messages': conversation,
    }
    return render(request, 'admin_side/chat_interface.html', context)

@login_required
def marketer_chat_view(request):
    if getattr(request.user, 'role', None) != 'marketer':
        return redirect('login')

    admin_user = CustomUser.objects.filter(role__in=SUPPORT_ROLES).first()
    if not admin_user:
        return JsonResponse({'success': False, 'error': 'No admin available to receive messages.'}, status=400)

    initial_unread = Message.objects.filter(
        sender__role__in=SUPPORT_ROLES,
        recipient=request.user,
        is_read=False
    ).count()

    admin_messages_qs = Message.objects.filter(
        sender__role__in=SUPPORT_ROLES,
        recipient=request.user,
        is_read=False
    )
    admin_messages_qs.update(is_read=True, status='read')

    conversation = Message.objects.filter(
        Q(sender=request.user, recipient__role__in=SUPPORT_ROLES) |
        Q(sender__role__in=SUPPORT_ROLES, recipient=request.user)
    ).order_by('date_sent')

    if request.method == "GET" and 'last_msg' in request.GET:
        try:
            last_msg_id = int(request.GET.get('last_msg', 0))
        except (ValueError, TypeError):
            last_msg_id = 0

        new_messages = conversation.filter(id__gt=last_msg_id)
        messages_html = ""
        messages_list = []
        for msg in new_messages:
            messages_html += render_to_string('marketer_side/chat_message.html', {'msg': msg, 'request': request})
            messages_list.append({'id': msg.id})

        updated_statuses = [{'id': msg.id, 'status': msg.status} for msg in conversation]

        return JsonResponse({
            'messages': messages_list,
            'messages_html': messages_html,
            'updated_statuses': updated_statuses,
        })

    if request.method == "POST":
        message_content = request.POST.get('message_content', '').strip()
        file_attachment = request.FILES.get('file')
        reply_to_id = request.POST.get('reply_to')
        reply_to = None
        if reply_to_id:
            try:
                reply_to = Message.objects.get(id=reply_to_id)
            except Message.DoesNotExist:
                reply_to = None

        if not message_content and not file_attachment:
            return JsonResponse({'success': False, 'error': 'Please enter a message or attach a file.'}, status=400)

        new_message = Message.objects.create(
            sender=request.user,
            recipient=admin_user,
            message_type="enquiry",
            content=message_content,
            file=file_attachment,
            reply_to=reply_to,
            status='sent'
        )

        message_html = render_to_string('marketer_side/chat_message.html', {
            'msg': new_message,
            'request': request,
        })
        return JsonResponse({'success': True, 'message_html': message_html})

    context = {
        'messages': conversation,
        'unread_chat_count': initial_unread,
        'global_message_count': initial_unread,
    }
    return render(request, 'marketer_side/chat_interface.html', context)


@login_required
@require_POST
def delete_message(request, message_id):
    try:
        msg = Message.objects.get(id=message_id)
    except Message.DoesNotExist:
        return JsonResponse({'success': False, 'error': 'Message not found'}, status=404)

    if msg.sender != request.user and msg.recipient != request.user:
        return JsonResponse({'success': False, 'error': 'You do not have permission to delete this message'}, status=403)

    msg.delete()
    return JsonResponse({'success': True})


@login_required
def chat_unread_count(request):
    user = request.user

    data = {
        'total_unread': 0,
        'global_message_count': 0,
        'admin_unread_clients': [],
        'client_count': 0,
        'admin_unread_marketers': [],
        'marketer_count': 0,
    }

    if getattr(user, 'role', None) in SUPPORT_ROLES:
        total = Message.objects.filter(
            recipient__role__in=SUPPORT_ROLES,
            is_read=False
        ).count()
        data['total_unread'] = total

        from django.db.models import Max, Count, Subquery, OuterRef

        latest_content_sq = Subquery(
            Message.objects.filter(
                sender=OuterRef('pk'),
                recipient__role__in=SUPPORT_ROLES
            ).order_by('-date_sent').values('content')[:1]
        )
        latest_file_sq = Subquery(
            Message.objects.filter(
                sender=OuterRef('pk'),
                recipient__role__in=SUPPORT_ROLES
            ).order_by('-date_sent').values('file')[:1]
        )

        unread_clients_qs = (CustomUser.objects
            .filter(
                role='client',
                sent_messages__recipient__role__in=SUPPORT_ROLES,
                sent_messages__is_read=False
            )
            .annotate(
                last_message=Max('sent_messages__date_sent'),
                unread_count=Count('sent_messages'),
                last_content=latest_content_sq,
                last_file=latest_file_sq,
            )
            .distinct()
            .order_by('-last_message')
        )

        admin_unread_clients = []
        for c in unread_clients_qs[:5]:
            profile_url = None
            try:
                if getattr(c, 'profile_image', None):
                    profile_url = c.profile_image.url
            except Exception:
                profile_url = None

            last_msg = (Message.objects
                        .filter(sender=c, recipient__role__in=SUPPORT_ROLES)
                        .order_by('-date_sent')
                        .first())
            last_iso = last_msg.date_sent.isoformat() if last_msg else None
            last_file_name = None
            if last_msg and getattr(last_msg, 'file', None):
                try:
                    last_file_name = last_msg.file.name
                except Exception:
                    last_file_name = None

            admin_unread_clients.append({
                'id': c.id,
                'full_name': getattr(c, 'full_name', 'Client'),
                'profile_image': profile_url,
                'unread_count': getattr(c, 'unread_count', 0),
                'last_content': getattr(c, 'last_content', '') or '',
                'last_file': last_file_name,
                'last_message_iso': last_iso,
            })

        data['client_count'] = unread_clients_qs.count()
        data['admin_unread_clients'] = admin_unread_clients

        unread_marketers_qs = (CustomUser.objects
            .filter(
                role='marketer',
                sent_messages__recipient__role__in=SUPPORT_ROLES,
                sent_messages__is_read=False
            )
            .annotate(
                last_message=Max('sent_messages__date_sent'),
                unread_count=Count('sent_messages'),
                last_content=Subquery(
                    Message.objects.filter(
                        sender=OuterRef('pk'),
                        recipient__role__in=SUPPORT_ROLES
                    ).order_by('-date_sent').values('content')[:1]
                ),
                last_file=Subquery(
                    Message.objects.filter(
                        sender=OuterRef('pk'),
                        recipient__role__in=SUPPORT_ROLES
                    ).order_by('-date_sent').values('file')[:1]
                ),
            )
            .distinct()
            .order_by('-last_message')
        )

        admin_unread_marketers = []
        for m in unread_marketers_qs[:5]:
            profile_url = None
            try:
                if getattr(m, 'profile_image', None):
                    profile_url = m.profile_image.url
            except Exception:
                profile_url = None

            last_msg = (Message.objects
                        .filter(sender=m, recipient__role__in=SUPPORT_ROLES)
                        .order_by('-date_sent')
                        .first())
            last_iso = last_msg.date_sent.isoformat() if last_msg else None
            last_file_name = None
            if last_msg and getattr(last_msg, 'file', None):
                try:
                    last_file_name = last_msg.file.name
                except Exception:
                    last_file_name = None

            admin_unread_marketers.append({
                'id': m.id,
                'full_name': getattr(m, 'full_name', 'Marketer'),
                'profile_image': profile_url,
                'unread_count': getattr(m, 'unread_count', 0),
                'last_content': getattr(m, 'last_content', '') or '',
                'last_file': last_file_name,
                'last_message_iso': last_iso,
            })

        data['marketer_count'] = unread_marketers_qs.count()
        data['admin_unread_marketers'] = admin_unread_marketers
    else:
        data['global_message_count'] = Message.objects.filter(
            sender__role__in=SUPPORT_ROLES,
            recipient=user,
            is_read=False
        ).count()

    return JsonResponse(data)

@login_required
def message_detail(request, message_id):
    message = get_object_or_404(Message, id=message_id)
    return render(request, 'message_detail.html', {'message': message})


@login_required
def company_profile_view(request):
    """Admin-only page showing the current company's profile and key real estate stats."""
    user = request.user
    if getattr(user, 'role', None) != 'admin':
        return redirect('home')

    company = getattr(user, 'company_profile', None)

    # Basic aggregates for dashboard-style overview
    total_clients = CustomUser.objects.filter(role='client').count()
    total_marketers = CustomUser.objects.filter(role='marketer').count()

    # Estates and allocations
    total_estates = Estate.objects.count() if 'Estate' in globals() else 0
    total_full_allocations = PlotAllocation.objects.filter(payment_type='full').count() if 'PlotAllocation' in globals() else 0
    total_part_allocations = PlotAllocation.objects.filter(payment_type='part').count() if 'PlotAllocation' in globals() else 0

    # Registered users
    registered_users = CustomUser.objects.filter(is_active=True).order_by('-date_joined')[:20]

    # Active vs Inactive app users (active = last_login within 30 days)
    thirty_days_ago = timezone.now() - timedelta(days=30)
    active_users_count = CustomUser.objects.filter(last_login__gte=thirty_days_ago, is_active=True).count()
    inactive_users_count = CustomUser.objects.filter(Q(last_login__lt=thirty_days_ago) | Q(last_login__isnull=True), is_active=True).count()

    # Admin and Support users
    admin_users = CustomUser.objects.filter(role='admin').order_by('-date_joined')
    support_users = CustomUser.objects.filter(role='support').order_by('-date_joined')

    # AdminSupport tables if available
    try:
        from adminSupport.models import StaffRoster, StaffMember
        staff_roster = StaffRoster.objects.select_related('user').all()[:50]
        staff_members = StaffMember.objects.all()[:50]
        staff_roster_count = StaffRoster.objects.count()
        staff_members_count = StaffMember.objects.count()
    except Exception:
        staff_roster = []
        staff_members = []
        staff_roster_count = 0
        staff_members_count = 0

    # App metrics (downloads)
    app_metrics = None
    total_downloads = 0
    if company:
        app_metrics = getattr(company, 'app_metrics', None)
        if not app_metrics:
            try:
                app_metrics = AppMetrics.objects.create(company=company)
            except Exception:
                app_metrics = None
        if app_metrics:
            total_downloads = app_metrics.total_downloads

    context = {
        'company': company,
        'total_clients': total_clients,
        'total_marketers': total_marketers,
        'total_estates': total_estates,
        'total_full_allocations': total_full_allocations,
        'total_part_allocations': total_part_allocations,
        'registered_users': registered_users,
        'active_users_count': active_users_count,
        'inactive_users_count': inactive_users_count,
        'admin_users': admin_users,
        'support_users': support_users,
        'staff_roster': staff_roster,
        'staff_members': staff_members,
        'staff_roster_count': staff_roster_count,
        'staff_members_count': staff_members_count,
        'app_metrics': app_metrics,
        'total_downloads': total_downloads,
    }
    return render(request, 'admin_side/company_profile.html', context)


@login_required
def company_profile_update(request):
    """Handle modal-based updates to company details. Returns JSON on AJAX."""
    user = request.user
    if getattr(user, 'role', None) != 'admin':
        return JsonResponse({'ok': False, 'error': 'Forbidden'}, status=403)

    company = getattr(user, 'company_profile', None)
    if not company:
        return JsonResponse({'ok': False, 'error': 'No linked company'}, status=400)

    if request.method != 'POST':
        return JsonResponse({'ok': False, 'error': 'Invalid method'}, status=405)

    form = CompanyForm(request.POST, request.FILES, instance=company)
    if form.is_valid():
        form.save()
        # minimal payload for re-rendering snippet on client side if desired
        return JsonResponse({'ok': True, 'message': 'Company details updated successfully.'})
    else:
        return JsonResponse({'ok': False, 'errors': form.errors}, status=400)


@login_required
@require_POST
def admin_toggle_mute(request, user_id: int):
    """Mute or unmute an admin or support account. Muted => is_active=False (cannot log in)."""
    if getattr(request.user, 'role', None) != 'admin':
        return JsonResponse({'ok': False, 'error': 'Forbidden'}, status=403)

    if request.user.id == user_id:
        return JsonResponse({'ok': False, 'error': "You can't mute your own account."}, status=400)

    try:
        target = CustomUser.objects.get(id=user_id)
    except CustomUser.DoesNotExist:
        return JsonResponse({'ok': False, 'error': 'User not found'}, status=404)

    if target.role not in ('admin', 'support'):
        return JsonResponse({'ok': False, 'error': 'Action allowed only on admin/support users'}, status=400)

    desired = request.POST.get('desired')  # 'mute' or 'unmute'
    if desired not in ('mute', 'unmute'):
        # Fallback to toggle behavior
        desired = 'mute' if target.is_active else 'unmute'

    # Prevent locking out all admins (must leave at least one active admin)
    if target.role == 'admin' and desired == 'mute' and target.is_active:
        remaining_active = CustomUser.objects.filter(role='admin', is_active=True).exclude(id=target.id).count()
        if remaining_active == 0:
            return JsonResponse({'ok': False, 'error': 'Cannot mute the last active admin.'}, status=400)

    target.is_active = (desired == 'unmute')
    if desired == 'unmute':
        target.deletion_reason = ''
    target.save(update_fields=['is_active', 'deletion_reason'])

    return JsonResponse({'ok': True, 'status': 'active' if target.is_active else 'muted'})


@login_required
@require_POST
def admin_delete_admin(request, user_id: int):
    """Soft-delete an admin or support user: mark is_deleted, disable login, set reason/timestamp."""
    if getattr(request.user, 'role', None) != 'admin':
        return JsonResponse({'ok': False, 'error': 'Forbidden'}, status=403)

    if request.user.id == user_id:
        return JsonResponse({'ok': False, 'error': "You can't delete your own account."}, status=400)

    try:
        target = CustomUser.objects.get(id=user_id)
    except CustomUser.DoesNotExist:
        return JsonResponse({'ok': False, 'error': 'User not found'}, status=404)

    if target.role not in ('admin', 'support'):
        return JsonResponse({'ok': False, 'error': 'Action allowed only on admin/support users'}, status=400)

    # Ensure at least one other active admin remains
    if target.role == 'admin':
        remaining_active = CustomUser.objects.filter(role='admin', is_active=True).exclude(id=target.id).count()
        if remaining_active == 0:
            return JsonResponse({'ok': False, 'error': 'Cannot delete the last active admin.'}, status=400)

    reason = request.POST.get('reason', '').strip()

    target.is_deleted = True
    target.is_active = False
    target.deleted_at = timezone.now()
    if reason:
        target.deletion_reason = reason
    target.save(update_fields=['is_deleted', 'is_active', 'deleted_at', 'deletion_reason'])

    return JsonResponse({'ok': True, 'message': 'Admin deleted (soft).', 'status': 'deleted'})



@login_required
def admin_client_chat_list(request):
    # Get all clients who have sent at least one message (to ANY admin)
    clients = CustomUser.objects.filter(
        role='client',
        sent_messages__isnull=False
    ).distinct().annotate(
        last_message=Max('sent_messages__date_sent')
    ).order_by('-last_message')
    
    for client in clients:
        # Count unread messages from this client to ANY admin (unified dashboard)
        client.unread_count = Message.objects.filter(
            sender=client,
            recipient__role__in=SUPPORT_ROLES,
            is_read=False
        ).count()
    
    # Marketers section: fetch marketers with any messages
    marketers = CustomUser.objects.filter(
        role='marketer',
        sent_messages__isnull=False
    ).distinct().annotate(
        last_message=Max('sent_messages__date_sent')
    ).order_by('-last_message')

    for m in marketers:
        m.unread_count = Message.objects.filter(
            sender=m,
            recipient__role__in=SUPPORT_ROLES,
            is_read=False
        ).count()

    # Total unread counts for sidebar notifications
    total_unread_count = Message.objects.filter(sender__role='client', recipient__role__in=SUPPORT_ROLES, is_read=False).count()
    marketers_unread_count = Message.objects.filter(sender__role='marketer', recipient__role__in=SUPPORT_ROLES, is_read=False).count()
    
    context = {
        'clients': clients,
        'marketers': marketers,
        'total_unread_count': total_unread_count,
        'marketers_unread_count': marketers_unread_count,
    }
    return render(request, 'admin_side/chat_list.html', context)


@login_required
def admin_marketer_chat_view(request, marketer_id):
    marketer = get_object_or_404(CustomUser, id=marketer_id, role='marketer')
    admin_user = request.user

    # Mark all unread messages from this marketer to ANY admin as read
    Message.objects.filter(sender=marketer, recipient__role__in=SUPPORT_ROLES, is_read=False).update(is_read=True, status='read')

    # Full conversation between this marketer and ANY admin
    conversation = Message.objects.filter(
        Q(sender=marketer, recipient__role__in=SUPPORT_ROLES) |
        Q(sender__role__in=SUPPORT_ROLES, recipient=marketer)
    ).order_by('date_sent')

    # Polling branch
    if request.method == "GET" and 'last_msg' in request.GET:
        try:
            last_msg_id = int(request.GET.get('last_msg', 0))
        except ValueError:
            last_msg_id = 0
        new_messages = conversation.filter(id__gt=last_msg_id)

        messages_html = ""
        messages_list = []
        for msg in new_messages:
            messages_html += render_to_string('admin_side/chat_message.html', {'msg': msg, 'request': request})
            messages_list.append({'id': msg.id})

        updated_statuses = [{'id': m.id, 'status': m.status} for m in conversation]

        return JsonResponse({
            'messages': messages_list,
            'messages_html': messages_html,
            'updated_statuses': updated_statuses
        })

    # Sending branch
    if request.method == "POST":
        message_content = request.POST.get('message_content', '').strip()
        file_attachment = request.FILES.get('file')
        if not message_content and not file_attachment:
            return JsonResponse({'success': False, 'error': 'Please enter a message or attach a file.'})

        new_message = Message.objects.create(
            sender=admin_user,
            recipient=marketer,
            message_type="enquiry",
            content=message_content,
            file=file_attachment,
            status='sent'
        )
        message_html = render_to_string('admin_side/chat_message.html', {'msg': new_message, 'request': request})
        return JsonResponse({'success': True, 'message_html': message_html})

    context = {
        'client': marketer,   # Reuse template expecting 'client'
        'messages': conversation,
        'is_marketer': True,
    }
    return render(request, 'admin_side/chat_interface.html', context)


@login_required
def search_clients_api(request):
    """API endpoint to search for clients to start chat with"""
    query = request.GET.get('q', '').strip()
    
    if len(query) < 2:
        return JsonResponse({'clients': []})
    
    # Search clients by name or email
    clients = CustomUser.objects.filter(
        role='client',
        full_name__icontains=query
    ) | CustomUser.objects.filter(
        role='client',
        email__icontains=query
    )
    
    clients = clients.distinct()[:10]  # Limit to 10 results
    
    clients_data = []
    for client in clients:
        clients_data.append({
            'id': client.id,
            'full_name': client.full_name,
            'email': client.email if client.email else '',
        })
    
    return JsonResponse({'clients': clients_data})


@login_required
def search_marketers_api(request):
    """API endpoint to search for marketers to start chat with"""
    query = request.GET.get('q', '').strip()

    if len(query) < 2:
        return JsonResponse({'marketers': []})

    marketers = CustomUser.objects.filter(
        role='marketer',
        full_name__icontains=query
    ) | CustomUser.objects.filter(
        role='marketer',
        email__icontains=query
    )

    marketers = marketers.distinct()[:10]

    marketers_data = []
    for m in marketers:
        marketers_data.append({
            'id': m.id,
            'full_name': m.full_name,
            'email': m.email if m.email else '',
        })

    return JsonResponse({'marketers': marketers_data})

    
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# CLIENT SIDE
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

@login_required
def client(request):
    # Get all clients with their assigned marketers using select_related for optimization
    clients = ClientUser.objects.filter(role='client').select_related('assigned_marketer').order_by('-date_registered')
    return render(request, 'admin_side/client.html', {'clients' : clients})


@login_required
@require_http_methods(["POST"])
def client_soft_delete(request, pk):
    """Soft delete a client"""
    import json
    try:
        client = CustomUser.objects.get(pk=pk, role='client')
        
        # Get deletion reasons from request
        data = json.loads(request.body)
        reasons = data.get('reasons', [])
        
        # Mark as deleted
        client.is_deleted = True
        client.deleted_at = timezone.now()
        client.deletion_reason = ', '.join(reasons)
        client.save()
        
        return JsonResponse({
            'success': True,
            'message': f'Client {client.full_name} has been marked as deleted.'
        })
    except CustomUser.DoesNotExist:
        return JsonResponse({
            'success': False,
            'message': 'Client not found.'
        }, status=404)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'message': str(e)
        }, status=500)


@login_required
@require_http_methods(["POST"])
def client_restore(request, pk):
    """Restore a soft-deleted client"""
    try:
        client = CustomUser.objects.get(pk=pk, role='client')
        
        # Restore the client
        client.is_deleted = False
        client.deleted_at = None
        client.deletion_reason = None
        client.save()
        
        return JsonResponse({
            'success': True,
            'message': f'Client {client.full_name} has been restored.'
        })
    except CustomUser.DoesNotExist:
        return JsonResponse({
            'success': False,
            'message': 'Client not found.'
        }, status=404)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'message': str(e)
        }, status=500)


@login_required
@require_http_methods(["POST"])
def marketer_soft_delete(request, pk):
    """Soft delete a marketer"""
    import json
    try:
        marketer = CustomUser.objects.get(pk=pk, role='marketer')
        
        # Get deletion reasons from request
        data = json.loads(request.body)
        reasons = data.get('reasons', [])
        
        # Mark as deleted
        marketer.is_deleted = True
        marketer.deleted_at = timezone.now()
        marketer.deletion_reason = ', '.join(reasons)
        marketer.save()
        
        return JsonResponse({
            'success': True,
            'message': f'Marketer {marketer.full_name} has been marked as deleted.'
        })
    except CustomUser.DoesNotExist:
        return JsonResponse({
            'success': False,
            'message': 'Marketer not found.'
        }, status=404)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'message': str(e)
        }, status=500)


@login_required
@require_http_methods(["POST"])
def marketer_restore(request, pk):
    """Restore a soft-deleted marketer"""
    try:
        marketer = CustomUser.objects.get(pk=pk, role='marketer')
        
        # Restore the marketer
        marketer.is_deleted = False
        marketer.deleted_at = None
        marketer.deletion_reason = None
        marketer.save()
        
        return JsonResponse({
            'success': True,
            'message': f'Marketer {marketer.full_name} has been restored.'
        })
    except CustomUser.DoesNotExist:
        return JsonResponse({
            'success': False,
            'message': 'Marketer not found.'
        }, status=404)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'message': str(e)
        }, status=500)


def calculate_portfolio_metrics(transactions):
    appreciation_total = Decimal(0)
    growth_rates = []
    highest_growth_rate = Decimal(0)
    highest_growth_property = ""
    
    for transaction in transactions:
        try:
            property_price = PropertyPrice.objects.get(
                estate=transaction.allocation.estate,
                plot_unit__plot_size=transaction.allocation.plot_size
            )
            current_value = property_price.current
        except PropertyPrice.DoesNotExist:
            current_value = transaction.total_amount
        
        appreciation = current_value - transaction.total_amount
        appreciation_total += appreciation
        
        if transaction.total_amount > 0:
            growth_rate = (appreciation / transaction.total_amount) * 100
        else:
            growth_rate = Decimal(0)
        
        growth_rates.append(growth_rate)
        
        if growth_rate > highest_growth_rate:
            highest_growth_rate = growth_rate
            highest_growth_property = transaction.allocation.estate.name
            
        transaction.current_value = current_value
        transaction.appreciation = appreciation
        transaction.growth_rate = growth_rate
        transaction.abs_appreciation = abs(appreciation)
        transaction.abs_growth_rate = abs(growth_rate)
    
    return {
        'transactions': transactions,
        'properties_count': transactions.count(),
        'total_value': sum(t.total_amount for t in transactions),
        'current_value': sum(t.current_value for t in transactions),
        'appreciation_total': appreciation_total,
        'average_growth': sum(growth_rates) / len(growth_rates) if growth_rates else 0,
        'highest_growth_rate': highest_growth_rate,
        'highest_growth_property': highest_growth_property,
    }


@login_required
def client_profile(request, pk):
    client = get_object_or_404(ClientUser, id=pk)
    
    # Get all transactions with related data
    transactions = Transaction.objects.filter(client=client).select_related(
        'allocation__estate',
        'allocation__plot_size'
    )
    
    # Calculate appreciation values
    appreciation_total = Decimal(0)
    growth_rates = []
    highest_growth_rate = Decimal(0)
    highest_growth_property = ""
    
    for transaction in transactions:
        # Get current price for this property
        try:
            property_price = PropertyPrice.objects.get(
                estate=transaction.allocation.estate,
                plot_unit__plot_size=transaction.allocation.plot_size
            )
            current_value = property_price.current
        except PropertyPrice.DoesNotExist:
            current_value = transaction.total_amount 
        
        # Calculate appreciation
        appreciation = current_value - transaction.total_amount
        appreciation_total += appreciation
        
        # Calculate growth rate
        if transaction.total_amount > 0:
            growth_rate = (appreciation / transaction.total_amount) * 100
        else:
            growth_rate = Decimal(0)
            
        growth_rates.append(growth_rate)
        
        # Track highest growth property
        if growth_rate > highest_growth_rate:
            highest_growth_rate = growth_rate
            highest_growth_property = transaction.allocation.estate.name
            
        # Add dynamic properties to transaction
        transaction.current_value = current_value
        transaction.appreciation = appreciation
        transaction.growth_rate = growth_rate
        transaction.abs_appreciation = abs(appreciation)
        transaction.abs_growth_rate = abs(growth_rate)
    
    # Calculate averages
    properties_count = transactions.count()
    average_growth = sum(growth_rates) / len(growth_rates) if growth_rates else 0
    
    context = {
        'client': client,
        'transactions': transactions,
        'properties_count': properties_count,
        'total_value': sum(t.total_amount for t in transactions),
        'current_value': sum(t.current_value for t in transactions),
        'appreciation_total': appreciation_total,
        'average_growth': average_growth,
        'highest_growth_rate': highest_growth_rate,
        'highest_growth_property': highest_growth_property,
    }
    
    return render(request, 'admin_side/client_profile.html', context)


@login_required
def user_profile(request):
    admin = request.user
    context = {'admin': admin}

    if request.method == 'POST':
        # Handle profile data update
        if 'update_profile' in request.POST:
            if update_profile_data(admin, request):
                messages.success(request, 'Your profile has been updated successfully!')

        # Handle password change
        elif 'change_password' in request.POST:
            password_response = change_password(request)
            if hasattr(password_response, 'success') and password_response.success:
                messages.success(request, 'Your password has been changed successfully!')
            else:
                messages.error(request, 'There was an error changing your password.')
            context.update({'password_response': password_response})

    return render(request, 'admin_side/admin_profile.html', context)


from django.db.models import Avg, Count, F, ExpressionWrapper, DecimalField
from django.db.models.functions import TruncMonth
from django.shortcuts import get_object_or_404
from django.views.generic import ListView, DetailView

class EstateListView(ListView):
    model = Estate
    template_name = "client_side/promo_estates_list.html"
    context_object_name = "estates"
    paginate_by = 12

    def get_queryset(self):
        qs = Estate.objects.all().prefetch_related(
            "property_prices",
            "promotional_offers",
            "estate_plots__plotsizeunits"
        )
        qs = qs.order_by("-date_added")
        q = self.request.GET.get("q")
        if q:
            qs = qs.filter(name__icontains=q)
        return qs

    def get_plots_json(self, estate_id):

        try:
            estate = Estate.objects.prefetch_related(
                Prefetch('estate_plots__plotsizeunits__plot_size'),
                Prefetch('promotional_offers'),
                Prefetch('property_prices', queryset=PropertyPrice.objects.select_related('plot_unit__plot_size'))
            ).get(pk=estate_id)
        except Estate.DoesNotExist:
            raise Http404("Estate not found")

        # Active promo (choose highest discount if multiple active)
        today = timezone.localdate()
        active_promos = estate.promotional_offers.filter(start__lte=today, end__gte=today)
        best_promo = active_promos.order_by('-discount').first()
        discount_pct = int(best_promo.discount) if best_promo else None

        sizes_out = []
        seen_sizes = set()

        for estate_plot in estate.estate_plots.all():
            for psu in estate_plot.plotsizeunits.all():
                try:
                    size_label = psu.plot_size.size
                except Exception:
                    try:
                        size_label = str(psu.plot_size)
                    except Exception:
                        size_label = None

                if size_label in seen_sizes:
                    continue
                seen_sizes.add(size_label)

                price_obj = estate.property_prices.filter(plot_unit=psu).first()
                if not price_obj:
                    price_obj = estate.property_prices.filter(
                        plot_unit__plot_size__size=str(size_label)
                    ).first()

                raw_amount = None
                if price_obj and getattr(price_obj, 'current', None) is not None:
                    try:
                        raw_amount = Decimal(price_obj.current)
                    except (InvalidOperation, TypeError):
                        raw_amount = None

                if raw_amount is None or raw_amount == Decimal('0'):
                    amount_value = None
                    amount_label = "NO AMOUNT SET"
                else:
                    amount_value = float(raw_amount.quantize(Decimal('0.01')))
                    if raw_amount == raw_amount.quantize(Decimal('1')):
                        amount_label = f"₦{int(raw_amount):,}"
                    else:
                        amount_label = f"₦{raw_amount:,}"

                discounted_value = None
                if amount_value is not None and discount_pct:
                    try:
                        discounted = (Decimal(amount_value) * (Decimal(100 - discount_pct) / Decimal(100))).quantize(Decimal('0.01'))
                        discounted_value = float(discounted)
                    except Exception:
                        discounted_value = None

                sizes_out.append({
                    "size": size_label,
                    "amount": amount_value,
                    "amount_label": amount_label,
                    "discounted": discounted_value,
                    "discount_pct": discount_pct,
                })

        if not sizes_out and estate.property_prices.exists():
            for pp in estate.property_prices.all():
                try:
                    size_label = pp.plot_unit.plot_size.size
                except Exception:
                    try:
                        size_label = str(pp.plot_unit.plot_size)
                    except Exception:
                        size_label = None

                if size_label in seen_sizes:
                    continue
                seen_sizes.add(size_label)

                raw_amount = None
                if getattr(pp, 'current', None) is not None:
                    try:
                        raw_amount = Decimal(pp.current)
                    except (InvalidOperation, TypeError):
                        raw_amount = None

                if raw_amount is None or raw_amount == Decimal('0'):
                    amount_value = None
                    amount_label = "NO AMOUNT SET"
                else:
                    amount_value = float(raw_amount.quantize(Decimal('0.01')))
                    if raw_amount == raw_amount.quantize(Decimal('1')):
                        amount_label = f"₦{int(raw_amount):,}"
                    else:
                        amount_label = f"₦{raw_amount:,}"

                discounted_value = None
                if amount_value is not None and discount_pct:
                    try:
                        discounted = (Decimal(amount_value) * (Decimal(100 - discount_pct) / Decimal(100))).quantize(Decimal('0.01'))
                        discounted_value = float(discounted)
                    except Exception:
                        discounted_value = None

                sizes_out.append({
                    "size": size_label,
                    "amount": amount_value,
                    "amount_label": amount_label,
                    "discounted": discounted_value,
                    "discount_pct": discount_pct,
                })

        response = {
            "estate_id": estate.id,
            "estate_name": estate.name,
            "promo": {
                "active": bool(best_promo),
                "name": best_promo.name if best_promo else None,
                "discount_pct": discount_pct
            },
            "sizes": sizes_out
        }
        return JsonResponse(response)

    
    def get(self, request, *args, **kwargs):
        """
        If the request has `estate_id` (or `format=json`) and looks like an XHR,
        return JSON for that estate's sizes/prices. Otherwise behave like ListView.
        """
        estate_id = request.GET.get('estate_id')
        fmt = request.GET.get('format')
        is_xhr = request.headers.get('x-requested-with') == 'XMLHttpRequest'

        if estate_id and (is_xhr or fmt == 'json'):
            return self.get_plots_json(estate_id)

        return super().get(request, *args, **kwargs)


class PromotionListView(ListView):
    model = PromotionalOffer
    template_name = "client_side/promotions_list.html"
    context_object_name = "promotions"
    paginate_by = 8

    def get_queryset(self):
        qs = PromotionalOffer.objects.all().prefetch_related("estates").order_by("-created_at")
        today = timezone.localdate()
        flt = self.request.GET.get('filter', '').lower()
        if flt == 'active':
            qs = qs.filter(start__lte=today, end__gte=today)
        elif flt == 'past':
            qs = qs.filter(end__lt=today)
        return qs
    
    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        today = timezone.localdate()
        
        ctx['active_promotions'] = PromotionalOffer.objects.filter(
            start__lte=today, end__gte=today
        ).order_by('-created_at')[:3]

        ctx['past_promotions'] = PromotionalOffer.objects.filter(end__lt=today).order_by('-end')[:12]

        ctx['current_filter'] = self.request.GET.get('filter', 'all').lower()
        
        return ctx


class PromotionDetailView(DetailView):
    model = PromotionalOffer
    template_name = "client_side/promo_detail.html"
    context_object_name = "promo"

    def get_queryset(self):
        return PromotionalOffer.objects.prefetch_related("estates")


def price_update_json(request, pk):
    try:
        ph = PriceHistory.objects.select_related(
            'price__estate', 'price__plot_unit__plot_size'
        ).get(pk=pk)
    except PriceHistory.DoesNotExist:
        return JsonResponse({"error": "Price update not found"}, status=404)

    percent_change = None
    try:
        prev = ph.previous
        curr = ph.current
        if prev not in (None, 0) and curr is not None:
            percent_change = float(((curr - prev) / prev) * 100)
    except Exception:
        percent_change = None

    data = {
        "id": ph.id,
        "estate_id": ph.price.estate.id if ph.price and ph.price.estate else None,
        "estate_name": ph.price.estate.name if ph.price and ph.price.estate else None,
        "size": getattr(ph.price.plot_unit.plot_size, 'size', None),
        "previous": float(ph.previous) if ph.previous is not None else None,
        "current": float(ph.current) if ph.current is not None else None,
        "percent_change": round(percent_change, 2) if percent_change is not None else None,
        "effective": ph.effective.isoformat() if ph.effective else None,
        "notes": ph.notes or "",
        "recorded_at": ph.recorded_at.isoformat() if ph.recorded_at else None,
    }
    return JsonResponse(data)


@login_required
def client_dashboard(request):
    allocations = PlotAllocation.objects.filter(client=request.user)
    total_properties = allocations.count()
    fully_paid_allocations = allocations.filter(payment_type="full").count()
    not_fully_paid_allocations = allocations.exclude(payment_type="full").count()

    client_estates = Estate.objects.filter(plotallocation__client=request.user).distinct()

    today_local = timezone.localdate()

    retention_days = getattr(settings, "PRICE_HISTORY_RETENTION_DAYS", 90)
    cutoff = today_local - timedelta(days=retention_days)

    all_updates = (
        PriceHistory.objects
        .select_related('price__estate', 'price__plot_unit__plot_size', 'price')
        .filter(effective__gte=cutoff)
        .order_by('-effective', '-recorded_at')
    )

    seen = set()
    latest_value = []
    for upd in all_updates:
        estate_id = getattr(upd.price, 'estate_id', None) if getattr(upd, 'price', None) else getattr(upd.price, 'estate_id', None)
        plot_unit_id = getattr(upd.price, 'plot_unit_id', None) if getattr(upd, 'price', None) else getattr(upd.price, 'plot_unit_id', None)
        key = f"{estate_id}_{plot_unit_id}"
        if key not in seen:
            seen.add(key)
            latest_value.append(upd)

    for upd in latest_value:
        try:
            live_current = None
            if getattr(upd, 'price', None) and getattr(upd.price, 'current', None) is not None:
                try:
                    live_current = Decimal(upd.price.current)
                except Exception:
                    live_current = None

            if live_current is not None:
                upd.current = live_current
            else:
                if getattr(upd, 'current', None) is not None:
                    try:
                        upd.current = Decimal(upd.current)
                    except Exception:
                        pass

            if getattr(upd, 'previous', None) is not None:
                try:
                    upd.previous = Decimal(upd.previous)
                except Exception:
                    pass

            if upd.previous not in (None, 0) and upd.current is not None:
                try:
                    upd.percent_change = float(((Decimal(upd.current) - Decimal(upd.previous)) / Decimal(upd.previous)) * 100)
                except Exception:
                    upd.percent_change = 0.0
            else:
                upd.percent_change = 0.0
        except Exception:
            upd.percent_change = 0.0

    latest_value = latest_value[:12]

    estate_ids = {e.id for e in client_estates}
    estate_ids.update({getattr(u.price.estate, 'id') for u in latest_value if getattr(u.price, 'estate', None)})
    estate_ids = {eid for eid in estate_ids if eid is not None}

    best_promo_by_estate = {}
    if estate_ids:
        promo_qs = (
            PromotionalOffer.objects
            .filter(estates__in=estate_ids, start__lte=today_local, end__gte=today_local)
            .order_by('-discount')
            .prefetch_related('estates')
        )
        for promo in promo_qs:
            for est in promo.estates.all():
                if est.id in estate_ids and est.id not in best_promo_by_estate:
                    best_promo_by_estate[est.id] = promo

    for upd in latest_value:
        try:
            est_id = getattr(upd.price.estate, 'id', None)
            promo = best_promo_by_estate.get(est_id)
            if promo and upd.current is not None:
                current_dec = Decimal(upd.current)
                discount_pct = Decimal(promo.discount)
                upd.promo_price = (current_dec * (Decimal(100) - discount_pct) / Decimal(100)).quantize(Decimal('0.01'))
                upd.promo = {'id': promo.id, 'discount': int(promo.discount), 'name': promo.name}
            else:
                upd.promo_price = None
                upd.promo = None
        except Exception:
            upd.promo_price = None
            upd.promo = None

    base_qs = (
        PriceHistory.objects
        .select_related('price__estate', 'price__plot_unit__plot_size', 'price')
        .filter(price__estate__in=client_estates, effective__gte=cutoff)
        .order_by('-effective', '-recorded_at')
    )

    promo_estate_ids = (
        PromotionalOffer.objects
        .filter(estates__in=client_estates, start__lte=today_local, end__gte=today_local)
        .values_list('estates', flat=True)
        .distinct()
    )
    promo_estate_ids = list(promo_estate_ids)

    promo_qs = PriceHistory.objects.none()
    if promo_estate_ids:
        promo_qs = (
            PriceHistory.objects
            .select_related('price__estate', 'price__plot_unit__plot_size', 'price')
            .filter(price__estate__in=promo_estate_ids)
            .order_by('-effective', '-recorded_at')
        )

    promo_map_for_client = {}
    if client_estates.exists():
        promos_for_client = (
            PromotionalOffer.objects
            .filter(estates__in=client_estates, start__lte=today_local, end__gte=today_local)
            .order_by('-discount')
            .prefetch_related('estates')
        )
        for promo in promos_for_client:
            for est in promo.estates.all():
                if est.id not in promo_map_for_client:
                    promo_map_for_client[est.id] = promo

    seen = set()
    recent_value_updates = []
    recent_value_updates_ph_objects = []

    def append_ph(ph, forced_by_promo=False):
        estate_id = getattr(ph.price.estate, 'id', None)
        plot_unit_id = getattr(ph.price.plot_unit, 'id', None)
        key = f"{estate_id}_{plot_unit_id}"
        if key in seen:
            return
        seen.add(key)

        # prefer live price for display here as well
        try:
            live_current = None
            if getattr(ph, 'price', None) and getattr(ph.price, 'current', None) is not None:
                try:
                    live_current = Decimal(ph.price.current)
                except Exception:
                    live_current = None

            display_current = live_current if live_current is not None else (ph.current if ph.current is not None else None)
            display_prev = ph.previous if ph.previous is not None else None

            percent_change = None
            if display_prev not in (None, 0) and display_current is not None:
                try:
                    percent_change = float(((Decimal(display_current) - Decimal(display_prev)) / Decimal(display_prev)) * 100)
                except Exception:
                    percent_change = None
        except Exception:
            percent_change = None

        # status based on local today
        if ph.effective and ph.effective > today_local:
            status = "Yet Active"
        else:
            status = "Active"

        promo_obj = promo_map_for_client.get(estate_id) or best_promo_by_estate.get(estate_id)
        promo = None
        promo_price = None
        if promo_obj and ph.current is not None:
            try:
                current_dec = Decimal(ph.current)
                discount_pct = Decimal(promo_obj.discount)
                promo_price = (current_dec * (Decimal(100) - discount_pct) / Decimal(100)).quantize(Decimal('0.01'))
                promo = {
                    'id': promo_obj.id,
                    'name': promo_obj.name,
                    'discount': int(promo_obj.discount),
                    'start': promo_obj.start,
                    'end': promo_obj.end,
                }
            except Exception:
                promo_price = None
                promo = None

        recent_value_updates.append({
            'ph': ph,
            'percent_change': percent_change,
            'status': status,
            'promo': promo,
            'promo_price': promo_price,
            'promo_forced': bool(forced_by_promo),
        })
        recent_value_updates_ph_objects.append(ph)

    for ph in base_qs:
        append_ph(ph, forced_by_promo=False)
    for ph in promo_qs:
        append_ph(ph, forced_by_promo=True)

    active_promotions = PromotionalOffer.objects.filter(
        start__lte=today_local, end__gte=today_local
    ).order_by('-discount')[:3]

    recent_transactions = PaymentRecord.objects.filter(
        transaction__allocation__client=request.user
    ).order_by('-payment_date')[:5]

    # value trend
    value_trend_data = []
    for i in range(6, -1, -1):
        month = timezone.now() - timedelta(days=30 * i)
        month_start = month.replace(day=1)
        avg_price = PriceHistory.objects.filter(
            price__estate__in=client_estates,
            effective__year=month_start.year,
            effective__month=month_start.month
        ).aggregate(avg_price=Avg('current'))['avg_price'] or 0
        value_trend_data.append({'date': month_start, 'value': float(avg_price)})

    context = {
        'total_properties': total_properties,
        'fully_paid_allocations': fully_paid_allocations,
        'not_fully_paid_allocations': not_fully_paid_allocations,
        'latest_value_updates': recent_value_updates_ph_objects,
        'recent_value_updates': recent_value_updates,
        'active_promotions': active_promotions,
        'recent_transactions': recent_transactions,
        'value_trend_data': value_trend_data,
        'client_estates': client_estates,
        'latest_value': latest_value,
        'today_local': today_local,
    }

    return render(request, 'client_side/client_side.html', context)


@login_required
def my_client_profile(request):
    client = ClientUser.objects.select_related('assigned_marketer').get(id=request.user.id)

    transactions = Transaction.objects.filter(client=client).select_related(
        'allocation__estate',
        'allocation__plot_size'
    )

    metrics = calculate_portfolio_metrics(transactions)
    context = {'client': client, **metrics}

    if request.method == 'POST':
        action = request.POST.get('action')

        if not action:
            if request.POST.get('update_profile'):
                action = 'update_profile'
            elif request.POST.get('change_password'):
                action = 'change_password'

        if action == "update_profile":
            ok = update_profile_data(client, request)
            if not ok:
                messages.error(request, "Failed to update your profile.")
            return redirect(request.path + '#profile-edit')

        elif action == "change_password":
            password_response = change_password(request)

            if isinstance(password_response, dict):
                cd = password_response.get('context_data', {})
            else:
                cd = getattr(password_response, 'context_data', {})

            if cd.get('success'):
                messages.success(request, cd['success'])
            elif cd.get('error'):
                messages.error(request, cd['error'])
                
            return redirect(request.path + '#profile-change-password')

    return render(request, 'client_side/client_profile.html', context)


@login_required
def client_new_property_request(request):
    
    estates = Estate.objects.all()
    context = {
        "estates": estates,
    }
    return render(request, 'client_side/new_property_request.html', context)


@login_required
def chat_view(request):
    admin_user = CustomUser.objects.filter(role__in=SUPPORT_ROLES).first()

    initial_unread = Message.objects.filter(
        sender__role__in=SUPPORT_ROLES,
        recipient=request.user,
        is_read=False
    ).count()

    Message.objects.filter(
        sender__role__in=SUPPORT_ROLES,
        recipient=request.user,
        is_read=False
    ).update(is_read=True, status='read')

    conversation = Message.objects.filter(
        Q(sender=request.user, recipient__role__in=SUPPORT_ROLES) |
        Q(sender__role__in=SUPPORT_ROLES, recipient=request.user)
    ).order_by('date_sent')

    if request.method == "GET" and 'last_msg' in request.GET:
        try:
            last_msg_id = int(request.GET.get('last_msg', 0))
        except ValueError:
            last_msg_id = 0
        new_messages = conversation.filter(id__gt=last_msg_id)

        messages_html = ""
        messages_list = []
        for msg in new_messages:
            messages_html += render_to_string('client_side/chat_message.html', {'msg': msg, 'request': request})
            messages_list.append({'id': msg.id})

        updated_statuses = []
        for m in conversation:
            updated_statuses.append({'id': m.id, 'status': m.status})

        return JsonResponse({
            'messages': messages_list,
            'messages_html': messages_html,
            'updated_statuses': updated_statuses
        })

    if request.method == "POST":
        message_content = request.POST.get('message_content')
        file_attachment = request.FILES.get('file')
        reply_to_id = request.POST.get('reply_to')
        reply_to = None
        if reply_to_id:
            try:
                reply_to = Message.objects.get(id=reply_to_id)
            except Message.DoesNotExist:
                reply_to = None

        if not message_content and not file_attachment:
            return JsonResponse({'success': False, 'error': 'Please enter a message or attach a file.'})

        new_message = Message.objects.create(
            sender=request.user,
            recipient=admin_user,
            message_type="enquiry",
            content=message_content,
            file=file_attachment,
            reply_to=reply_to,
            status='sent'
        )

        message_html = render_to_string('client_side/chat_message.html', {
            'msg': new_message,
            'request': request,
        })
        return JsonResponse({'success': True, 'message_html': message_html})

    else:
        context = {
            'messages': conversation,
            'unread_chat_count': initial_unread,
            'global_message_count': initial_unread,
        }
        return render(request, 'client_side/chat_interface.html', context)


@login_required
def view_all_requests(request):
    # Retrieve all property requests
    property_requests = PropertyRequest.objects.all()
    return render(request, 'client_side/requests_table.html', {'requests': property_requests})


@login_required
def property_list(request):
    # Fetch only the allocations that belong to the logged-in client.
    allocations = PlotAllocation.objects.filter(client=request.user).order_by('-date_allocated')
    context = {
        "allocations": allocations,
    }
    return render(request, 'client_side/property_list.html', context)

@login_required
def view_client_estate(request, estate_id, plot_size_id):
    estate = get_object_or_404(Estate, id=estate_id)

    plot_size = get_object_or_404(PlotSize, id=plot_size_id)
    
    # Get floor plans for this specific plot size in the estate
    floor_plans = EstateFloorPlan.objects.filter(
        estate=estate, 
        plot_size=plot_size
    )
    
    context = {
        'estate': estate,
        'plot_size': plot_size,
        'floor_plans': floor_plans,
    }
    return render(request, 'client_side/client_estate_detail.html', context)


# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# MARKETER SIDE
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

@login_required
def marketer_dashboard(request):
    user = request.user

    # 1) Totals
    total_transactions = Transaction.objects.filter(marketer=user).count()
    total_estates_sold = Transaction.objects.filter(marketer=user, allocation__payment_type='full').count()
    number_clients = ClientUser.objects.filter(assigned_marketer=user).count()

    # Helper to build a list of (label, transaction_count, estate_count, new_client_count)
    def build_series(start, step, buckets, date_field='transaction_date'):
        labels = []
        tx_counts = []
        est_counts = []
        cli_counts = []

        current = start
        for _ in range(buckets):
            # label for this bucket:
            labels.append(current.strftime(step['fmt']))

            # window start/end
            window_start = current
            window_end = current + step['delta']

            # transactions in window
            tx_qs = Transaction.objects.filter(
                marketer=user,
                **{f"{date_field}__gte": window_start},
                **{f"{date_field}__lt": window_end}
            )
            tx_counts.append(tx_qs.count())

            # full-payment estates sold
            est_qs = tx_qs.filter(allocation__payment_type='full')
            est_counts.append(est_qs.count())

            # new clients assigned in this window
            cli_qs = ClientUser.objects.filter(
                assigned_marketer=user,
                date_registered__gte=window_start,
                date_registered__lt=window_end
            )
            cli_counts.append(cli_qs.count())

            current = window_end

        return labels, tx_counts, est_counts, cli_counts

    today = date.today()

    # Weekly: last 7 days
    weekly_start = today - relativedelta(days=6)
    weekly_step = { 'delta': relativedelta(days=1), 'fmt': '%d %b' }
    weekly_labels, weekly_tx, weekly_est, weekly_cli = build_series(weekly_start, weekly_step, 7)

    # Monthly: last 6 months
    monthly_start = (today - relativedelta(months=5)).replace(day=1)
    monthly_step = { 'delta': relativedelta(months=1), 'fmt': '%b %Y' }
    monthly_labels, monthly_tx, monthly_est, monthly_cli = build_series(monthly_start, monthly_step, 6)

    # Yearly: last 5 years
    yearly_start = today.replace(month=1, day=1) - relativedelta(years=4)
    yearly_step = { 'delta': relativedelta(years=1), 'fmt': '%Y' }
    yearly_labels, yearly_tx, yearly_est, yearly_cli = build_series(yearly_start, yearly_step, 5)

    # All-Time: monthly buckets from first transaction month until now
    first_tx = Transaction.objects.filter(marketer=user).order_by('transaction_date').first()
    if first_tx:
        first_month = first_tx.transaction_date.replace(day=1)
    else:
        first_month = today.replace(day=1)
    months = (today.year - first_month.year) * 12 + (today.month - first_month.month) + 1
    all_step = { 'delta': relativedelta(months=1), 'fmt': '%b %Y' }
    all_labels, all_tx, all_est, all_cli = build_series(first_month, all_step, months)

    return render(request, 'marketer_side/marketer_side.html', {
        'total_transactions': total_transactions,
        'total_estates_sold': total_estates_sold,
        'number_clients': number_clients,
        'weekly': {
            'labels': weekly_labels, 'tx': weekly_tx,
            'est': weekly_est, 'cli': weekly_cli
        },
        'monthly': {
            'labels': monthly_labels, 'tx': monthly_tx,
            'est': monthly_est, 'cli': monthly_cli
        },
        'yearly': {
            'labels': yearly_labels, 'tx': yearly_tx,
            'est': yearly_est, 'cli': yearly_cli
        },
        'alltime': {
            'labels': all_labels, 'tx': all_tx,
            'est': all_est, 'cli': all_cli
        }
    })

@login_required
def marketer_profile(request):
    marketer      = request.user
    now           = timezone.now()
    current_year  = now.year
    year_str      = str(current_year)
    current_month = now.strftime("%Y-%m")
    password_response = None


    lifetime_closed_deals = Transaction.objects.filter(
        marketer=marketer
    ).count()

    lifetime_commission = MarketerPerformanceRecord.objects.filter(
        marketer=marketer,
        period_type='monthly'
    ).aggregate(total=Sum('commission_earned'))['total'] or 0


    performance = {
        'closed_deals':      lifetime_closed_deals,
        'total_sales':       0,
        'commission_earned': lifetime_commission,
        'commission_rate':   0,
        'target_achievement': 0,
        'yearly_target_achievement': None,
    }

    # Latest commission rate
    comm = MarketerCommission.objects.filter(marketer=marketer).order_by('-effective_date').first()
    if comm:
        performance['commission_rate'] = comm.rate

    # Monthly target %
    mt = MarketerTarget.objects.filter(
        marketer=marketer,
        period_type='monthly',
        specific_period=current_month
    ).first()
    if mt and mt.target_amount:
        performance['target_achievement'] = min(
            100,
            performance['total_sales'] / mt.target_amount * 100
        )

    # Annual target achievement
    at = (
        MarketerTarget.objects.filter(marketer=marketer, period_type='annual', specific_period=year_str)
        .first()
        or
        MarketerTarget.objects.filter(marketer=None, period_type='annual', specific_period=year_str)
        .first()
    )
    if at and at.target_amount:
        total_year_sales = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__year=current_year
        ).aggregate(total=Sum('total_amount'))['total'] or 0
        performance['yearly_target_achievement'] = min(
            100,
            total_year_sales / at.target_amount * 100
        )

    # — Build leaderboard —
    sales_data = []
    for m in MarketerUser.objects.all():
        year_sales = Transaction.objects.filter(
            marketer=m,
            transaction_date__year=current_year
        ).aggregate(total=Sum('total_amount'))['total'] or 0

        tgt = (
            MarketerTarget.objects.filter(marketer=m, period_type='annual', specific_period=year_str).first()
            or
            MarketerTarget.objects.filter(marketer=None, period_type='annual', specific_period=year_str).first()
        )
        target_amt = tgt.target_amount if tgt else None
        pct = (year_sales / target_amt * 100) if target_amt else None

        sales_data.append({'marketer': m, 'total_sales': year_sales, 'target_amt': target_amt, 'pct': pct})

    sales_data.sort(key=lambda x: x['total_sales'], reverse=True)

    top3 = []
    for idx, e in enumerate(sales_data[:3], start=1):
        pct = e['pct']
        if pct is None:
            category = diff = None
        elif pct < 100:
            category, diff = 'Below Target', round(100 - pct, 1)
        elif pct == 100:
            category, diff = 'On Target', 0
        else:
            category, diff = 'Above Target', round(pct - 100, 1)

        top3.append({
            'rank': idx,
            'marketer': e['marketer'],
            'category': category,
            'diff_pct': diff,
            'has_target': e['target_amt'] is not None,
        })

    user_entry = None
    for idx, e in enumerate(sales_data, start=1):
        if e['marketer'].id == marketer.id:
            pct = e['pct']
            if pct is None:
                category = diff = None
            elif pct < 100:
                category, diff = 'Below Target', round(100 - pct, 1)
            elif pct == 100:
                category, diff = 'On Target', 0
            else:
                category, diff = 'Above Target', round(pct - 100, 1)

            user_entry = {
                'rank': idx,
                'marketer': marketer,
                'category': category,
                'diff_pct': diff,
                'has_target': e['target_amt'] is not None,
            }
            break

    if request.method == 'POST':
        # Profile update
        if request.POST.get("update_profile"):
            ok = update_profile_data(marketer, request)
            if ok:
                messages.success(request, "Your profile has been updated successfully!")
            else:
                messages.error(request, "Failed to update your profile.")

        # Password change
        elif request.POST.get('change_password'):
            password_response = change_password(request)
            cd = password_response.context_data
            if cd.get('success'):
                messages.success(request, cd['success'])
            elif cd.get('error'):
                messages.error(request, cd['error'])

        return redirect('marketer-profile')



    return render(request, 'marketer_side/marketer_profile.html', {
        'password_response': password_response,
        'performance': performance,
        'top3':        top3,
        'user_entry':  user_entry,
        'current_year': current_year,
    })

@login_required
def client_records(request):
    marketer = request.user
    
    clients = (
        ClientUser.objects
        .filter(assigned_marketer=marketer)
        .prefetch_related(
            'transactions__allocation__estate',
            'transactions__allocation__plot_size',
            'transactions__allocation__plot_number',
        )
    )

    return render(request, 'marketer_side/client_records.html', {
        'clients': clients,
    })


@login_required
def marketer_notification(request):
    return render(request, 'marketer_side/notification.html')

@login_required
def client_notification(request):
    return render(request, 'client_side/notification.html')


# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# OTHER CONFIGURATIONS
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

@login_required
def dashboard(request):
    user = request.user
    if user.role == 'admin':
        return render(request, 'admin_side/index.html')
    elif user.role == 'client':
        return render(request, 'client_side/client_side.html')
    elif user.role == 'marketer':
        return render(request, 'marketer_side/marketer_side.html')
    elif user.role == 'support':
        return render(request, 'adminSide/birthday_message.html')
    
    return redirect('login')


@login_required
def user_profile(request):
    user = request.user
    if user.role == 'admin':
        return render(request, 'admin_side/admin_profile.html')
    elif user.role == 'client':
        return render(request, 'client_side/client_profile.html')
    elif user.role == 'marketer':
        return render(request, 'marketer_side/marketer_profile.html')
    
    return redirect('dashboard')


class CustomLoginView(LoginView):
    form_class = CustomAuthenticationForm
    template_name = 'login.html'

    def form_valid(self, form):
        response = super().form_valid(form)
        # Capture last login IP and (optionally) location
        try:
            user = self.request.user
            ip = extract_client_ip(self.request)
            # If we only have a private/localhost IP, prefer the client-provided public IP (if present)
            try:
                from .services.geoip import is_private_ip
                client_ip_from_form = self.request.POST.get('client_public_ip')
                if (not ip or is_private_ip(ip)) and client_ip_from_form:
                    ip = client_ip_from_form.strip()
            except Exception:
                pass
            if hasattr(user, 'last_login_ip'):
                user.last_login_ip = ip
                # Attempt a lightweight GeoIP lookup; ignore failures
                location = lookup_ip_location(ip)
                if hasattr(user, 'last_login_location') and location:
                    user.last_login_location = location
                    user.save(update_fields=['last_login_ip', 'last_login_location'])
                else:
                    user.save(update_fields=['last_login_ip'])
        except Exception:
            pass
        messages.success(self.request, "Login successful!")
        return response

    def form_invalid(self, form):
        messages.error(self.request, "Invalid email or password. Please try again.")
        return self.render_to_response(self.get_context_data(form=form))

    def get_success_url(self):
        redirect_to = self.get_redirect_url()
        if redirect_to:
            return redirect_to

        user = self.request.user
        if user.role == 'admin':
            return reverse_lazy('admin-dashboard')
        elif user.role == 'client':
            return reverse_lazy('client-dashboard')
        elif user.role == 'marketer':
            return reverse_lazy('marketer-dashboard')
        elif user.role == 'support':
            return reverse_lazy('adminsupport:support_dashboard')
        else:
            return super().get_success_url()


@csrf_protect
def company_registration(request):
    """Handle company registration and create primary admin account"""
    if request.method == 'POST':
        try:
            # Extract form data
            company_name = request.POST.get('company_name')
            registration_number = request.POST.get('registration_number')
            registration_date = request.POST.get('registration_date')
            location = request.POST.get('location')
            ceo_name = request.POST.get('ceo_name')
            ceo_dob = request.POST.get('ceo_dob')
            email = request.POST.get('email')
            phone = request.POST.get('phone')
            password = request.POST.get('password')
            confirm_password = request.POST.get('confirm_password')

            # Validation
            if password != confirm_password:
                messages.error(request, "Passwords do not match!")
                return redirect('login')

            if len(password) < 8:
                messages.error(request, "Password must be at least 8 characters long!")
                return redirect('login')

            # Check if company already exists
            if Company.objects.filter(company_name=company_name).exists():
                messages.error(request, "A company with this name already exists!")
                return redirect('login')

            if Company.objects.filter(registration_number=registration_number).exists():
                messages.error(request, "This registration number is already in use!")
                return redirect('login')

            if Company.objects.filter(email=email).exists():
                messages.error(request, "This email is already registered!")
                return redirect('login')

            # Check if user email already exists
            if CustomUser.objects.filter(email=email).exists():
                messages.error(request, "A user with this email already exists!")
                return redirect('login')

            # Create company with transaction
            with transaction.atomic():
                # Create the company
                company = Company.objects.create(
                    company_name=company_name,
                    registration_number=registration_number,
                    registration_date=registration_date,
                    location=location,
                    ceo_name=ceo_name,
                    ceo_dob=ceo_dob,
                    email=email,
                    phone=phone,
                    is_active=True
                )

                # Create the admin user
                admin_user = CustomUser.objects.create_user(
                    email=email,
                    full_name=ceo_name,
                    phone=phone,
                    password=password,
                    role='admin',
                    company_profile=company,
                    address=location,
                    date_of_birth=ceo_dob,
                    is_staff=True,
                    is_superuser=True
                )

                # Set additional fields
                admin_user.company = company_name
                admin_user.save()

                messages.success(
                    request,
                    f"🎉 Registration successful! Welcome {company_name}! You can now login with your credentials."
                )
                
                # Optionally send welcome email here
                try:
                    send_mail(
                        subject=f'Welcome to Real Estate Management System - {company_name}',
                        message=f'Dear {ceo_name},\n\n'
                                f'Your company "{company_name}" has been successfully registered.\n'
                                f'You can now login with your email: {email}\n\n'
                                f'Thank you for choosing our platform!\n\n'
                                f'Best regards,\nReal Estate Management Team',
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[email],
                        fail_silently=True,
                    )
                except Exception as e:
                    # Email failure shouldn't stop registration
                    pass

                return redirect('login')

        except IntegrityError as e:
            messages.error(request, f"Database error: A record with this information already exists!")
            return redirect('login')
        except Exception as e:
            messages.error(request, f"An error occurred during registration: {str(e)}")
            return redirect('login')

    # GET request - show login page
    return redirect('login')


@login_required
def change_password(request):
    context = {}

    if request.method == 'POST':
        current = request.POST.get('currentPassword')
        new_pw  = request.POST.get('newPassword')
        confirm = request.POST.get('renewPassword')

        if not request.user.check_password(current):
            context['error'] = "Current password is incorrect."
        elif new_pw != confirm:
            context['error'] = "New password and confirmation password do not match."
        elif len(new_pw) < 8:
            context['error'] = "Password must be at least 8 characters long."
        else:
            # All good: update password
            user = request.user
            user.set_password(new_pw)
            user.save()
            # Keep the session
            update_session_auth_hash(request, user)
            context['success'] = "Your password has been successfully updated!"

    return SimpleNamespace(context_data=context)


def update_profile_data(user, request):
    if request.method == 'POST':
        # Get the posted form data
        about = request.POST.get('about')
        company = request.POST.get('company')
        job = request.POST.get('job')
        country = request.POST.get('country')
        profile_image = request.FILES.get('profile_image')

        # Validate the input fields if necessary
        # if not about or not company or not job or not country:
        #     messages.error(request, "Please fill out all fields.")
        #     return False

        # Update the user fields
        user.about = about
        user.company = company
        user.job = job
        user.country = country

        # If a new profile image was uploaded, update it
        if profile_image:
            user.profile_image = profile_image

        # Save the updated user information
        try:
            user.save()
            messages.success(request, 'Your profile has been updated successfully!')
            return True
        except ValidationError as e:
            messages.error(request, f"Error updating profile: {e}")
            return False
    return False


@login_required
def send_message(request):
    return render(request, 'send_message.html')

from django.shortcuts import render, get_object_or_404


@login_required
def client_message(request):
    """
    Handle client message submission and display client-specific messages.
    """
    if request.method == "POST":
        message_type = request.POST.get('message_type')
        message_content = request.POST.get('message_content')

        if not message_type or not message_content:
            messages.error(request, "All fields are required.")
            return redirect('client-message')

        # Save the client's message
        Message.objects.create(
            sender=request.user,
            recipient=None,  # Indicates a message for the admin
            type=message_type,
            content=message_content,
            date_sent=timezone.now(),
        )

        messages.success(request, "Your message has been sent to the admin dashboard.")
        return redirect('client-message')

    user_messages = Message.objects.filter(sender=request.user).order_by('-date_sent')
    return render(request, 'client_side/contact.html', {'messages': user_messages})


# NOTIFICATIONS
def announcement_form(request):
    form = NotificationForm() 
    return render(request, 'notifications/emails/admin_notification_form.html', {'form': form})


@require_http_methods(["POST"])
def send_announcement(request):
    try:
        # Authentication check
        if not request.user.is_authenticated or not request.user.is_staff:
            return JsonResponse({
                'status': 'error',
                'message': 'Authentication required'
            }, status=401)

        # Data validation
        notification_type = request.POST.get('notification_type')
        title = request.POST.get('title')
        message = request.POST.get('message')

        if not all([notification_type, title, message]):
            raise ValidationError("All fields are required")

        # Create notification
        notification = Notification.objects.create(
            notification_type=notification_type,
            title=title,
            message=message
        )

        # Determine recipients
        roles = []
        if notification_type == Notification.ANNOUNCEMENT:
            roles = ['client', 'marketer']
        elif notification_type == Notification.CLIENT_ANNOUNCEMENT:
            roles = ['client']
        elif notification_type == Notification.MARKETER_ANNOUNCEMENT:
            roles = ['marketer']
        else:
            raise ValidationError("Invalid notification type")

        recipients = CustomUser.objects.filter(role__in=roles)
        if not recipients.exists():
            raise ValidationError("No recipients found for this notification type")

        # Bulk create with batch processing
        batch_size = 100
        user_notifications = [
            UserNotification(user=user, notification=notification)
            for user in recipients.iterator()
        ]
        UserNotification.objects.bulk_create(user_notifications, batch_size=batch_size)

        return JsonResponse({
            'status': 'success',
            'message': f'Notification sent to {len(recipients)} recipients'
        })

    except ValidationError as e:
        return JsonResponse({
            'status': 'error',
            'message': 'Validation error',
            'errors': e.messages
        }, status=400)
        
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e)
        }, status=500)


def send_notification_email(client, title, message):
    context = {
        'user': client,
        'message': message,
        'site_url': settings.SITE_URL
    }
    
    html_content = render_to_string(
        'notifications/emails/announcement.html',
        context
    )
    
    send_mail(
        subject=f"REMS Notification: {title}",
        message=strip_tags(html_content),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[client.email],
        html_message=html_content
    )



# MANAGEMENT DASHBOARD
# Sales Volume Tab

def sales_volume_metrics(request):
    """
    GET params:
      - period: 'monthly', 'quarterly', or 'yearly'
      - specific_period: 'YYYY-MM', 'YYYY-Qn', or 'YYYY'
    Returns JSON with current & previous metrics, including Outstanding Payments
    calculated as (sum of all part‑plan totals) – (sum of all part‑plan payments).
    """

    today  = timezone.now().date()
    period = request.GET.get('period', 'monthly')
    sp     = request.GET.get('specific_period')

    # 1) Determine start/end of the selected period
    if period == 'monthly' and sp:
        year, month = map(int, sp.split('-'))
        start = dt.date(year, month, 1)
        end   = start + relativedelta(months=1)

    elif period == 'quarterly' and sp:
        y_str, q_str = sp.split('-Q')
        y, q = int(y_str), int(q_str)
        start = dt.date(y, 3*(q-1) + 1, 1)
        end   = start + relativedelta(months=3)

    elif period == 'yearly' and sp:
        y = int(sp)
        start = dt.date(y, 1, 1)
        end   = dt.date(y+1, 1, 1)

    else:
        # default to current month
        start = today.replace(day=1)
        end   = start + relativedelta(months=1)

    # helper: sum total_amount in [s,e)
    def sum_amt(s, e):
        return (Transaction.objects
                .filter(transaction_date__gte=s, transaction_date__lt=e)
                .aggregate(total=Sum('total_amount'))['total'] or 0)

    # 2) Monthly Closed Deals: last month in [start,end)
    last_month_start = (end - relativedelta(months=1)).replace(day=1)
    next_month_start = last_month_start + relativedelta(months=1)

    monthly_closed = Transaction.objects.filter(
        transaction_date__gte=last_month_start,
        transaction_date__lt= next_month_start
    ).count()

    prev_month_start = last_month_start - relativedelta(months=1)
    prev_month_end   = last_month_start

    prev_monthly_closed = Transaction.objects.filter(
        transaction_date__gte=prev_month_start,
        transaction_date__lt= prev_month_end
    ).count()

    # 3) Quarterly Sales Volume
    quarterly_sales = sum_amt(start, end)

    prev_quarter_start = start - (end - start)
    prev_quarter_end   = start

    prev_quarterly_sales = sum_amt(prev_quarter_start, prev_quarter_end)

    # 4) Annual Transactions & Average Deal
    annual_transactions = Transaction.objects.filter(
        transaction_date__gte=start,
        transaction_date__lt=end
    ).count()

    average_deal = (quarterly_sales / annual_transactions) if annual_transactions else 0

    prev_annual_transactions = Transaction.objects.filter(
        transaction_date__gte=prev_quarter_start,
        transaction_date__lt=prev_quarter_end
    ).count()

    prev_average_deal = (
        (prev_quarterly_sales / prev_annual_transactions)
        if prev_annual_transactions else 0
    )

    # 5) Active Installments (all‑time)
    active_installments = (
        Transaction.objects
        .filter(allocation__payment_type='part')
        .annotate(
            paid=Coalesce(
                Sum('payment_records__amount_paid'),
                Value(0),
                output_field=DecimalField()
            )
        )
        .filter(paid__lt=F('total_amount'))
        .count()
    )

    # 6) Outstanding Payments (all part‑plans)
    #    Sum all part‑plan totals, then subtract all part‑plan payments
    part_totals = (
        Transaction.objects
        .filter(allocation__payment_type='part')
        .aggregate(grand_total=Sum('total_amount'))['grand_total'] or 0
    )
    paid_sum = (
        PaymentRecord.objects
        .filter(transaction__allocation__payment_type='part')
        .aggregate(paid_total=Sum('amount_paid'))['paid_total'] or 0
    )
    total_outstanding = part_totals - paid_sum

    # 7) Overdue Payments (all‑time): count part‑plans whose due_date < today and still unpaid
    overdue_count = 0
    for tx in Transaction.objects.filter(allocation__payment_type='part'):
        if tx.due_date and tx.due_date < today and tx.total_amount > tx.total_paid:
            overdue_count += 1

    # 8) Total Paid YTD
    y_start = today.replace(month=1, day=1)
    part_paid_ytd = (
        PaymentRecord.objects
        .filter(payment_date__gte=y_start)
        .aggregate(total=Sum('amount_paid'))['total'] or 0
    )
    full_paid_ytd = (
        Transaction.objects
        .filter(allocation__payment_type='full', transaction_date__gte=y_start)
        .aggregate(total=Sum('total_amount'))['total'] or 0
    )
    total_paid = part_paid_ytd + full_paid_ytd

    # Return JSON
    return JsonResponse({
        'monthly_closed':           monthly_closed,
        'prev_monthly_closed':      prev_monthly_closed,
        'quarterly_sales':          float(quarterly_sales),
        'prev_quarterly_sales':     float(prev_quarterly_sales),
        'annual_transactions':      annual_transactions,
        'prev_annual_transactions': prev_annual_transactions,
        'average_deal':             float(average_deal),
        'prev_average_deal':        float(prev_average_deal),
        'active_installments':      active_installments,
        'total_outstanding':        float(total_outstanding),
        'overdue_count':            overdue_count,
        'total_paid':               float(total_paid),
    })


# <!-- Land Plot Transactions -->
@login_required
@require_http_methods(["POST"])
def add_transaction(request):
    cid      = request.POST.get("client", "")
    aid      = request.POST.get("allocation", "")
    txn_date = request.POST.get("transaction_date", "")
    total_s  = request.POST.get("total_amount", "0")
    notes    = request.POST.get("special_notes", "")
    plan     = request.POST.get("installment_plan", "")
    pdur     = request.POST.get("payment_duration", "")
    cdur     = request.POST.get("custom_duration", "")
    fp_s     = request.POST.get("first_percent", "")
    sp_s     = request.POST.get("second_percent", "")
    tp_s     = request.POST.get("third_percent", "")
    pm = request.POST.get("payment_method", "")

    allocation = get_object_or_404(PlotAllocation, pk=aid)
    existing   = Transaction.objects.filter(client_id=cid, allocation=allocation).first()
    txn        = existing or Transaction(client_id=cid, allocation=allocation)

    # --- 2) Core fields ---
    txn.transaction_date = txn_date
    txn.total_amount     = Decimal(total_s)
    txn.special_notes    = notes
    txn.installment_plan = plan or None

    # --- 3) Part-payment logic ---
    if allocation.payment_type == "part" and txn.total_amount > 0:
        # 3a) Handle durations
        if pdur and pdur != "custom":
            txn.payment_duration = int(pdur)
            txn.custom_duration  = None
        elif pdur == "custom" and cdur:
            txn.payment_duration = None
            txn.custom_duration  = int(cdur)
        else:
            txn.payment_duration = txn.custom_duration = None

        # 3b) Handle percents & installments
        if plan and plan != "custom":
            pcts = list(map(int, plan.split("-")))
            txn.first_percent, txn.second_percent, txn.third_percent = pcts
        else:
            txn.first_percent  = int(fp_s) if fp_s.isdigit() else None
            txn.second_percent = int(sp_s) if sp_s.isdigit() else None
            txn.third_percent  = int(tp_s) if tp_s.isdigit() else None
            pcts = [txn.first_percent, txn.second_percent, txn.third_percent]

        if pcts and sum(pcts) == 100:
            t = txn.total_amount
            txn.first_installment  = (t * pcts[0]) / 100
            txn.second_installment = (t * pcts[1]) / 100
            txn.third_installment  = (t * pcts[2]) / 100
        else:
            txn.first_installment = txn.second_installment = txn.third_installment = None

    else:
        # full payment → clear part-payment fields
        txn.payment_duration     = txn.custom_duration = None
        txn.first_percent        = txn.second_percent = txn.third_percent = None
        txn.first_installment    = txn.second_installment = txn.third_installment = None

    if allocation.payment_type == "full":
        # write payment_method
        txn.payment_method = pm or None
    else:
        txn.payment_method = None

    # --- 4) Save & respond ---
    try:
        txn.save()
        return redirect("management-dashboard")
    except Exception as e:
        return render(request, "admin_side/management-dashboard.html", {
            "all_clients": ClientUser.objects.all(),
            "error":       str(e),
            "posted":      request.POST,
        })


@login_required
def ajax_client_marketer(request):
    client_id = request.GET.get('client_id')
    if not client_id:
        return JsonResponse({'error': 'Missing client_id'}, status=400)
    
    try:
        client = ClientUser.objects.get(pk=client_id)
        marketer = client.assigned_marketer
        return JsonResponse({
            'marketer_name': marketer.full_name if marketer else 'No marketer assigned'
        })
    except ClientUser.DoesNotExist:
        return JsonResponse({'error': 'Client not found'}, status=404)

@login_required
def ajax_client_allocations(request):
    client_id = request.GET.get('client_id')
    if not client_id:
        return JsonResponse({'error': 'Missing client_id'}, status=400)
    
    try:
        allocations = PlotAllocation.objects.filter(
            client_id=client_id
        ).select_related('estate', 'plot_size_unit__plot_size')
        
        data = [{
            'id': alloc.id,
            'estate_name': alloc.estate.name,
            'plot_size': alloc.plot_size_for_transaction,
            'payment_type': alloc.payment_type,
            'date_allocated': alloc.date_allocated.strftime('%Y-%m-%d'),
        } for alloc in allocations]
        
        return JsonResponse(data, safe=False)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@require_GET
def ajax_allocation_info(request):
    alloc_id = request.GET.get("allocation_id")
    if not alloc_id:
        return HttpResponseBadRequest("Missing allocation_id")

    alloc = get_object_or_404(
        PlotAllocation.objects.select_related(
            'estate',
            'plot_size_unit__plot_size',
            'client__assigned_marketer'
        ),
        pk=alloc_id
    )

    txn = Transaction.objects.filter(allocation=alloc).order_by('-transaction_date').first()

    payload = {
        "plot_size": alloc.plot_size_unit.plot_size.size,
        "payment_type": alloc.payment_type,
        "marketer_name": alloc.client.assigned_marketer.full_name if alloc.client.assigned_marketer else "",
        "transaction_date": alloc.date_allocated.strftime("%Y-%m-%d"),
        "total_amount": "",
        "special_notes": "",
        "installment_plan": "",
        "first_percent": "",
        "second_percent": "",
        "third_percent": "",
        "payment_duration": "",
        "custom_duration": ""
    }

    if txn:
        payload.update({
            "transaction_date": txn.transaction_date.strftime("%Y-%m-%d"),
            "total_amount": str(txn.total_amount),
            "special_notes": txn.special_notes or "",
            "installment_plan": txn.installment_plan or "",
            "first_percent": txn.first_percent or "",
            "second_percent": txn.second_percent or "",
            "third_percent": txn.third_percent or "",
            "payment_duration": txn.payment_duration or "",
            "custom_duration": txn.custom_duration or ""
        })

    return JsonResponse(payload)


@require_GET
def ajax_get_unpaid_installments(request):
    txn_id = request.GET.get("transaction_id")
    if not txn_id:
        return JsonResponse({"error": "Missing transaction_id"}, status=400)
    txn = get_object_or_404(Transaction, pk=txn_id)

    label_map = {
        1: "First",
        2: "Second",
        3: "Third",
    }

    payload = []
    for inst in txn.payment_installments:
        n = inst.get("n")
        payload.append({
            "n":         n,
            "label":     inst.get("label", label_map.get(n, f"Installment {n}")),
            "due":       f"{inst.get('due', 0):.2f}",
            "remaining": f"{inst.get('remaining', 0):.2f}",
        })

    return JsonResponse({"installments": payload})


@login_required
def generate_receipt_pdf(request, transaction_id):
    transaction = get_object_or_404(Transaction.objects.select_related(
        'client', 'allocation__estate', 'marketer'
    ), pk=transaction_id)
    
    # Generate a unique receipt ID
    receipt_id = f"REC-{uuid.uuid4().hex[:8].upper()}"
    today = datetime.date.today().strftime("%d %b %Y")
    
    context = {
        'transaction': transaction,
        'receipt_id': receipt_id,
        'date': today,
        'company': {
            'name': "NeuraLens Properties",
            'address': "123 Estate Avenue, City",
            'phone': "+234 800 000 0000",
            'email': "info@neuralensproperties.com",
            'logo': settings.STATIC_URL + "img/logo.png"
        }
    }
    
    template = get_template('admin_side/management_page_sections/payment_reciept.html')
    html = template.render(context)
    
    result = BytesIO()
    pdf = pisa.pisaDocument(BytesIO(html.encode("UTF-8")), result)
    
    if not pdf.err:
        response = HttpResponse(result.getvalue(), content_type='application/pdf')
        filename = f"Receipt_{receipt_id}_{transaction.client.full_name}.pdf"
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response
    
    return HttpResponse("Error generating PDF", status=400)


@require_GET
def ajax_payment_history(request):
    txn_id = request.GET.get("transaction_id")
    if not txn_id:
        return JsonResponse({"error": "Missing transaction_id"}, status=400)

    txn = get_object_or_404(Transaction, pk=txn_id)

    # FULL PAYMENT → 1 line straight off Transaction
    if txn.allocation.payment_type == 'full':
        return JsonResponse({
            "payments": [{
                "date": txn.transaction_date.strftime("%d %b %Y"),
                "amount": str(txn.total_amount.quantize(Decimal('0.01'))),
                "method": txn.get_payment_method_display() or "",
                "installment": "Full Payment",
                "reference": txn.reference_code or ""
            }]
        })

    # PART‐PAYMENT → group by receipt
    qs = txn.payment_records.order_by('-payment_date')
    grouped = {}
    for p in qs:
        key = p.reference_code
        if key not in grouped:
            grouped[key] = {
                "date": p.payment_date.strftime("%d %b %Y"),
                "amount": Decimal('0.00'),
                "method": p.get_payment_method_display(),
                "installment": p.get_selected_installment_display() or "",  # Use selected installment
                "reference": key,
            }
        grouped[key]["amount"] += p.amount_paid

    payments = []
    for rec in grouped.values():
        rec["amount"] = str(rec["amount"].quantize(Decimal('0.01')))
        payments.append(rec)

    return JsonResponse({"payments": payments})

@require_POST
@transaction.atomic
def ajax_record_payment(request):
    txn_id = request.POST.get("transaction_id")
    inst_no = request.POST.get("installment")
    amt_s = request.POST.get("amount_paid")
    pay_date = request.POST.get("payment_date")
    method = request.POST.get("payment_method")

    if not all([txn_id, amt_s, pay_date, method]):
        return HttpResponseBadRequest("Missing required fields")

    txn = get_object_or_404(Transaction, pk=txn_id)
    total = Decimal(amt_s)
    
    # Cap payment at remaining balance
    balance = txn.balance
    if total > balance:
        total = balance

    # Generate reference code
    prefix = "NLP"
    date_str = timezone.now().strftime("%Y%m%d")
    plot_raw = str(txn.allocation.plot_size)
    m = re.search(r'\d+', plot_raw)
    size_num = m.group(0) if m else plot_raw
    suffix = f"{random.randint(0, 9999):04d}"
    reference_code = f"{prefix}{date_str}-{size_num}-{suffix}"

    # Get installments in order
    installments = txn.payment_installments
    remaining = total
    records = []

    # Always allocate in installment order (1, 2, 3)
    for inst in installments:
        if remaining <= 0:
            break
            
        # Skip already paid installments
        if inst['remaining'] <= 0:
            continue
            
        # Calculate allocation amount
        slice_amt = min(inst['remaining'], remaining)
        
        records.append(
            PaymentRecord(
                transaction=txn,
                installment=inst['n'],
                amount_paid=slice_amt,
                payment_date=pay_date,
                payment_method=method,
                reference_code=reference_code,
                selected_installment=int(inst_no) if inst_no else None
            )
        )
        remaining -= slice_amt

    # Create all records at once
    PaymentRecord.objects.bulk_create(records)
    
    # Update transaction status if fully paid
    if txn.balance <= 0:
        # This will be reflected in the status property next time it's accessed
        pass

    return JsonResponse({
        "success": True,
        "reference_code": reference_code,
    })

def payment_receipt(request, reference_code):
    # For full payments
    if Transaction.objects.filter(reference_code=reference_code).exists():
        txn = Transaction.objects.get(reference_code=reference_code)
        payment = None
        payments = []
        payments_total = txn.total_amount
    else:
        # For installment payments
        payments = PaymentRecord.objects.filter(reference_code=reference_code)
        if not payments.exists():
            return HttpResponse("Receipt not found", status=404)
        
        txn = payments.first().transaction
        payment = payments.first()
        payments_total = sum(p.amount_paid for p in payments)
    
    # Generate receipt number if needed
    if payment and not payment.receipt_number:
        payment.generate_receipt_number()
        payment.receipt_generated = True
        payment.receipt_date = timezone.now()
        payment.save()
    
    context = {
        'transaction': txn,
        'payment': payment,
        'payments': payments,
        'payments_total': payments_total,
        'today': timezone.now().date(),
        'company': {
            'name': "NeuraLens Properties",
            'address': "123 NeuraLens, Wuse Zone 4, Abuja",
            'phone': "+234 812 345 6789",
            'email': "info@neuralensproperties.com",
            'website': "www.neuralensproperties.com"
        }
    }
    
    # Render HTML
    template = 'admin_side/management_page_sections/absolute_payment_reciept.html'
    html_string = render_to_string(template, context)
    
    # Add CSS styling directly to the HTML
    html_with_css = f"""
    <html>
    <head>
        <style>
            @page {{ size: A4; margin: 20mm; }}
            html, body {{ font-family: 'Poppins', sans-serif !important; font-size: 12px; margin: 0; padding: 0; }}
        </style>
    </head>
    <body>
        {html_string}
    </body>
    </html>
    """
    
    # Create PDF using xhtml2pdf
    result = BytesIO()
    pdf = pisa.pisaDocument(BytesIO(html_with_css.encode("UTF-8")), result)
    
    if not pdf.err:
        # Create HTTP response
        response = HttpResponse(content_type='application/pdf')
        filename = f"receipt_{reference_code}.pdf"
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        response.write(result.getvalue())
        return response
    else:
        return HttpResponse("Error generating PDF", status=500)

@require_GET
def ajax_transaction_details(request, transaction_id):
    txn = get_object_or_404(
        Transaction.objects.select_related(
            'allocation__estate',
            'client',
            'marketer'
        ),
        pk=transaction_id
    )

    data = {
        'client': txn.client.full_name,
        'marketer': txn.marketer.full_name if txn.marketer else '',
        'transaction_date': txn.transaction_date.strftime("%d %b %Y"),
        'total_amount': str(txn.total_amount),
        'status': txn.status,
        'allocation': {
            'estate': {
                'name': txn.allocation.estate.name
            },
            'plot_size': txn.allocation.plot_size_for_transaction,
            'payment_type': txn.allocation.payment_type
        },
        # ← Add these two:
        'payment_duration': txn.payment_duration,      # integer months or None
        'custom_duration': txn.custom_duration,        # integer months or None

        'installment_plan': txn.installment_plan,
        'first_percent': txn.first_percent,
        'second_percent': txn.second_percent,
        'third_percent': txn.third_percent,
        'first_installment': str(txn.first_installment)  if txn.first_installment  else None,
        'second_installment': str(txn.second_installment) if txn.second_installment else None,
        'third_installment': str(txn.third_installment)   if txn.third_installment  else None,
    }

    return JsonResponse(data)

@require_GET
def ajax_existing_transaction(request):
    """
    Given client_id & allocation_id, return the existing transaction’s
    payment_method and reference_code (if any), so the form can pre-fill.
    """
    client_id     = request.GET.get('client_id')
    allocation_id = request.GET.get('allocation_id')

    txn = (
        Transaction.objects
        .filter(client_id=client_id, allocation_id=allocation_id)
        .first()
    )

    if not txn:
        return JsonResponse({'payment_method': None, 'reference_code': None})

    return JsonResponse({
        'payment_method': txn.payment_method,
        'reference_code': txn.reference_code,
    })

@require_POST
def ajax_send_receipt(request):
    txn_id = request.POST.get("transaction_id")
    if not txn_id:
        return JsonResponse({"error":"Missing transaction_id"}, status=400)

    try:
        txn = Transaction.objects.get(pk=txn_id)
        # Here you would implement your actual email sending logic
        # For now we'll just simulate success
        return JsonResponse({"success": True, "message": "Receipt sent successfully"})
    except Transaction.DoesNotExist:
        return JsonResponse({"error": "Transaction not found"}, status=404)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)


# Sales Volume
class MarketersAPI(View):
    def get(self, request):
        marketers = User.objects.filter(role='marketer').values('id', 'full_name')
        return JsonResponse(list(marketers), safe=False)

class MarketerPerformanceView(View):
    template_name = 'dashboard/performance.html'
    
    def get(self, request):
        return render(request, self.template_name)
    
    def post(self, request):
        return JsonResponse({'status': 'error'}, status=400)


class PerformanceDataAPI(View):
    def get(self, request):
        period_type     = request.GET.get('period_type', 'monthly')
        specific_period = request.GET.get('specific_period')
        if not specific_period:
            return JsonResponse({'error': 'Specific period required'}, status=400)

        today = timezone.now().date()
        start_date, end_date = self.get_date_range(period_type, specific_period)

        # 1) Gather all metrics first
        response_data    = []
        record_payloads  = []

        for marketer in MarketerUser.objects.all():
            # transactions in period
            txns = Transaction.objects.filter(
                marketer=marketer,
                transaction_date__range=(start_date, end_date)
            )
            closed_deals  = txns.count()
            total_sales   = txns.aggregate(total=Sum('total_amount'))['total'] or 0

            # commission lookup
            commission = (
                MarketerCommission.objects
                .filter(Q(marketer=marketer) | Q(marketer=None),
                        effective_date__lte=today)
                .order_by('-effective_date')
                .first()
            )
            rate               = commission.rate if commission else 0
            commission_earned  = total_sales * rate / 100

            # target lookup: specific → global → none
            specific_tgt = MarketerTarget.objects.filter(
                marketer=marketer,
                period_type=period_type,
                specific_period=specific_period
            ).first()
            if specific_tgt:
                tgt_amt = specific_tgt.target_amount
            else:
                global_tgt = MarketerTarget.objects.filter(
                    marketer=None,
                    period_type=period_type,
                    specific_period=specific_period
                ).first()
                tgt_amt = global_tgt.target_amount if global_tgt else 0

            target_percent = round((total_sales / tgt_amt * 100), 1) if tgt_amt else 0

            # stash for JSON
            response_data.append({
                'marketer_id':       marketer.id,
                'marketer_name':     marketer.full_name,
                'closed_deals':      closed_deals,
                'total_sales':       float(total_sales),
                'commission_rate':   float(rate),
                'commission_earned': float(commission_earned),
                'target_amount':     float(tgt_amt),
                'target_percent':    target_percent,
            })

            # stash for DB write
            record_payloads.append({
                'marketer':         marketer,
                'period_type':      period_type,
                'specific_period':  specific_period,
                'closed_deals':     closed_deals,
                'total_sales':      total_sales,
                'commission_earned': commission_earned,
            })

        # 2) Write performance records in their own small transactions
        for rec in record_payloads:
            try:
                with transaction.atomic():
                    MarketerPerformanceRecord.objects.update_or_create(
                        marketer=rec['marketer'],
                        period_type=rec['period_type'],
                        specific_period=rec['specific_period'],
                        defaults={
                            'closed_deals':      rec['closed_deals'],
                            'total_sales':       rec['total_sales'],
                            'commission_earned': rec['commission_earned'],
                        }
                    )
            except DatabaseError:
                # Skip on DB lock or other error
                continue

        return JsonResponse(response_data, safe=False)

    def get_date_range(self, period_type, specific_period):
        today = timezone.now().date()

        if period_type == 'monthly':
            year, month = map(int, specific_period.split('-'))
            start = datetime(year, month, 1).date()
            end   = (start + relativedelta(months=1)) - timedelta(days=1)

        elif period_type == 'quarterly':
            y_str, q_str = specific_period.split('-Q')
            y, q = int(y_str), int(q_str)
            start_month = 3*(q-1) + 1
            start = datetime(y, start_month, 1).date()
            if q == 4:
                next_start = datetime(y+1, 1, 1).date()
            else:
                next_start = datetime(y, start_month+3, 1).date()
            end = next_start - timedelta(days=1)

        else:  # annual
            y = int(specific_period)
            start = datetime(y, 1, 1).date()
            end   = datetime(y, 12, 31).date()

        return start, end


class SetTargetAPI(View):
    def get(self, request):
        return HttpResponseNotAllowed(['POST'])

    def post(self, request):
        # Parse payload
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({'status':'error','message':'Invalid JSON'}, status=400)

        period_type     = data.get('period_type')
        specific_period = data.get('specific_period')
        target_amount   = data.get('target_amount')

        # Validate
        if not period_type or not specific_period:
            return JsonResponse({'status':'error','message':'period_type & specific_period required'}, status=400)
        if target_amount is None:
            return JsonResponse({'status':'error','message':'target_amount required'}, status=400)

        # Always write the one global record (marketer=None)
        MarketerTarget.objects.update_or_create(
            marketer=None,
            period_type=period_type,
            specific_period=specific_period,
            defaults={'target_amount': target_amount}
        )

        return JsonResponse({'status':'success'})


class GetGlobalTargetAPI(View):
    def get(self, request):
        period_type     = request.GET.get('period_type')
        specific_period = request.GET.get('specific_period')

        if not period_type or not specific_period:
            return JsonResponse({'status':'error','message':'period_type & specific_period required'}, status=400)

        record = MarketerTarget.objects.filter(
            marketer=None,
            period_type=period_type,
            specific_period=specific_period
        ).first()

        return JsonResponse({
            'target_amount': record.target_amount if record else None
        })


class SetCommissionAPI(View):
    def get(self, request):
        return HttpResponseNotAllowed(['POST'])

    def post(self, request):
        try:
            payload = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({'status':'error','message':'Invalid JSON'}, status=400)

        marketer_id    = payload.get('marketer')
        rate           = payload.get('commission_rate')
        effective_date = payload.get('effective_date')

        # Basic validation
        if marketer_id is None or rate is None or not effective_date:
            return JsonResponse({'status':'error','message':'Missing parameters'}, status=400)

        # Fetch exactly one marketer
        try:
            marketer = MarketerUser.objects.get(id=marketer_id)
        except MarketerUser.DoesNotExist:
            return JsonResponse({'status':'error','message':'Marketer not found'}, status=404)

        # Look for the latest commission record
        existing = (
            MarketerCommission.objects
            .filter(marketer=marketer)
            .order_by('-effective_date')
            .first()
        )

        if existing:
            # Update the most recent record
            existing.rate = rate
            existing.effective_date = effective_date
            existing.save(update_fields=['rate', 'effective_date'])
        else:
            # No existing commission—create a new one
            MarketerCommission.objects.create(
                marketer=marketer,
                rate=rate,
                effective_date=effective_date
            )

        return JsonResponse({'status':'success'})

class GetCommissionAPI(View):
    def get(self, request):
        marketer_id = request.GET.get('marketer')
        if not marketer_id:
            return JsonResponse({'status':'error','message':'marketer param required'}, status=400)

        try:
            marketer = MarketerUser.objects.get(id=marketer_id)
        except MarketerUser.DoesNotExist:
            return JsonResponse({'status':'error','message':'Marketer not found'}, status=404)

        commission = MarketerCommission.objects.filter(
            marketer=marketer
        ).order_by('-effective_date').first()

        if not commission:
            # no commission yet
            return JsonResponse({'commission_rate': None, 'effective_date': None})

        return JsonResponse({
            'commission_rate': commission.rate,
            'effective_date': commission.effective_date.isoformat()
        })


class ExportPerformanceAPI(View):
    def get(self, request):
        period_type = request.GET.get('period_type')
        specific_period = request.GET.get('specific_period')
        format = request.GET.get('format', 'csv')
        
        # This would generate a file in real implementation
        # For now, just return success
        return JsonResponse({
            'status': 'success',
            'message': f'Exported {period_type} {specific_period} in {format.upper()} format'
        })


# VALUE REGULATION
def is_admin(user):
    return user.is_authenticated and user.role == "admin"

@require_http_methods(["GET"])
@login_required
@user_passes_test(is_admin)
def estate_plot_sizes(request, estate_id):
    estate = get_object_or_404(Estate, pk=estate_id)
    units = PlotSizeUnits.objects.filter(estate_plot__estate=estate).select_related('plot_size')
    
    plot_units = [{
        "id": u.id,
        "size": u.plot_size.size,
        "available": u.available_units
    } for u in units]

    location = estate.location
    plot_unit_id = request.GET.get("plot_unit_id")
    existing = None
    
    if plot_unit_id:
        try:
            pp = PropertyPrice.objects.get(estate=estate, plot_unit__id=plot_unit_id)
            existing = {
                "presale": str(pp.presale),
                "previous": str(pp.previous),
                "current": str(pp.current),
                "effective": pp.effective.isoformat(),
                "notes": pp.notes or ""
            }
        except PropertyPrice.DoesNotExist:
            pass

    return JsonResponse({
        "plot_units": plot_units,
        "location": location,
        "existing_price": existing,
    })



@login_required
@user_passes_test(is_admin)
def estate_bulk_price_data(request, estate_id):
    """
    Returns estate info with all plot units and their current prices for bulk updating.
    """
    estate = get_object_or_404(Estate, pk=estate_id)
    
    # Get all plot size units for this estate
    units = PlotSizeUnits.objects.filter(
        estate_plot__estate=estate
    ).select_related('plot_size').distinct()
    
    plot_units = []
    for unit in units:
        # Try to get existing price
        try:
            pp = PropertyPrice.objects.get(estate=estate, plot_unit=unit)
            presale = float(pp.presale)
            previous = float(pp.previous)
            current = float(pp.current)
        except PropertyPrice.DoesNotExist:
            presale = 0
            previous = 0
            current = 0
        
        plot_units.append({
            "id": unit.id,
            "size": unit.plot_size.size,
            "available": unit.available_units,
            "total": unit.total_units,
            "presale": presale,
            "previous": previous,
            "current": current,
        })
    
    return JsonResponse({
        "estate": {
            "id": estate.id,
            "name": estate.name,
            "location": estate.location,
        },
        "plot_units": plot_units,
    })


def send_bulk_price_update_notification(estate, price_changes, unlaunched_plots, effective_date, notes):
    """
    Send comprehensive notifications to clients and marketers about bulk price updates.
    Uses the SAME notification system as the "Send Notification" modal.
    
    Args:
        estate: Estate object
        price_changes: List of dicts with plot_size, previous_price, new_price, pct_change, available, total, is_sold_out, changed
        unlaunched_plots: List of plot sizes (strings) that have no PropertyPrice yet
        effective_date: Date string for when prices become effective
        notes: Additional notes about the price update
    
    Returns:
        dict with notification counts
    """
    from datetime import datetime
    
    # Get User model
    User = get_user_model()
    
    # Categorize plots
    changed_plots = [p for p in price_changes if p['changed'] and not p['is_sold_out']]
    unchanged_plots = [p for p in price_changes if not p['changed'] and not p['is_sold_out']]
    sold_out_plots = [p for p in price_changes if p['is_sold_out']]
    
    # Format effective date
    try:
        eff_date = datetime.strptime(effective_date, '%Y-%m-%d').strftime('%B %d, %Y')
    except:
        eff_date = effective_date
    
    # Build HTML notification message
    message_parts = []
    
    # Header
    message_parts.append(f"""
    <div style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0;">
            <h2 style="margin: 0; font-size: 24px;">🏘️ NEW PRICE REVIEW FOR {estate.name}</h2>
            <p style="margin: 10px 0 0 0; font-size: 14px; opacity: 0.9;">Effective Date: {eff_date}</p>
        </div>
        <div style="background: #f8f9fa; padding: 20px; border: 1px solid #e0e0e0; border-top: none;">
    """)
    
    # Changed Plots Section (Price Increased or Decreased)
    if changed_plots:
        message_parts.append("""
        <div style="margin-bottom: 20px;">
            <h3 style="color: #333; font-size: 18px; margin-bottom: 15px; border-bottom: 2px solid #667eea; padding-bottom: 5px;">
                📊 Price Updates
            </h3>
            <table style="width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                <thead>
                    <tr style="background: #667eea; color: white;">
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #5568d3;">Plot Size</th>
                        <th style="padding: 12px; text-align: right; border-bottom: 2px solid #5568d3;">Presale Price</th>
                        <th style="padding: 12px; text-align: right; border-bottom: 2px solid #5568d3;">Previous Price</th>
                        <th style="padding: 12px; text-align: right; border-bottom: 2px solid #5568d3;">New Price</th>
                        <th style="padding: 12px; text-align: center; border-bottom: 2px solid #5568d3;">Change</th>
                        <th style="padding: 12px; text-align: center; border-bottom: 2px solid #5568d3;">Total % from Presale</th>
                    </tr>
                </thead>
                <tbody>
        """)
        
        for plot in changed_plots:
            pct_change = plot['pct_change']
            total_pct = plot['total_pct']
            presale_price = plot.get('presale', 0)
            
            change_color = '#28a745' if pct_change > 0 else '#dc3545' if pct_change < 0 else '#6c757d'
            change_icon = '📈' if pct_change > 0 else '📉' if pct_change < 0 else '➖'
            badge_color = 'background: #d4edda; color: #155724; border: 1px solid #c3e6cb;' if pct_change > 0 else 'background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb;'
            
            # Total % styling
            total_color = '#28a745' if total_pct > 0 else '#dc3545' if total_pct < 0 else '#6c757d'
            total_icon = '🚀' if total_pct > 0 else '⬇️' if total_pct < 0 else '➖'
            total_badge_color = 'background: #d1f2eb; color: #0c5460; border: 1px solid #bee5eb; font-weight: 700;' if total_pct > 0 else 'background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb;'
            
            message_parts.append(f"""
                    <tr style="border-bottom: 1px solid #e0e0e0;">
                        <td style="padding: 12px; font-weight: 600; color: #333;">{plot['plot_size']}</td>
                        <td style="padding: 12px; text-align: right; color: #666; font-style: italic;">₦{presale_price:,.0f}</td>
                        <td style="padding: 12px; text-align: right; color: #666;">₦{plot['previous_price']:,.0f}</td>
                        <td style="padding: 12px; text-align: right; font-weight: 700; color: {change_color};">₦{plot['new_price']:,.0f}</td>
                        <td style="padding: 12px; text-align: center;">
                            <span style="{badge_color} padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; display: inline-block;">
                                {change_icon} {pct_change:+.1f}%
                            </span>
                        </td>
                        <td style="padding: 12px; text-align: center;">
                            <span style="{total_badge_color} padding: 6px 12px; border-radius: 12px; font-size: 13px; display: inline-block;">
                                {total_icon} {total_pct:+.1f}%
                            </span>
                        </td>
                    </tr>
            """)
        
        message_parts.append("""
                </tbody>
            </table>
        </div>
        """)
    
    # Sold Out Plots Section
    if sold_out_plots:
        message_parts.append("""
        <div style="margin-bottom: 20px;">
            <h3 style="color: #dc3545; font-size: 16px; margin-bottom: 10px;">
                🚫 Sold Out Plots
            </h3>
            <div style="background: white; padding: 15px; border-radius: 8px; border-left: 4px solid #dc3545;">
        """)
        
        for plot in sold_out_plots:
            message_parts.append(f"""
                <div style="padding: 8px 0; border-bottom: 1px dashed #e0e0e0; display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-weight: 600; color: #333;">{plot['plot_size']}</span>
                    <span style="background: #f8d7da; color: #721c24; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600;">SOLD OUT</span>
                </div>
            """)
        
        message_parts.append("""
            </div>
        </div>
        """)
    
    # Not Launched Yet Section
    if unlaunched_plots:
        message_parts.append("""
        <div style="margin-bottom: 20px;">
            <h3 style="color: #ffc107; font-size: 16px; margin-bottom: 10px;">
                🔜 Coming Soon
            </h3>
            <div style="background: white; padding: 15px; border-radius: 8px; border-left: 4px solid #ffc107;">
        """)
        
        for plot_size in unlaunched_plots:
            message_parts.append(f"""
                <div style="padding: 8px 0; border-bottom: 1px dashed #e0e0e0; display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-weight: 600; color: #333;">{plot_size}</span>
                    <span style="background: #fff3cd; color: #856404; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600;">NOT LAUNCHED YET</span>
                </div>
            """)
        
        message_parts.append("""
            </div>
        </div>
        """)
    
    # Additional Notes
    if notes and notes.strip():
        message_parts.append(f"""
        <div style="background: white; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #17a2b8;">
            <h4 style="color: #17a2b8; font-size: 14px; margin: 0 0 8px 0;">📝 Additional Notes:</h4>
            <p style="margin: 0; color: #666; font-size: 14px; line-height: 1.6;">{notes}</p>
        </div>
        """)
    
    # Call to Action
    message_parts.append("""
        <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; margin-top: 20px;">
            <h3 style="margin: 0 0 10px 0; font-size: 20px;">🚀 HURRY UP TO BAG THIS OPPORTUNITY!</h3>
            <p style="margin: 0; font-size: 14px; opacity: 0.95;">Don't miss out on these updated prices. Contact us today to secure your plot!</p>
        </div>
        </div>
    </div>
    """)
    
    full_message = ''.join(message_parts)
    subject = f'Price Update: {estate.name}'
    
    # Create notification for CLIENTS (using SAME approach as notify_clients_marketer)
    client_notif = Notification.objects.create(
        title=subject,
        message=full_message,
        notification_type=Notification.CLIENT_ANNOUNCEMENT
    )
    
    # Create notification for MARKETERS
    marketer_notif = Notification.objects.create(
        title=subject,
        message=full_message,
        notification_type=Notification.MARKETER_ANNOUNCEMENT
    )
    
    # Get users by role (SAME as notify_clients_marketer function)
    clients = User.objects.filter(role='client')
    marketers = User.objects.filter(role='marketer')
    
    # Link notifications to users (SAME approach as notify_clients_marketer)
    clients_count = 0
    for user in clients:
        UserNotification.objects.get_or_create(user=user, notification=client_notif)
        clients_count += 1
    
    marketers_count = 0
    for user in marketers:
        UserNotification.objects.get_or_create(user=user, notification=marketer_notif)
        marketers_count += 1
    
    return {
        'clients_notified': clients_count,
        'marketers_notified': marketers_count,
        'total_notified': clients_count + marketers_count
    }


@csrf_exempt
@login_required
@user_passes_test(is_admin)
@require_http_methods(["POST"])
def property_price_bulk_update(request):
    """
    Bulk update property prices for multiple plot units.
    """
    try:
        payload = json.loads(request.body)
        estate_id = payload["estate_id"]
        effective = payload["effective"]
        notes = payload.get("notes", "")
        notify = payload.get("notify", False)
        updates = payload["updates"]  # List of {plot_unit_id, new_price}
        
        estate = Estate.objects.get(pk=estate_id)
    except (KeyError, Estate.DoesNotExist, json.JSONDecodeError, ValueError) as e:
        return JsonResponse({"status": "error", "message": f"Invalid payload: {str(e)}"}, status=400)
    
    if not updates:
        return JsonResponse({"status": "error", "message": "No updates provided"}, status=400)
    
    updated_rows = []
    updated_count = 0
    price_changes = []  # Track all price changes for notification
    
    with transaction.atomic():
        # Get all plot units for this estate to categorize them
        all_units = PlotSizeUnits.objects.filter(estate_plot__estate=estate).select_related('plot_size')
        updated_unit_ids = [u["plot_unit_id"] for u in updates]
        
        for update_data in updates:
            try:
                plot_unit_id = update_data["plot_unit_id"]
                new_price = Decimal(str(update_data["new_price"]))
                
                unit = PlotSizeUnits.objects.get(pk=plot_unit_id)
                
                # Get or create PropertyPrice
                try:
                    pp = PropertyPrice.objects.get(estate=estate, plot_unit=unit)
                    previous_current = pp.current
                    presale = pp.presale
                    
                    # Calculate percentage change
                    if previous_current > 0:
                        pct_change = ((new_price - previous_current) / previous_current * 100)
                    else:
                        pct_change = Decimal(0)
                    
                    # Calculate total % from presale
                    if presale and presale > 0:
                        total_pct = ((new_price - presale) / presale) * 100
                    else:
                        total_pct = Decimal(0)
                    
                    # Update existing
                    pp.previous = previous_current
                    pp.current = new_price
                    pp.effective = effective
                    pp.notes = notes
                    pp.save()
                    
                except PropertyPrice.DoesNotExist:
                    # Create new with presale = new_price
                    pp = PropertyPrice.objects.create(
                        estate=estate,
                        plot_unit=unit,
                        presale=new_price,
                        previous=new_price,
                        current=new_price,
                        effective=effective,
                        notes=notes
                    )
                    previous_current = new_price
                    presale = new_price
                    pct_change = Decimal(0)
                
                # Calculate total % from presale
                if presale and presale > 0:
                    total_pct = ((new_price - presale) / presale) * 100
                else:
                    total_pct = Decimal(0)
                
                # Track price change info
                price_changes.append({
                    'plot_size': unit.plot_size.size,
                    'previous_price': float(previous_current),
                    'new_price': float(new_price),
                    'pct_change': float(pct_change),
                    'total_pct': float(total_pct),
                    'presale': float(presale),
                    'available': unit.available_units,
                    'total': unit.total_units,
                    'is_sold_out': unit.available_units == 0,
                    'changed': previous_current != new_price
                })
                
                # Create history entry
                PriceHistory.objects.create(
                    price=pp,
                    presale=pp.presale,
                    previous=previous_current,
                    current=pp.current,
                    effective=effective,
                    notes=notes
                )
                
                row_key = f"{estate_id}-{plot_unit_id}"
                updated_rows.append(row_key)
                updated_count += 1
                
            except (KeyError, PlotSizeUnits.DoesNotExist, ValueError) as e:
                # Skip invalid updates
                continue
        
        # Check for unlaunched plots (no PropertyPrice yet)
        unlaunched_plots = []
        for unit in all_units:
            if unit.id not in updated_unit_ids:
                try:
                    PropertyPrice.objects.get(estate=estate, plot_unit=unit)
                except PropertyPrice.DoesNotExist:
                    unlaunched_plots.append(unit.plot_size.size)
    
    # Send notifications if requested
    if notify and price_changes:
        try:
            notification_result = send_bulk_price_update_notification(
                estate=estate,
                price_changes=price_changes,
                unlaunched_plots=unlaunched_plots,
                effective_date=effective,
                notes=notes
            )
        except Exception as e:
            # Log error but don't fail the update
            print(f"Notification error: {str(e)}")
    
    return JsonResponse({
        "status": "ok",
        "updated_count": updated_count,
        "updated_rows": updated_rows,
        "notification_sent": notify and len(price_changes) > 0
    })


@csrf_exempt
@login_required
@user_passes_test(is_admin)
@require_http_methods(["POST"])
def property_price_add(request):
    try:
        payload = json.loads(request.body)
        estate_id = payload["estate_id"]
        plot_unit_id = payload["plot_unit_id"]
        presale = Decimal(payload["presale"])
        effective = payload["effective"]
        notes = payload.get("notes", "")
        
        estate = Estate.objects.get(pk=estate_id)
        unit = PlotSizeUnits.objects.get(pk=plot_unit_id)

    except (KeyError, Estate.DoesNotExist, PlotSizeUnits.DoesNotExist, 
            ValueError, json.JSONDecodeError) as e:
        return HttpResponseBadRequest("Invalid payload")

    with transaction.atomic():
        obj, created = PropertyPrice.objects.update_or_create(
            estate=estate,
            plot_unit=unit,
            defaults={
                "presale": presale,
                "previous": presale,
                "current": presale,
                "effective": effective,
                "notes": notes,
            }
        )
        
        PriceHistory.objects.create(
            price=obj,
            presale=presale,
            previous=obj.previous,
            current=obj.current,
            effective=effective,
            notes=notes
        )

    return JsonResponse({
        "status": "ok", 
        "id": obj.id, 
        "created": created,
        "row_key": f"{estate_id}-{plot_unit_id}"
    })


def send_single_price_update_notification(estate, plot_size, presale_price, previous_price, new_price, effective_date, notes):
    """
    Send notification to clients and marketers about a single property price update.
    
    Args:
        estate: Estate object
        plot_size: String (e.g., "500 sqm")
        presale_price: Float - original launch price
        previous_price: Float - price before update
        new_price: Float - updated current price
        effective_date: Date string for when price becomes effective
        notes: Additional notes about the price update
    """
    from datetime import datetime
    
    # Get User model
    User = get_user_model()
    
    # Calculate percentages
    if previous_price > 0:
        pct_change = ((new_price - previous_price) / previous_price) * 100
    else:
        pct_change = 0
    
    if presale_price > 0:
        total_pct = ((new_price - presale_price) / presale_price) * 100
    else:
        total_pct = 0
    
    # Format effective date
    try:
        eff_date = datetime.strptime(effective_date, '%Y-%m-%d').strftime('%B %d, %Y')
    except:
        eff_date = effective_date
    
    # Determine change direction
    change_icon = '📈' if pct_change > 0 else '📉' if pct_change < 0 else '➖'
    change_word = 'INCREASE' if pct_change > 0 else 'DECREASE' if pct_change < 0 else 'NO CHANGE'
    change_color = '#28a745' if pct_change > 0 else '#dc3545' if pct_change < 0 else '#6c757d'
    badge_color = 'background: #d4edda; color: #155724; border: 1px solid #c3e6cb;' if pct_change > 0 else 'background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb;'
    
    # Total % styling
    total_icon = '🚀' if total_pct > 0 else '⬇️' if total_pct < 0 else '➖'
    total_badge_color = 'background: #d1f2eb; color: #0c5460; border: 1px solid #bee5eb; font-weight: 700;' if total_pct > 0 else 'background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb;'
    
    # Build HTML notification message
    message = f"""
    <div style="font-family: Arial, sans-serif; max-width: 700px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 25px; border-radius: 12px 12px 0 0; text-align: center;">
            <h2 style="margin: 0 0 10px 0; font-size: 26px; font-weight: 800;">🏘️ PRICE ALERT!</h2>
            <h3 style="margin: 0; font-size: 20px; font-weight: 700; opacity: 0.95;">{estate.name}</h3>
            <p style="margin: 8px 0 0 0; font-size: 14px; opacity: 0.9;">📍 {estate.location}</p>
        </div>
        
        <div style="background: #f8f9fa; padding: 25px; border: 1px solid #e0e0e0; border-top: none;">
            <!-- Plot Size Banner -->
            <div style="background: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; border-left: 5px solid #667eea; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
                <div style="font-size: 14px; color: #666; margin-bottom: 5px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Plot Size</div>
                <div style="font-size: 28px; font-weight: 800; color: #667eea;">{plot_size}</div>
            </div>
            
            <!-- Price Comparison Table -->
            <div style="background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08); margin-bottom: 20px;">
                <table style="width: 100%; border-collapse: collapse;">
                    <thead>
                        <tr style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
                            <th style="padding: 15px; text-align: left; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Price Point</th>
                            <th style="padding: 15px; text-align: right; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Amount</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr style="border-bottom: 1px solid #f0f0f0;">
                            <td style="padding: 15px; color: #666; font-size: 14px; font-weight: 600; font-style: italic;">Presale Price (Launch)</td>
                            <td style="padding: 15px; text-align: right; color: #666; font-size: 16px; font-weight: 600;">₦{presale_price:,.0f}</td>
                        </tr>
                        <tr style="border-bottom: 1px solid #f0f0f0;">
                            <td style="padding: 15px; color: #666; font-size: 14px; font-weight: 600;">Previous Price</td>
                            <td style="padding: 15px; text-align: right; color: #666; font-size: 16px; font-weight: 600;">₦{previous_price:,.0f}</td>
                        </tr>
                        <tr style="background: rgba(102, 126, 234, 0.05);">
                            <td style="padding: 15px; color: #333; font-size: 15px; font-weight: 700;">NEW PRICE</td>
                            <td style="padding: 15px; text-align: right; font-size: 20px; font-weight: 800; color: {change_color};">₦{new_price:,.0f}</td>
                        </tr>
                    </tbody>
                </table>
            </div>
            
            <!-- Change Badges -->
            <div style="display: flex; gap: 15px; margin-bottom: 20px; flex-wrap: wrap;">
                <div style="flex: 1; min-width: 200px; background: white; padding: 20px; border-radius: 10px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
                    <div style="font-size: 12px; color: #666; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Recent Change</div>
                    <div style="{badge_color} padding: 10px 15px; border-radius: 8px; font-size: 18px; font-weight: 700; display: inline-block;">
                        {change_icon} {pct_change:+.1f}%
                    </div>
                    <div style="font-size: 13px; color: #666; margin-top: 8px; font-weight: 600;">{abs(pct_change):.1f}% {change_word}</div>
                </div>
                
                <div style="flex: 1; min-width: 200px; background: white; padding: 20px; border-radius: 10px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
                    <div style="font-size: 12px; color: #666; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Total Growth</div>
                    <div style="{total_badge_color} padding: 10px 15px; border-radius: 8px; font-size: 18px; font-weight: 700; display: inline-block;">
                        {total_icon} {total_pct:+.1f}%
                    </div>
                    <div style="font-size: 13px; color: #666; margin-top: 8px; font-weight: 600;">Since Launch</div>
                </div>
            </div>
            
            <!-- Effective Date -->
            <div style="background: white; padding: 18px; border-radius: 10px; margin-bottom: 20px; border-left: 4px solid #17a2b8; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="background: #17a2b8; color: white; width: 45px; height: 45px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 20px;">📅</div>
                    <div style="flex: 1;">
                        <div style="font-size: 12px; color: #666; margin-bottom: 3px; text-transform: uppercase; letter-spacing: 0.5px; font-weight: 600;">Effective Date</div>
                        <div style="font-size: 16px; color: #17a2b8; font-weight: 700;">{eff_date}</div>
                    </div>
                </div>
            </div>
            
            {f'''
            <!-- Notes -->
            <div style="background: white; padding: 18px; border-radius: 10px; margin-bottom: 20px; border-left: 4px solid #ffc107; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
                <div style="font-size: 12px; color: #666; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">📝 Additional Notes:</div>
                <div style="color: #333; font-size: 14px; line-height: 1.6;">{notes}</div>
            </div>
            ''' if notes and notes.strip() else ''}
            
            <!-- Call to Action -->
            <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 30px 25px; border-radius: 12px; text-align: center; box-shadow: 0 4px 15px rgba(240, 147, 251, 0.4);">
                <h3 style="margin: 0 0 12px 0; font-size: 24px; font-weight: 800;">🚀 HURRY UP TO BAG THIS OPPORTUNITY!</h3>
                <p style="margin: 0; font-size: 15px; opacity: 0.95; line-height: 1.5;">
                    {f"Don't miss out on this {abs(pct_change):.1f}% price {'increase' if pct_change > 0 else 'adjustment'}!" if pct_change != 0 else "Secure your plot at this competitive price!"}
                    <br>Contact us today to secure your investment!
                </p>
            </div>
        </div>
    </div>
    """
    
    subject = f'🏘️ Price Alert: {estate.name} - {plot_size}'
    
    # Create notification for CLIENTS
    client_notif = Notification.objects.create(
        title=subject,
        message=message,
        notification_type=Notification.CLIENT_ANNOUNCEMENT
    )
    
    # Create notification for MARKETERS
    marketer_notif = Notification.objects.create(
        title=subject,
        message=message,
        notification_type=Notification.MARKETER_ANNOUNCEMENT
    )
    
    # Get users by role
    clients = User.objects.filter(role='client')
    marketers = User.objects.filter(role='marketer')
    
    # Link notifications to users
    for user in clients:
        UserNotification.objects.get_or_create(user=user, notification=client_notif)
    
    for user in marketers:
        UserNotification.objects.get_or_create(user=user, notification=marketer_notif)
    
    return {
        'clients_count': clients.count(),
        'marketers_count': marketers.count()
    }


@csrf_exempt
@login_required
@user_passes_test(is_admin)
@require_http_methods(["POST", "PUT"])
def property_price_edit(request, pk):
    """
    Updates an existing PropertyPrice (only current/effective/notes)
    and appends a PriceHistory entry using the unchanged presale.
    Optionally sends notifications to clients and marketers.
    """
    pp = get_object_or_404(PropertyPrice, pk=pk)

    try:
        payload = json.loads(request.body)
        current = Decimal(payload["current"])
        effective = payload["effective"]
        notes = payload.get("notes", "")
        notify = payload.get("notify", False)
    except (KeyError, json.JSONDecodeError, ValueError) as e:
        return HttpResponseBadRequest(f"Invalid payload: {str(e)}")

    previous_current = pp.current
    presale = pp.presale

    pp.previous = previous_current
    pp.current = current
    pp.effective = effective
    pp.notes = notes
    pp.save()

    PriceHistory.objects.create(
        price=pp,
        presale=pp.presale,
        previous=previous_current,
        current=pp.current,
        effective=pp.effective,
        notes=pp.notes
    )

    # Send notifications if requested
    notification_sent = False
    if notify:
        try:
            send_single_price_update_notification(
                estate=pp.estate,
                plot_size=pp.plot_unit.plot_size.size,
                presale_price=float(presale),
                previous_price=float(previous_current),
                new_price=float(current),
                effective_date=effective,
                notes=notes
            )
            notification_sent = True
        except Exception as e:
            print(f"Notification error: {str(e)}")

    row_key = f"{pp.estate_id}-{pp.plot_unit_id}"
    return JsonResponse({
        "status": "ok",
        "row_key": row_key,
        "notification_sent": notification_sent
    })

@login_required
@require_POST
def property_price_save(request):
    estate_id = request.POST.get('estate')
    plot_unit_id = request.POST.get('plot_unit')
    presale = request.POST.get('presale')
    previous = request.POST.get('previous')
    current = request.POST.get('current')
    effective = request.POST.get('effective')
    notes = request.POST.get('notes', '')

    estate = get_object_or_404(Estate, id=estate_id)
    unit = get_object_or_404(PlotSizeUnits, id=plot_unit_id)
    created = False

    try:
        pp, created = PropertyPrice.objects.update_or_create(
            estate=estate, plot_unit=unit,
            defaults={
                'presale': presale,
                'previous': previous,
                'current': current,
                'effective': effective,
                'notes': notes
            }
        )
        response = {
            'success': True,
            'created': created,
            'price': {
                'id': pp.id,
                'estate': estate.name,
                'location': estate.location,
                'plot_unit': unit.name,
                'presale': str(pp.presale),
                'previous': str(pp.previous),
                'current': str(pp.current),
                'effective': pp.effective.isoformat(),
                'notes': pp.notes,
            }
        }
        return JsonResponse(response)

    except IntegrityError:
        return JsonResponse({'success': False, 'message': 'Duplicate estate + plot unit.'}, status=400)
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

def property_row_html(request, row_key):
    estate_id, unit_id = row_key.split('-')
    today = date.today()
    
    try:
        pp = PropertyPrice.objects.select_related(
            'estate', 'plot_unit__plot_size'
        ).get(
            estate_id=estate_id, 
            plot_unit_id=unit_id
        )
        
        # Check for active promo
        active_promo = PromotionalOffer.objects.filter(
            estates__id=estate_id,
            start__lte=today,
            end__gte=today
        ).first()
        
        # Calculate display values (same logic as management_dashboard)
        current_price = float(pp.current)
        
        if active_promo:
            discount_factor = float(1 - active_promo.discount / 100)
            discounted_price = Decimal(str(current_price * discount_factor))
        else:
            discounted_price = pp.current
        
        # Calculate percentages
        if pp.previous and pp.previous > 0:
            percent_change = (float(discounted_price) - float(pp.previous)) / float(pp.previous) * 100
            pp.percent_change = Decimal(str(percent_change))
        else:
            pp.percent_change = None
            
        if pp.presale and pp.presale > 0:
            overtime = (float(discounted_price) - float(pp.presale)) / float(pp.presale) * 100
            pp.overtime = Decimal(str(overtime))
        else:
            pp.overtime = None
        
        pp.display_current = discounted_price
        pp.active_promo = active_promo
        
        html = render_to_string(
            "admin_side/price_row.html", 
            {'row': pp, 'today': str(today)}, 
            request
        )
    except PropertyPrice.DoesNotExist:
        estate = Estate.objects.select_related().get(id=estate_id)
        unit = PlotSizeUnits.objects.select_related('plot_size').get(id=unit_id)
        
        # Check for active promo even for non-existent price
        active_promo = PromotionalOffer.objects.filter(
            estates__id=estate_id,
            start__lte=today,
            end__gte=today
        ).first()
        
        class DummyPrice:
            def __init__(self, estate, unit, active_promo):
                self.estate = estate
                self.plot_unit = unit
                self.id = None
                self.presale = None
                self.previous = None
                self.current = None
                self.percent_change = None
                self.overtime = None
                self.display_current = None
                self.effective = None
                self.notes = None
                self.active_promo = active_promo
                
        html = render_to_string(
            "admin_side/price_row.html", 
            {'row': DummyPrice(estate, unit, active_promo), 'today': str(today)}, 
            request
        )
    
    return JsonResponse({'html': html})

@login_required
@require_GET
def property_price_prefill(request):
    estate_id = request.GET.get('estate')
    plot_unit_id = request.GET.get('plot_unit')
    try:
        pp = PropertyPrice.objects.get(estate_id=estate_id, plot_unit_id=plot_unit_id)
        return JsonResponse({
            'exists': True,
            'presale': str(pp.presale),
            'previous': str(pp.previous),
            'current': str(pp.current),
            'effective': pp.effective.isoformat(),
            'notes': pp.notes,
        })
    except PropertyPrice.DoesNotExist:
        return JsonResponse({'exists': False})

# Add to imports
from django.utils.dateparse import parse_date as django_parse_date
from decimal import Decimal

@login_required
@user_passes_test(is_admin)
@require_GET
def property_price_history(request, pk):
    pp = get_object_or_404(PropertyPrice, pk=pk)
    history = []

    # Build real history from PriceHistory records
    for h in pp.history.order_by('effective'):
        history.append({
            "presale": float(h.presale),
            "previous": float(h.previous),
            "current": float(h.current),
            "effective": h.effective.isoformat(),
            "notes": h.notes or "",
            "is_promo": False  # Mark as real price record
        })

    # Get ALL promos for this estate (active and expired)
    promos = PromotionalOffer.objects.filter(estates=pp.estate).order_by('start')
    
    # Create list to track promo injection points
    promo_events = []
    
    # For each promo, create start and end events
    for promo in promos:
        # Find base price at promo start
        base_price = None
        for h in history:
            if django_parse_date(h['effective']) <= promo.start:
                base_price = h['current']
        
        if base_price is None:
            continue
            
        # Calculate discounted price
        discounted = base_price * (100 - promo.discount) / 100
        discounted = round(discounted, 2)
        
        # Add promo start event
        promo_events.append({
            "effective": promo.start.isoformat(),
            "current": discounted,
            "previous": base_price,
            "presale": float(pp.presale),
            "notes": f"PROMO START: {promo.name} ({promo.discount}% OFF)",
            "is_promo": True
        })
        
        # Add promo end event
        promo_events.append({
            "effective": promo.end.isoformat(),
            "current": base_price,  # Revert to base price
            "previous": discounted,
            "presale": float(pp.presale),
            "notes": f"PROMO END: {promo.name} expired",
            "is_promo": True
        })
    
    # Combine real history with promo events
    combined_history = history + promo_events
    combined_history.sort(key=lambda x: x['effective'])
    
    # Calculate price changes
    if combined_history:
        initial = combined_history[0]
        latest = combined_history[-1]
        presale_val = Decimal(initial["presale"])
        latest_val = Decimal(latest["current"])
        
        # Find previous price (skip promo events for change calculation)
        prev_record = None
        for record in reversed(combined_history):
            if not record['is_promo']:
                prev_record = record
                break
        
        prev_val = Decimal(prev_record["current"]) if prev_record else presale_val
        
        current_change = float((latest_val - prev_val) / prev_val * 100) if prev_val > 0 else 0.0
        total_change = float((latest_val - presale_val) / presale_val * 100) if presale_val > 0 else 0.0
    else:
        current_change = 0.0
        total_change = 0.0

    return JsonResponse({
        "history": combined_history,
        "current_change": round(current_change, 2),
        "total_change": round(total_change, 2),
        "has_promos": len(promos) > 0
    })


@csrf_exempt
@login_required
@user_passes_test(is_admin)
@require_http_methods(["POST"])
@csrf_exempt
@login_required
@user_passes_test(is_admin)
@require_http_methods(["POST"])
def promo_create(request):
    try:
        data = json.loads(request.body)

        name = data.get("name", "").strip()
        discount = float(data.get("discount", 0))
        start = parse_date(data.get("start"))
        end = parse_date(data.get("end"))
        description = data.get("description", "")
        estate_ids = data.get("estates", [])

        if not name or not start or not end or not estate_ids:
            return JsonResponse({"status": "error", "message": "Missing required fields."}, status=400)

        promo = PromotionalOffer.objects.create(
            name=name, discount=discount,
            start=start, end=end, description=description
        )
        promo.estates.set(Estate.objects.filter(id__in=estate_ids))

        return JsonResponse({
            "status": "ok",
            "id": promo.id,
            "discount": promo.discount,
            "start": promo.start.isoformat(),
            "end": promo.end.isoformat(),
        })

    except Exception as e:
        return JsonResponse({"status": "error", "message": str(e)}, status=500)

@csrf_exempt
@login_required
@user_passes_test(is_admin)
@require_http_methods(["PUT"])
def promo_update(request, promo_id):
    try:
        data = json.loads(request.body)
        promo = get_object_or_404(PromotionalOffer, id=promo_id)

        promo.name = data.get("name", promo.name).strip()
        promo.discount = float(data.get("discount", promo.discount))
        promo.start = parse_date(data.get("start")) or promo.start
        promo.end = parse_date(data.get("end")) or promo.end
        promo.description = data.get("description", promo.description)
        estate_ids = data.get("estates", [])

        if not promo.name or not promo.start or not promo.end or not estate_ids:
            return JsonResponse({"status": "error", "message": "Missing required fields."}, status=400)

        promo.save()
        promo.estates.set(Estate.objects.filter(id__in=estate_ids))

        return JsonResponse({
            "status": "ok",
            "id": promo.id,
            "discount": promo.discount,
            "start": promo.start.isoformat(),
            "end": promo.end.isoformat(),
        })

    except Exception as e:
        return JsonResponse({"status": "error", "message": str(e)}, status=500)

@require_GET
@login_required
@user_passes_test(is_admin)
def get_active_promo_for_estate(request, estate_id):
    try:
        # Only return promo that is still active
        promo = PromotionalOffer.objects.filter(
            estates__id=estate_id,
            start__lte=now(),
            end__gte=now()
        ).order_by('-start').first()

        if not promo:
            return JsonResponse({'status': 'no_active_promo'})

        return JsonResponse({
            'status': 'ok',
            'data': {
                'name': promo.name,
                'discount': promo.discount,
                'start': promo.start.isoformat(),
                'end': promo.end.isoformat(),
                'description': promo.description,
            }
        })

    except PromotionalOffer.DoesNotExist:
        return JsonResponse({'status': 'no_active_promo'})


# # MANAGEMENT NOTIFICATIONS

@csrf_exempt
def notify_clients_marketer(request):
    if request.method != 'POST':
        return JsonResponse({'status':'error','message':'Invalid request method'}, status=405)

    try:
        data = json.loads(request.body)
        subject     = data['subject']
        message     = data['message']
        notify_type = data['type']
        estate_ids  = data.get('estate_ids', [])
        send_inapp  = data.get('send_inapp', False)

        User = get_user_model()
        
        if notify_type == 'client_update':
            users     = User.objects.filter(role='client')
            ntype     = Notification.CLIENT_ANNOUNCEMENT
        elif notify_type == 'marketer_update':
            users     = User.objects.filter(role='marketer')
            ntype     = Notification.MARKETER_ANNOUNCEMENT
        elif notify_type == 'general_notification':
            users     = User.objects.exclude(role='admin')
            ntype     = Notification.ANNOUNCEMENT
        else:
            users     = User.objects.filter(estate__id__in=estate_ids).distinct()
            ntype     = Notification.ANNOUNCEMENT

        recipients = list(dict.fromkeys(users.values_list('id', flat=True)))

        # create one Notification record
        notif = Notification.objects.create(
            title=subject,
            message=message,
            notification_type=ntype
        )

        dispatched = False
        dispatch_payload = None
        if send_inapp and recipients:
            total_recipients = len(recipients)
            total_batches = ceil(total_recipients / BATCH_SIZE) if total_recipients else 0
            dispatch = NotificationDispatch.objects.create(
                notification=notif,
                total_recipients=total_recipients,
                total_batches=total_batches,
            )

            celery_ready = is_celery_worker_available(timeout=2.0)

            if celery_ready:
                try:
                    dispatch_notification_stream.delay(dispatch.id, notif.id, recipients)
                except Exception as exc:
                    logger.warning(
                        "Falling back to synchronous notification dispatch (dispatch_id=%s): %s",
                        dispatch.id,
                        exc,
                        exc_info=True,
                    )
                    try:
                        dispatch_notification_stream_sync(dispatch.id, notif.id, recipients)
                    except Exception:
                        dispatch.refresh_from_db()
                        raise
                    else:
                        dispatch.refresh_from_db()
                else:
                    dispatched = True
            else:
                logger.info(
                    "Celery worker unavailable within timeout; running synchronous dispatch (dispatch_id=%s)",
                    dispatch.id,
                )
                try:
                    dispatch_notification_stream_sync(dispatch.id, notif.id, recipients)
                except Exception:
                    dispatch.refresh_from_db()
                    raise
                else:
                    dispatch.refresh_from_db()

            dispatch_payload = dispatch.as_dict()

        response_status = 'queued' if dispatched else 'success'

        return JsonResponse({
            'status': response_status,
            'recipients': len(recipients),
            'notification_id': notif.id,
            'dispatched': dispatched,
            'dispatch': dispatch_payload,
            'queue_message': None if dispatched else 'No queue',
        })

    except Exception as exc:
        logger.exception("Failed to dispatch notification", exc_info=exc)
        return JsonResponse(
            {
                'status': 'error',
                'message': 'Failed to dispatch notification.',
                'detail': str(exc),
            },
            status=500,
        )

    except Exception as e:
        return JsonResponse({'status':'error','message':str(e)}, status=400)


@login_required
@require_GET
def notification_dispatch_status(request, dispatch_id: int):
    try:
        dispatch = NotificationDispatch.objects.get(pk=dispatch_id)
    except NotificationDispatch.DoesNotExist:
        return JsonResponse({'ok': False, 'error': 'Dispatch not found'}, status=404)

    return JsonResponse({'ok': True, 'dispatch': dispatch.as_dict()})


@login_required
@login_required
def notifications_all(request):
    qs     = request.user.notifications.select_related('notification').order_by('-notification__created_at')
    unread = qs.filter(read=False)
    read   = qs.filter(read=True)
    tpl    = f"{request.user.role}_side/notification.html"
    return render(request, tpl, {'unread_list': unread, 'read_list': read})

@login_required
def notification_detail(request, un_id):
    un = get_object_or_404(UserNotification, pk=un_id, user=request.user)
    if not un.read:
        un.read = True
        un.save(update_fields=['read'])
    return render(
        request,
        f"{request.user.role}_side/notification_detail.html",
        {'notification': un.notification,
         'back_url': 'notifications_all'}
    )

@login_required
def mark_notification_read(request, un_id):
    un = get_object_or_404(UserNotification, pk=un_id, user=request.user)
    un.read = True
    un.save(update_fields=['read'])
    return redirect('notification_detail', un_id=un.id)


@login_required
@user_passes_test(is_admin)
@require_GET
def property_price_detail(request, pk):
    """
    Returns JSON detail of a PropertyPrice including an active promo adjustment.
    """
    pp = get_object_or_404(PropertyPrice, pk=pk)
    today = now().date()

    promo = PromotionalOffer.objects.filter(
        estates=pp.estate,
        start__lte=today,
        end__gte=today
    ).order_by('-discount').first()

    original = pp.current
    adjusted = original
    if promo:
        adjusted = (original * (Decimal(100) - promo.discount) / Decimal(100)).quantize(Decimal('0.01'))

    return JsonResponse({
        "id": pp.id,
        "estate":    {"id": pp.estate.id, "name": pp.estate.name},
        "plot_unit": {"id": pp.plot_unit.id, "size": pp.plot_unit.plot_size.size},
        "presale":   str(pp.presale),
        "previous":  str(pp.previous),
        "current":   str(adjusted),
        "original":  str(original),
        "promo_applied":  bool(promo),
        "promo_discount": promo.discount if promo else 0,
        "promo_name":     promo.name if promo else "",
        "promo_expires":  promo.end.isoformat() if promo else None,
        "effective": pp.effective.isoformat(),
        "notes":     pp.notes,
    })



# MESSAGING AND BIRTHDAY.

