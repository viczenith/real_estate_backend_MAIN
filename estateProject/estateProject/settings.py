
# from pathlib import Path
# import os
# import secrets
# import dj_database_url
# from dotenv import load_dotenv

# from django.core.exceptions import ImproperlyConfigured
# from dotenv import load_dotenv

# # Build paths inside the project like this: BASE_DIR / 'subdir'.
# BASE_DIR = Path(__file__).resolve().parent.parent

# load_dotenv(BASE_DIR / '.env')


# # Quick-start development settings - unsuitable for production
# # See https://docs.djangoproject.com/en/5.1/howto/deployment/checklist/

# def get_bool_env(var_name: str, default: bool = False) -> bool:
#     value = os.environ.get(var_name)
#     if value is None:
#         return default
#     return value.lower() in {"1", "true", "t", "yes", "y", "on"}


# # SECURITY WARNING: don't run with debug turned on in production!
# DEBUG = get_bool_env('DEBUG', default=True)

# # SECURITY WARNING: keep the secret key used in production secret!
# SECRET_KEY = os.environ.get('SECRET_KEY')
# if not SECRET_KEY:
#     if DEBUG:
#         secret_file = BASE_DIR / '.secret_key'
#         if secret_file.exists():
#             SECRET_KEY = secret_file.read_text().strip()
#         else:
#             SECRET_KEY = secrets.token_urlsafe(64)
#             secret_file.write_text(SECRET_KEY)
#     else:
#         raise ImproperlyConfigured('SECRET_KEY environment variable is required')



# raw_allowed_hosts = os.environ.get('ALLOWED_HOSTS', '*')
# ALLOWED_HOSTS = [host.strip() for host in raw_allowed_hosts.split(',') if host.strip()]
# if not ALLOWED_HOSTS:
#     ALLOWED_HOSTS = ['*']


# # Application definition

# INSTALLED_APPS = [
#     'django.contrib.admin',
#     'django.contrib.auth',
#     'django.contrib.contenttypes',
#     'django.contrib.sessions',
#     'django.contrib.messages',
#     'django.contrib.staticfiles',
#     'django.contrib.humanize',
#     'channels',
#     'estateApp',
#     'adminSupport',
#     'DRF',
#     'widget_tweaks',
#     'rest_framework',
#     'rest_framework.authtoken',
#     'corsheaders',
# ]

# REST_FRAMEWORK = {
#     'DEFAULT_AUTHENTICATION_CLASSES': (
#         'rest_framework.authentication.SessionAuthentication',
#         'rest_framework.authentication.TokenAuthentication',
#     ),
#     'DEFAULT_PERMISSION_CLASSES': (
#         'rest_framework.permissions.IsAuthenticated',
#     ),
# }

# MIDDLEWARE = [
#     'django.middleware.security.SecurityMiddleware',
#     'whitenoise.middleware.WhiteNoiseMiddleware',
#     'corsheaders.middleware.CorsMiddleware',
#     'django.contrib.sessions.middleware.SessionMiddleware',
#     'django.middleware.common.CommonMiddleware',
#     'django.middleware.csrf.CsrfViewMiddleware',
#     'django.contrib.auth.middleware.AuthenticationMiddleware',
#     'django.contrib.messages.middleware.MessageMiddleware',
#     'django.middleware.clickjacking.XFrameOptionsMiddleware',
# ]

# CORS_ALLOWED_ORIGINS = [
#   "http://localhost:8080",
#   "http://localhost:5601",
#   "http://192.168.110.208:5555",
#   "http://192.168.110.208:8000",
# ]

# CORS_ALLOW_ALL_ORIGINS = True

# ROOT_URLCONF = 'estateProject.urls'

