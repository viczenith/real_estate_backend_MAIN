from django import forms
from django.contrib.auth.forms import AuthenticationForm
from django.core.exceptions import ValidationError
from django.contrib.auth.models import User
from .models import *


class CustomAuthenticationForm(AuthenticationForm):
    username = forms.EmailField(
        widget=forms.EmailInput(attrs={'autofocus': True, 'placeholder': 'Enter your email'}),
        label="Email",
        required=True
    )
    

# ESTATE ADD VIEW FORM

class EstateForm(forms.ModelForm):
    class Meta:
        model = Estate
        fields = ['name', 'location', 'estate_size', 'title_deed']

class EstatePlotForm(forms.ModelForm):
    plot_sizes = forms.ModelMultipleChoiceField(
        queryset=PlotSize.objects.all(),
        widget=forms.CheckboxSelectMultiple,
        required=False
    )
    plot_numbers = forms.ModelMultipleChoiceField(
        queryset=PlotNumber.objects.all(),
        widget=forms.CheckboxSelectMultiple,
        required=False
    )

    class Meta:
        model = EstatePlot
        fields = ['estate', 'plot_sizes', 'plot_numbers']



class EstateFloorPlanForm(forms.ModelForm):
    class Meta:
        model = EstateFloorPlan
        fields = ['estate', 'plot_size', 'floor_plan_image', 'plan_title']

# amenities
class AmenitieForm(forms.ModelForm):
    class Meta:
        model = EstateAmenitie
        fields = ['amenities']
        widgets = {
            'amenities': forms.CheckboxSelectMultiple,
        }


# NOTIFICATIONS
class NotificationForm(forms.ModelForm):
    class Meta:
        model = Notification
        fields = ['notification_type', 'title', 'message']
        widgets = {
            'notification_type': forms.Select(attrs={'class': 'form-select'}),
            'title': forms.TextInput(attrs={'class': 'form-control'}),
            'message': forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
        }
        labels = {
            'notification_type': 'Announcement Type',
            'title': 'Title',
            'message': 'Message',
        }

# class EstateValueRegulationForm(forms.ModelForm):
#     class Meta:
#         model = EstateValueRegulation
#         fields = ['estate', 'plot_size', 'current_price', 'effective_date', 'notes']
#         widgets = {
#             'effective_date': forms.DateInput(attrs={'type': 'date'}),
#         }



# COMPANY PROFILE EDIT FORM
class CompanyForm(forms.ModelForm):
    class Meta:
        model = Company
        fields = [
            'company_name', 'registration_number', 'registration_date', 'location',
            'ceo_name', 'ceo_dob', 'email', 'phone', 'logo', 'is_active'
        ]
        widgets = {
            'registration_date': forms.DateInput(attrs={'type': 'date', 'class': 'form-control'}),
            'ceo_dob': forms.DateInput(attrs={'type': 'date', 'class': 'form-control'}),
        }

# Optional: inline metrics editor if needed later
class AppMetricsForm(forms.ModelForm):
    class Meta:
        model = AppMetrics
        fields = ['android_downloads', 'ios_downloads']


