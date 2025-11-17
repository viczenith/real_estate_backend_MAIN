"""
WSGI config for estateProject project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/4.2/howto/deployment/wsgi/
"""

import os
import sys
from pathlib import Path

from django.core.wsgi import get_wsgi_application

# Add the project directory to the Python path
BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.append(str(BASE_DIR))

# Use production settings by default
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings.production')

# This application object is used by the development server and any WSGI server
application = get_wsgi_application()