# TEMPLATES = [
#     {
#         'BACKEND': 'django.template.backends.django.DjangoTemplates',
#         'DIRS': [os.path.join(BASE_DIR, 'templates')],
#         'APP_DIRS': True,
#         'OPTIONS': {
#             'context_processors': [
#                 'django.template.context_processors.debug',
#                 'django.template.context_processors.request',
#                 'django.contrib.auth.context_processors.auth',
#                 'django.contrib.messages.context_processors.messages',
#                 'estateApp.context_processors.chat_notifications',
#                 'estateApp.context_processors.user_notifications',
#                 'estateApp.context_processors.dashboard_url',
#             ],
#         },
#     },
# ]

# WSGI_APPLICATION = 'estateProject.wsgi.application'
# ASGI_APPLICATION = 'estateProject.asgi.application'

# CHANNEL_LAYERS = {
#     'default': {
#         'BACKEND': 'channels_redis.core.RedisChannelLayer',
#         'CONFIG': {
#             'hosts': [os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/0')],
#         },
#     }
# }


# # Database
# # https://docs.djangoproject.com/en/5.1/ref/settings/#databases

# # Load environment variables
# load_dotenv()

# # Database configuration
# DATABASES = {
#     'default': dj_database_url.config(
#         default='sqlite:///' + str(BASE_DIR / 'db.sqlite3'),
#         conn_max_age=600,
#         conn_health_checks=True,
#     )
# }

# # For local development, you can uncomment this to use SQLite
# # DATABASES = {
# #     'default': {
# #         'ENGINE': 'django.db.backends.sqlite3',
# #         'NAME': BASE_DIR / 'db.sqlite3',
# #     }
# # }

# # If you need to use the old style PostgreSQL configuration, uncomment and modify this:
# # DATABASES = {
# #     'default': {
# #         'ENGINE': 'django.db.backends.postgresql',
# #         'NAME': os.environ.get('POSTGRES_DB', ''),
# #         'USER': os.environ.get('POSTGRES_USER', ''),
# #         'PASSWORD': os.environ.get('POSTGRES_PASSWORD', ''),
# #         'HOST': os.environ.get('POSTGRES_HOST', '127.0.0.1'),
# #         'PORT': os.environ.get('POSTGRES_PORT', '5432'),
# #     }
# # }


# # Password validation
# # https://docs.djangoproject.com/en/5.1/ref/settings/#auth-password-validators

# AUTH_PASSWORD_VALIDATORS = [
#     {
#         'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
#     },
#     {
#         'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
#     },
#     {
#         'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
#     },
#     {
#         'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
#     },
# ]


# # Internationalization
# # https://docs.djangoproject.com/en/5.1/topics/i18n/

# LANGUAGE_CODE = 'en-us'

# TIME_ZONE = 'UTC'

# USE_I18N = True

# USE_TZ = True


# # Static files (CSS, JavaScript, Images)
# # https://docs.djangoproject.com/en/5.1/howto/static-files/

# STATICFILES_FINDERS = [
#     "django.contrib.staticfiles.finders.FileSystemFinder",
#     "django.contrib.staticfiles.finders.AppDirectoriesFinder",
# ]

# # For production
# STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# STATIC_URL = '/static/'
# STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')


# STATICFILES_DIRS = [
#     os.path.join(BASE_DIR, 'static'),
#     os.path.join(BASE_DIR, 'estateApp', 'static'),
#     os.path.join(BASE_DIR, 'adminSupport', 'static'),
# ]


# MEDIA_URL = '/media/'
# MEDIA_ROOT = os.path.join(BASE_DIR, 'media')


# # Default primary key field type
# # https://docs.djangoproject.com/en/5.1/ref/settings/#default-auto-field

# DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


# AUTH_USER_MODEL = 'estateApp.CustomUser'
# CSRF_FAILURE_VIEW = 'estateApp.views.custom_csrf_failure_view'


# LOGIN_URL = '/login/'
# # LOGIN_REDIRECT_URL = '/dashboard/'
# LOGOUT_REDIRECT_URL = '/login/' 

# SESSION_COOKIE_AGE = 300
# SESSION_EXPIRE_AT_BROWSER_CLOSE = True
# SESSION_SAVE_EVERY_REQUEST = True


