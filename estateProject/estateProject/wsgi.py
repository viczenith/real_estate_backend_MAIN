"""
WSGI config for estateProject project.

It exposes the WSGI callable as a module-level variable named ``application``.
"""

import os
import sys
from pathlib import Path

# Calculate the base directory (two levels up from wsgi.py)
BASE_DIR = Path(__file__).resolve().parent.parent

# Add the project directory to the Python path
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

# Set the Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings')

# Initialize Django application
from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
