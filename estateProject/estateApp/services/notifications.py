from estateApp.models import *
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives
# from celery import shared_task
from django.conf import settings
from django.contrib.contenttypes.models import ContentType

class NotificationService:
    TEMPLATE_MAP = {
        'PAYMENT': 'payment.html',
        'ALLOCATION': 'allocation.html',
        'ANNOUNCEMENT': 'announcement.html',
        'REMINDER': 'reminder.html'
    }

    @classmethod
    def create_notification(cls, user, notification_type, title, message, related_object=None):
        notification = Notification.objects.create(
            user=user,
            notification_type=notification_type,
            title=title,
            message=message,
            content_type=ContentType.objects.get_for_model(related_object),
            object_id=related_object.id if related_object else None
        )
        cls.send_notification_email.delay(notification.id)
        return notification

    # @staticmethod
    # @shared_task
    # def send_notification_email(notification_id):
    #     notification = Notification.objects.get(id=notification_id)
    #     context = {
    #         'user': notification.user,
    #         'message': notification.message,
    #         'site_url': settings.SITE_URL,
    #         'related_object': notification.related_object,
    #         'unsubscribe_url': f"{settings.SITE_URL}/notifications/unsubscribe/"
    #     }

    #     template = cls.TEMPLATE_MAP.get(
    #         notification.notification_type, 
    #         'announcement.html'
    #     )

    #     html_content = render_to_string(
    #         f'notifications/emails/{template}',
    #         context
    #     )

    #     email = EmailMultiAlternatives(
    #         subject=f"REMS: {notification.title}",
    #         body=strip_tags(html_content),
    #         from_email=settings.DEFAULT_FROM_EMAIL,
    #         to=[notification.user.email]
    #     )
    #     email.attach_alternative(html_content, "text/html")
    #     email.send()


