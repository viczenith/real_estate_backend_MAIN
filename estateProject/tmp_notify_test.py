import os
import json

import django


def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings')
    django.setup()

    from django.test import RequestFactory
    from django.contrib.auth import get_user_model
    from estateApp.views import notify_clients_marketer

    User = get_user_model()
    user = User.objects.filter(role='admin').first() or User.objects.first()
    if user is None:
        raise SystemExit('No users available to attach to request')

    rf = RequestFactory()
    body = json.dumps({
        'subject': 'Test subject',
        'message': 'Hello from script',
        'type': 'client_update',
        'send_inapp': False,
    })
    request = rf.post('/api/notify-clients-marketer/', data=body, content_type='application/json')
    request.user = user
    response = notify_clients_marketer(request)
    print('status:', response.status_code)
    print('body:', response.content.decode())


if __name__ == '__main__':
    main()