# AUTHENTICATION_BACKENDS = (
#     'django.contrib.auth.backends.ModelBackend',
#     'estateApp.backends.EmailBackend',
# )

# from django.contrib.messages import constants as messages

# MESSAGE_TAGS = {
#     messages.ERROR: 'danger',
#     messages.SUCCESS: 'success',
# }

# # Firebase / push notifications 
# FIREBASE_CREDENTIALS_PATH = os.environ.get('FIREBASE_CREDENTIALS_PATH')
# FIREBASE_DEFAULT_ICON = os.environ.get('FIREBASE_DEFAULT_ICON', 'ic_chat_notification')
# FIREBASE_DEFAULT_COLOR = os.environ.get('FIREBASE_DEFAULT_COLOR', '#075E54')
# FIREBASE_DEFAULT_CHANNEL_ID = os.environ.get('FIREBASE_DEFAULT_CHANNEL_ID', 'chat_messages')
# FIREBASE_DEFAULT_SOUND = os.environ.get('FIREBASE_DEFAULT_SOUND', 'default')

# # Redis Configuration
# # In production, set REDIS_URL in your environment variables
# # Example: rediss://default:password@host:port
# REDIS_URL = os.environ['REDIS_URL']  # Required in production

# # Celery settings
# CELERY_BROKER_URL = f"{REDIS_URL}/0"
# CELERY_RESULT_BACKEND = f"{REDIS_URL}/1"
# CELERY_ACCEPT_CONTENT = ['json']
# CELERY_TASK_SERIALIZER = 'json'
# CELERY_RESULT_SERIALIZER = 'json'
# CELERY_TIMEZONE = TIME_ZONE
# CELERY_TASK_DEFAULT_QUEUE = 'default'

# # Redis specific settings
# CELERY_BROKER_TRANSPORT_OPTIONS = {
#     'ssl_cert_reqs': 'CERT_NONE',  # For self-signed certs
#     'retry_on_timeout': True,
#     'socket_keepalive': True,
#     'socket_timeout': 30,
#     'socket_connect_timeout': 30,
# }

# CELERY_TASK_ROUTES = {
#     "estateApp.tasks.dispatch_notification_batch": {"queue": "notifications"},
#     "estateApp.tasks.dispatch_notification_stream": {"queue": "notifications"},
# }

# # Worker settings
# CELERY_TASK_ACKS_LATE = True
# CELERY_WORKER_PREFETCH_MULTIPLIER = 1
# CELERY_TASK_SOFT_TIME_LIMIT = 30
# CELERY_WORKER_MAX_TASKS_PER_CHILD = 100
# CELERY_WORKER_DISABLE_RATE_LIMITS = True


from pathlib import Path
import os
import secrets
import dj_database_url
from dotenv import load_dotenv
from django.core.exceptions import ImproperlyConfigured
from django.contrib.messages import constants as messages

# Base directory
BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env for local development
load_dotenv(BASE_DIR / '.env')

# Utility to parse booleans from environment
def get_bool_env(var_name: str, default: bool = False) -> bool:
    value = os.environ.get(var_name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "t", "yes", "y", "on"}

# SECURITY
DEBUG = get_bool_env('DEBUG', default=True)

SECRET_KEY = os.environ.get('SECRET_KEY')
if not SECRET_KEY:
    if DEBUG:
        secret_file = BASE_DIR / '.secret_key'
        if secret_file.exists():
            SECRET_KEY = secret_file.read_text().strip()
        else:
            SECRET_KEY = secrets.token_urlsafe(64)
            secret_file.write_text(SECRET_KEY)
    else:
        raise ImproperlyConfigured('SECRET_KEY environment variable is required')

raw_allowed_hosts = os.environ.get('ALLOWED_HOSTS', '*')
ALLOWED_HOSTS = [host.strip() for host in raw_allowed_hosts.split(',') if host.strip()]
if not ALLOWED_HOSTS:
    ALLOWED_HOSTS = ['*']

