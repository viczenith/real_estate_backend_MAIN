import os
import logging

try:
    from celery import Celery
    from celery.schedules import crontab  # noqa: F401  (kept for existing beat configs)
except ModuleNotFoundError:  # pragma: no cover
    Celery = None  # type: ignore

logger = logging.getLogger(__name__)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "estateProject.settings")


if Celery is not None:
    app = Celery("estateProject")
    app.config_from_object("django.conf:settings", namespace="CELERY")
    app.autodiscover_tasks()

    @app.task(bind=True)
    def debug_task(self):
        print(f"Request: {self.request!r}")
else:
    app = None
    logger.warning(
        "Celery is not installed; background tasks will run synchronously if invoked in-process"
    )
