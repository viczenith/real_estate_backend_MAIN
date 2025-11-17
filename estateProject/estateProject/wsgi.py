"""
WSGI config for estateProject project.

It exposes the WSGI callable as a module-level variable named ``application``.
"""

import os
import sys
from pathlib import Path

# Calculate paths
BASE_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# Add the project directory to the Python path
for path in [str(BASE_DIR), str(PROJECT_ROOT)]:
    if path not in sys.path:
        print(f"Adding to path: {path}")
        sys.path.insert(0, path)

# Print current Python path and working directory for debugging
print("=" * 50)
print(f"Current working directory: {os.getcwd()}")
print(f"BASE_DIR: {BASE_DIR}")
print(f"PROJECT_ROOT: {PROJECT_ROOT}")
print("Python path:", sys.path)
print("=" * 50)

# Set the Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings')

# Initialize Django application
print("Initializing Django application...")
try:
    from django.core.wsgi import get_wsgi_application
    application = get_wsgi_application()
    print("Django application initialized successfully")
except Exception as e:
    print(f"Error initializing Django application: {str(e)}")
    raise
