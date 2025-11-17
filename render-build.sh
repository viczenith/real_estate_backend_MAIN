#!/usr/bin/env bash
# Build script for Render.com Python services
set -o errexit
set -o pipefail
set -o nounset

echo "=== Starting build process ==="

# Debug: Show environment and directory info
echo "=== Environment Variables ==="
printenv | sort
echo ""

# Navigate to the project root if needed
if [ -d "estateProject" ]; then
    cd estateProject
    echo "=== Changed to project directory: $(pwd) ==="
fi

echo "=== Current Directory ==="
echo "Working directory: $(pwd)"
echo ""

echo "=== Directory Contents ==="
ls -la

# Ensure we're in the correct directory
if [ ! -f "manage.py" ]; then
    echo "=== ERROR: manage.py not found in $(pwd)"
    echo "=== Current directory contents:"
    ls -la
    echo "=== Searching for manage.py in subdirectories:"
    find . -name "manage.py" -type f
    exit 1
fi

# Install Python dependencies
echo -e "\n=== Installing Python dependencies ==="
python -m pip install --upgrade pip
pip install -r requirements.txt

# Install additional required packages
echo -e "\n=== Installing additional packages ==="
pip install gunicorn whitenoise

# Verify Python path
echo -e "\n=== Python Path ==="
python -c "import sys; print('\n'.join(sys.path))"

# Apply database migrations
echo -e "\n=== Applying database migrations ==="
python manage.py migrate --noinput

# Collect static files
echo -e "\n=== Collecting static files ==="
python manage.py collectstatic --noinput

# Verify Django installation
echo -e "\n=== Verifying Django installation ==="
python -c "import django; print(f'Django version: {django.get_version()}')"

# Check for wsgi.py in the correct location
WSGI_PATH="estateProject/wsgi.py"
echo -e "\n=== Checking for wsgi.py ==="
if [ -f "$WSGI_PATH" ]; then
    echo "Found wsgi.py at: $(pwd)/$WSGI_PATH"
    echo "=== wsgi.py contents ==="
    head -n 20 "$WSGI_PATH"
else
    echo "=== ERROR: Could not find $WSGI_PATH"
    echo "=== Current directory: $(pwd)"
    echo "=== Searching for wsgi.py in subdirectories:"
    find . -name "wsgi.py" -type f
    exit 1
fi

# Final directory structure
echo -e "\n=== Final directory structure ==="
find . -type d | sort

echo -e "\n=== Build completed successfully ==="
