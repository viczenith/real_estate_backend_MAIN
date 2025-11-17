"""
WSGI config for estateProject project.

It exposes the WSGI callable as a module-level variable named ``application``.
"""

import os
import sys
from pathlib import Path

# Calculate paths
BASE_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BASE_DIR / 'estateProject'

# Add the project directory to the Python path
sys.path.append(str(BASE_DIR))
sys.path.append(str(PROJECT_ROOT))

# Set the Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings')

# Initialize Django application
from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