# APPLICATIONS
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.humanize',

    'channels',
    'estateApp',
    'adminSupport',
    'DRF',
    'widget_tweaks',
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
]

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.TokenAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
}

# MIDDLEWARE
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Static file handling
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

CORS_ALLOW_ALL_ORIGINS = get_bool_env('CORS_ALLOW_ALL_ORIGINS', default=True)
CORS_ALLOWED_ORIGINS = [
    "http://localhost:8080",
    "http://localhost:5601",
    "http://192.168.110.208:5555",
    "http://192.168.110.208:8000",
]

# URLS
ROOT_URLCONF = 'estateProject.urls'
WSGI_APPLICATION = 'estateProject.wsgi.application'
ASGI_APPLICATION = 'estateProject.asgi.application'

# Channels
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/0')],
        },
    }
}

# DATABASE
DATABASES = {
    'default': dj_database_url.config(
        default=f'sqlite:///{BASE_DIR / "db.sqlite3"}',
        conn_max_age=600,
        conn_health_checks=True
    )
}

# PASSWORD VALIDATION
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# INTERNATIONALIZATION
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# STATIC FILES
STATICFILES_FINDERS = [
    "django.contrib.staticfiles.finders.FileSystemFinder",
    "django.contrib.staticfiles.finders.AppDirectoriesFinder",
]

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'static'),
    os.path.join(BASE_DIR, 'estateApp', 'static'),
    os.path.join(BASE_DIR, 'adminSupport', 'static'),
]

STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# MEDIA FILES
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# DEFAULT AUTO FIELD
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# CUSTOM USER MODEL
AUTH_USER_MODEL = 'estateApp.CustomUser'

# CSRF
CSRF_FAILURE_VIEW = 'estateApp.views.custom_csrf_failure_view'

# AUTHENTICATION
LOGIN_URL = '/login/'
LOGOUT_REDIRECT_URL = '/login/'

SESSION_COOKIE_AGE = 300
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
SESSION_SAVE_EVERY_REQUEST = True

AUTHENTICATION_BACKENDS = (
    'django.contrib.auth.backends.ModelBackend',
    'estateApp.backends.EmailBackend',
)

# MESSAGE TAGS
MESSAGE_TAGS = {
    messages.ERROR: 'danger',
    messages.SUCCESS: 'success',
}

# FIREBASE / PUSH NOTIFICATIONS
FIREBASE_CREDENTIALS_PATH = os.environ.get('FIREBASE_CREDENTIALS_PATH')
FIREBASE_DEFAULT_ICON = os.environ.get('FIREBASE_DEFAULT_ICON', 'ic_chat_notification')
FIREBASE_DEFAULT_COLOR = os.environ.get('FIREBASE_DEFAULT_COLOR', '#075E54')
FIREBASE_DEFAULT_CHANNEL_ID = os.environ.get('FIREBASE_DEFAULT_CHANNEL_ID', 'chat_messages')
FIREBASE_DEFAULT_SOUND = os.environ.get('FIREBASE_DEFAULT_SOUND', 'default')

# REDIS & CELERY
REDIS_URL = os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379')
CELERY_BROKER_URL = f"{REDIS_URL}/0"
CELERY_RESULT_BACKEND = f"{REDIS_URL}/1"
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_DEFAULT_QUEUE = 'default'

CELERY_BROKER_TRANSPORT_OPTIONS = {
    'ssl_cert_reqs': 'CERT_NONE',
    'retry_on_timeout': True,
    'socket_keepalive': True,
    'socket_timeout': 30,
    'socket_connect_timeout': 30,
}

CELERY_TASK_ROUTES = {
    "estateApp.tasks.dispatch_notification_batch": {"queue": "notifications"},
    "estateApp.tasks.dispatch_notification_stream": {"queue": "notifications"},
}

CELERY_TASK_ACKS_LATE = True
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_TASK_SOFT_TIME_LIMIT = 30
CELERY_WORKER_MAX_TASKS_PER_CHILD = 100
CELERY_WORKER_DISABLE_RATE_LIMITS = True
