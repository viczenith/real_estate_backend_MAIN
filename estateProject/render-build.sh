#!/usr/bin/env bash
# Build script for Render.com Python services
set -o errexit
set -o pipefail
set -o nounset

# Install runtime dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Collect static assets for WhiteNoise
python manage.py collectstatic --noinput
