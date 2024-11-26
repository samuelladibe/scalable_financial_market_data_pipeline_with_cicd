INSTALLED_APPS = [
    # other apps...
    'django_celery_beat',
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',  # Or another backend (e.g., 'django.db.backends.sqlite3')
        'NAME': 'crypto_db_new',
        'USER': 'samuel',
        'PASSWORD': 'samuel',
        'HOST': 'localhost',  # Or your database server
        'PORT': '5432',  # Default PostgreSQL port
    }
}
