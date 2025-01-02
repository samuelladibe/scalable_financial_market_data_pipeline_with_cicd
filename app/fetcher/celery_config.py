import os
from celery import Celery
from celery.schedules import crontab

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
celery = Celery(
    'tasks',
    broker='redis://localhost:6379/0',
    backend='redis://localhost:6379/0'
)

# Celery configuration
celery.conf.update(
    timezone = 'UTC',
    enable_utc=True,
    beat_schedule={
        'fetch-crypto-every-day-minutes': {
            'task': 'tasks.fetch_and_store_crypto',
            'schedule': crontab(hour=0, minute=0),  # Every day at midnigth
    },
    }
)
celery.conf.beat_scheduler='django_celery_beat.schedulers:DatabaseScheduler'