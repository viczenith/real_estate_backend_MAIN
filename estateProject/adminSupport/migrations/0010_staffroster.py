from django.db import migrations, models
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ('adminSupport', '0009_contactinfo_crmsettings_diasporaoffer_holiday_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='StaffRoster',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('created_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='staff_roster_created', to=settings.AUTH_USER_MODEL)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='staff_roster', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Staff Roster Entry',
                'verbose_name_plural': 'Staff Roster',
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='staffroster',
            index=models.Index(fields=['active'], name='staffroster_active_idx'),
        ),
    ]
