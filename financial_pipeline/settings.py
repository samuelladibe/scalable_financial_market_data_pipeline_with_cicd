import os
from dotenv import load_dotenv
from pathlib import Path

# Define BASE_DIR for the Django project
BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv()

# Database connection details
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER") # Change this if your username is different
DB_PASSWORD = os.getenv("DB_PASSWORD") # Replace with your PostgreSQL password
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
SECRET_KEY = os.environ.get('SECRET_KEY')
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # other apps...
    'django_crontab',
    'app.fetcher',
]

CRONJOBS = [
    # Schedule, Command to run
    ('0 0 * * *', 'app.fetcher.tasks.run_fetch_and_store'), # Runs daily at midnight
]

ALLOWED_HOSTS = ['*'] # You can add 'your-server-ip', 'your-domain.com' for deployment

ROOT_URLCONF = 'financial_pipeline.urls'

DEBUG = False

STATIC_URL = '/static/'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(BASE_DIR, 'templates')],  # Adjust 'templates' folder path as needed
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',  # Or another backend (e.g., 'django.db.backends.sqlite3')
        'NAME': DB_NAME,
        'USER': DB_USER,
        'PASSWORD': DB_PASSWORD,
        'HOST': DB_HOST,  # Or your database server
        'PORT': DB_PORT,  # Default PostgreSQL port
    }


# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.postgresql',  # Or another backend (e.g., 'django.db.backends.sqlite3')
#         'NAME': 'crypto_db_new',
#         'USER': 'sam',
#         'PASSWORD': 'samuel',
#         'HOST': 'localhost',  # Or your database server
#         'PORT': '5432',  # Default PostgreSQL port
#     }
}
