from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from estateApp.models import BirthdayPreference, ALLOWED_ROLES_FOR_PREF

User = get_user_model()

class Command(BaseCommand):
    help = "Create BirthdayPreference records for existing client/marketer users"

    def handle(self, *args, **kwargs):
        created = 0
        removed = 0
        for u in User.objects.filter(role__in=ALLOWED_ROLES_FOR_PREF):
            obj, was_created = BirthdayPreference.objects.get_or_create(user=u)
            if was_created:
                created += 1
        for pref in BirthdayPreference.objects.exclude(user__role__in=ALLOWED_ROLES_FOR_PREF):
            pref.delete()
            removed += 1
        self.stdout.write(self.style.SUCCESS(f"Created {created} prefs, removed {removed} invalid prefs."))
