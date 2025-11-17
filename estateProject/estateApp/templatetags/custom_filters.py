from django import template
from django.utils import timezone
from datetime import timedelta
import os
register = template.Library()

@register.filter
def get_item(dictionary, key):
    return dictionary.get(key)




@register.filter
def is_allocated_in_estate(number, estate_id):
    if hasattr(number, 'allocated_estate_id'):
        return number.allocated_estate_id == estate_id
    return False


@register.filter
def endswith(value, arg):
    if isinstance(value, str):
        return value.endswith(arg)
    return False


@register.filter
def filename(value):
    if not value:
        return ''
    # Ensure robust handling of both POSIX and Windows-style paths
    return os.path.basename(str(value))


@register.filter
def sub(value, arg):
    return value - arg


@register.filter
def within_minutes(value, minutes=30):
    try:
        dt = timezone.make_aware(value) if timezone.is_naive(value) else value
    except Exception:
        return False
    return timezone.now() - dt <= timedelta(minutes=minutes)


@register.filter
def isoformat(value):
    try:
        return value.isoformat()
    except Exception:
        return ""
