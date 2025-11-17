"""
Management command to permanently delete users that have been soft-deleted for more than 30 days.
Run this command via cron job or task scheduler:
    python manage.py delete_expired_users
"""

from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from estateApp.models import CustomUser


class Command(BaseCommand):
    help = 'Permanently delete users (clients and marketers) that have been soft-deleted for more than 30 days'

    def add_arguments(self, parser):
        parser.add_argument(
            '--days',
            type=int,
            default=30,
            help='Number of days after which to permanently delete soft-deleted users (default: 30)',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be deleted without actually deleting',
        )

    def handle(self, *args, **options):
        days = options['days']
        dry_run = options['dry_run']
        
        # Calculate the cutoff date
        cutoff_date = timezone.now() - timedelta(days=days)
        
        # Find users that have been deleted for more than the specified days
        expired_users = CustomUser.objects.filter(
            is_deleted=True,
            deleted_at__lte=cutoff_date
        ).exclude(role='admin')  # Never auto-delete admins
        
        count = expired_users.count()
        
        if count == 0:
            self.stdout.write(self.style.SUCCESS('No expired users found.'))
            return
        
        if dry_run:
            self.stdout.write(self.style.WARNING(f'DRY RUN: Would permanently delete {count} user(s):'))
            for user in expired_users:
                self.stdout.write(
                    f'  - {user.full_name} ({user.role}) - Deleted on {user.deleted_at.strftime("%Y-%m-%d")}'
                )
        else:
            # Log the users being deleted
            self.stdout.write(self.style.WARNING(f'Permanently deleting {count} user(s)...'))
            for user in expired_users:
                self.stdout.write(
                    f'  - Deleting: {user.full_name} ({user.role}) - Deleted on {user.deleted_at.strftime("%Y-%m-%d")}'
                )
            
            # Permanently delete the users
            expired_users.delete()
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully deleted {count} user(s) that were soft-deleted more than {days} days ago.'
                )
            )
