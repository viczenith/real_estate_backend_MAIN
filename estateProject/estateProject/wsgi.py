"""
WSGI config for estateProject project.

It exposes the WSGI callable as a module-level variable named ``application``.
"""

import os
import sys
from pathlib import Path

# Calculate paths
BASE_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BASE_DIR.parent

# Add the project directory to the Python path
for path in [str(BASE_DIR), str(PROJECT_ROOT)]:
    if path not in sys.path:
        print(f"Adding to path: {path}")
        sys.path.insert(0, path)

# Print current Python path for debugging
print("Python path:", sys.path)
print("Current working directory:", os.getcwd())

# Set the Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings')

# Initialize Django application
print("Initializing Django application...")
from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
print("Django application initialized successfully")
