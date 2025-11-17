from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import *
from django.utils import timezone


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ('company_name', 'registration_number', 'ceo_name', 'email', 'phone', 'location', 'is_active', 'created_at')
    list_filter = ('is_active', 'registration_date', 'created_at')
    search_fields = ('company_name', 'registration_number', 'ceo_name', 'email', 'phone', 'location')
    ordering = ('-created_at',)
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Company Information', {
            'fields': ('company_name', 'registration_number', 'registration_date', 'location', 'logo')
        }),
        ('CEO Information', {
            'fields': ('ceo_name', 'ceo_dob')
        }),
        ('Contact Information', {
            'fields': ('email', 'phone')
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )


@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    list_display = ('full_name', 'email', 'phone', 'role', 'date_registered', 'company', 'job', 'country')
    list_filter = ('role', 'date_registered', 'is_active', 'is_staff')
    search_fields = ('full_name', 'email', 'phone', 'company', 'job', 'country')
    ordering = ('date_registered',)

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'address', 'phone', 'date_of_birth', 'about', 'company', 'job', 'country', 'profile_image')}),
        ('Permissions and Role', {'fields': ('role', 'is_staff', 'is_active', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_registered')}),
        # ('Marketer Info', {'fields': ('marketer',)}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'password1', 'password2', 'full_name', 'role')
        }),
    )


@admin.register(AdminUser)
class AdminUserAdmin(CustomUserAdmin):
    list_display = ('full_name', 'email', 'phone', 'date_registered')
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'address', 'phone', 'date_of_birth', 'about', 'company', 'job', 'country', 'profile_image')}),
        ('Permissions', {'fields': ('is_staff', 'is_active', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_registered')}),
    )


@admin.register(ClientUser)
class ClientUserAdmin(CustomUserAdmin):
    list_display = ('full_name', 'email', 'phone', 'assigned_marketer', 'date_registered', 'about', 'company', 'job', 'country', 'profile_image')

    def assigned_marketer(self, obj):
        return obj.marketer.full_name if obj.marketer else "Not Assigned"
    assigned_marketer.short_description = "Assigned Marketer"

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'address', 'phone', 'date_of_birth', 'about', 'company', 'job', 'country', 'profile_image')}),
        # ('Marketer Info', {'fields': ('marketer',)}),
        ('Marketer Info', {'fields': ('assigned_marketer',)}),
        ('Permissions', {'fields': ('is_staff', 'is_active', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_registered')}),
    )


@admin.register(MarketerUser)
class MarketerUserAdmin(CustomUserAdmin):
    list_display = ('full_name', 'email', 'phone', 'date_registered', 'about', 'company', 'job', 'country', 'profile_image')

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'address', 'phone', 'date_of_birth', 'about', 'company', 'job', 'country', 'profile_image')}),
        ('Permissions', {'fields': ('is_staff', 'is_active', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_registered')}),
    )


@admin.register(SupportUser)
class SupportUserAdmin(CustomUserAdmin):
    list_display = ('full_name', 'email', 'phone', 'date_registered', 'about', 'company', 'job', 'country', 'profile_image')

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'address', 'phone', 'date_of_birth', 'about', 'company', 'job', 'country', 'profile_image')}),
        ('Permissions', {'fields': ('is_staff', 'is_active', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_registered')}),
    )


class MessageAdmin(admin.ModelAdmin):
    list_display = ('sender', 'recipient', 'message_type', 'content', 'date_sent')
    search_fields = ('sender__username', 'recipient__username', 'message_type')
    list_filter = ('message_type', 'date_sent')

    def save_model(self, request, obj, form, change):
        if obj.reply:
            obj.date_replied = timezone.now()
        super().save_model(request, obj, form, change)

admin.site.register(Message, MessageAdmin)



# ADD ESTATE

@admin.register(PlotSize)
class PlotSizeAdmin(admin.ModelAdmin):
    list_display = ("size",)
    search_fields = ("size",)

@admin.register(PlotNumber)
class PlotNumberAdmin(admin.ModelAdmin):
    list_display = ("number",)
    search_fields = ("number",)


# class EstatePlotInline(admin.TabularInline):
#     model = EstatePlot
#     extra = 1 
#     fields = ['estate', 'plot_numbers']
    # filter_horizontal = ('plot_sizes', 'plot_numbers')

@admin.register(Estate)
class EstateAdmin(admin.ModelAdmin):
    list_display = ("name", "location", "estate_size", "title_deed", "date_added")
    search_fields = ("name", "location")
    list_filter = ("title_deed", "date_added")
    ordering = ("-date_added",)
    # inlines = [EstatePlotInline]

# @admin.register(EstatePlot)
# class EstatePlotAdmin(admin.ModelAdmin):
#     list_display = ("estate", "plot_sizes", "plot_numbers")
    # list_filter = ("estate",)
    # search_fields = ("estate__name",)
    # filter_horizontal = ( "plot_numbers")

# Register the intermediate model
@admin.register(PlotSizeUnits)
class PlotSizeUnitsAdmin(admin.ModelAdmin):
    list_display = ['estate_plot', 'plot_size', 'total_units', 'available_units']
    list_filter = ['estate_plot__estate', 'plot_size']
    search_fields = ['estate_plot__estate__name', 'plot_size__size']

class PlotSizeUnitsInline(admin.TabularInline):
    model = PlotSizeUnits
    extra = 1  # Number of empty forms to display

@admin.register(EstatePlot)
class EstatePlotAdmin(admin.ModelAdmin):
    inlines = [PlotSizeUnitsInline]
    list_display = ['estate', 'get_plot_sizes', 'get_plot_numbers']
    filter_horizontal = ('plot_numbers',)

    def get_plot_sizes(self, obj):
        return ", ".join([size.size for size in obj.plot_sizes.all()])
    get_plot_sizes.short_description = "Plot Sizes"

    def get_plot_numbers(self, obj):
        return ", ".join([num.number for num in obj.plot_numbers.all()])
    get_plot_numbers.short_description = "Plot Numbers"


# admin.site.register(PlotAllocation)
# @admin.register(PlotAllocation)
# class PlotAllocationAdmin(admin.ModelAdmin):
#     list_display = ('client', 'estate', 'plot_size', 'plot_number', 'payment_type', 'date_allocated')


class PlotSizeUnitsInline(admin.TabularInline):
    model = PlotSizeUnits
    extra = 1
    readonly_fields = ('available_units',)

class PlotAllocationAdmin(admin.ModelAdmin):
    list_display = ('client', 'get_plot_size', 'payment_type', 'date_allocated')
    list_filter = ('plot_size_unit__plot_size', 'payment_type')
    
    def get_plot_size(self, obj):
        return obj.plot_size_unit.plot_size.size
    get_plot_size.short_description = 'Plot Size'

admin.site.register(PlotAllocation, PlotAllocationAdmin)


admin.site.register(EstatePrototype)
admin.site.register(EstateAmenitie)
admin.site.register(EstateFloorPlan)


# MANAGEMENT DASHBOARD
# Land Plot Transactions
admin.site.register(Transaction)
admin.site.register(PaymentRecord)

# Sales Volume + Marketers Performance
admin.site.register(MarketerCommission)
admin.site.register(MarketerTarget)
admin.site.register(MarketerPerformanceRecord)

# VALUE EVALUATION
admin.site.register(PropertyPrice)
admin.site.register(PriceHistory)
admin.site.register(PromotionalOffer)


# MESSAGING AND BIRTHDAY.


