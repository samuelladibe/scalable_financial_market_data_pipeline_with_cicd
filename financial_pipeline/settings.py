import os
from dotenv import load_dotenv

load_dotenv()

# Database connection details
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER") # Change this if your username is different
DB_PASSWORD = os.getenv("DB_PASSWORD") # Replace with your PostgreSQL password
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")

INSTALLED_APPS = [
    # other apps...
    'django_crontab',
    'app.fetcher',
]

CRONJOBS = [
    # Schedule, Command to run
    ('0 0 * * *', 'app.fetcher.tasks.run_fetch_and_store'), # Runs daily at midnight
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
