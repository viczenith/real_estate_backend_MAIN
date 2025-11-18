"""
WSGI config for estateProject project.

It exposes the WSGI callable as a module-level variable named ``application``.
"""

import os
import sys
from pathlib import Path

# Calculate paths
BASE_DIR = Path(__file__).resolve().parent.parent

# Add the project directory to the Python path
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

# Set the Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings')

# Print debug information
print("=" * 50)
print(f"Current working directory: {os.getcwd()}")
print(f"BASE_DIR: {BASE_DIR}")
print("Python path:", sys.path)

# Check for required packages
try:
    import dj_database_url
    print(f"dj-database-url found at: {dj_database_url.__file__}")
except ImportError as e:
    print(f"ERROR: dj-database-url not found: {e}")
    print("Attempting to install required packages...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "dj-database-url==3.0.1", "python-dotenv==1.0.0"])
    import dj_database_url
    print(f"Successfully installed dj-database-url at: {dj_database_url.__file__}")

print("=" * 50)

# Initialize Django application
print("Initializing Django application...")
try:
    import django
    django.setup()
    from django.core.wsgi import get_wsgi_application
    application = get_wsgi_application()
    print("Django application initialized successfully")
except Exception as e:
    print(f"Error initializing Django application: {str(e)}")
    import traceback
    traceback.print_exc()
    raise
