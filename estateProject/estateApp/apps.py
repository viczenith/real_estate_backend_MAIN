from django.apps import AppConfig


class EstateAppConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'estateApp'

    def ready(self):
        # Import and connect signals
        import estateApp.signals