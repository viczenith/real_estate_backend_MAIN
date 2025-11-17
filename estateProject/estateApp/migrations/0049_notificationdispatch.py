from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("estateApp", "0048_userdevicetoken"),
    ]

    operations = [
        migrations.CreateModel(
            name="NotificationDispatch",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("total_recipients", models.PositiveIntegerField(default=0)),
                ("processed_recipients", models.PositiveIntegerField(default=0)),
                ("total_batches", models.PositiveIntegerField(default=0)),
                ("processed_batches", models.PositiveIntegerField(default=0)),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("queued", "Queued"),
                            ("processing", "Processing"),
                            ("completed", "Completed"),
                            ("failed", "Failed"),
                        ],
                        default="queued",
                        max_length=20,
                    ),
                ),
                ("last_error", models.TextField(blank=True)),
                ("started_at", models.DateTimeField(blank=True, null=True)),
                ("finished_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "notification",
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name="dispatches",
                        to="estateApp.notification",
                    ),
                ),
            ],
            options={"ordering": ["-created_at"]},
        ),
    ]
