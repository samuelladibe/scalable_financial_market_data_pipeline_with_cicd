# Financial Pipeline Project Summary: **Issue**s and **Fix**es
This document summarizes the key technical challenges and solutions implemented during the initial setup and configuration of the Django-based data fetching and scheduling pipeline using Docker Compose.

## I. Initial Setup & Database Connection
### 1. Missing Django Model (`models.py`)
**Issue**: Django's `makemigrations` and `migrate` commands failed to create the necessary database table (`crypto_prices`) because a corresponding Django Model was missing.

**Fix**: Implemented the `CryptoPrice` Model in `app/db/models.py` with `db_table = 'crypto_prices'` to match the application's raw SQL insertion logic. Migrations were then successfully run.

### 2. Database Table Alteration Failure
**Issue**: Attempting to add the `insertion_datetime` field resulted in an error requiring a default value, even after deleting the Docker volume, due to cached migration history (0001_initial.py).

**Fix**: Reset Migration History. The existing migration file (`app/db/migrations/0001_initial.py`) was deleted on the host machine, and a fresh `makemigrations` and `migrate` sequence was run.

### 3. Container Startup Failure (Container Exits)
**Issue**: The main `financial_pipeline_app` container started and immediately exited because the sequential `command` (migrate -> collectstatic -> runserver) failed due to a premature database connection attempt or missing settings.

**Fix**: Implemented a Database Wait Loop. The command in docker-compose.yml was modified to include a while ! pg_isready... loop before executing migrate, ensuring the PostgreSQL service is fully ready to accept connections before Django attempts setup.

### 4. `STATIC_ROOT` Configuration Error
**Issue**: The `python manage.py collectstatic` command failed with an `ImproperlyConfigured` error because the `STATIC_ROOT` was not defined.

**Fix**: Added `STATICFILES_DIRS` and the required `STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')` to `financial_pipeline/settings.py`.

## II. Cron Scheduling & Environment Integrity
### 5. `ModuleNotFoundError` for Local Files
**Issue**: When running the fetcher script via the robust `manage.py shell -c` command, the script failed with `ModuleNotFoundError: No module named 'fetch_crypto'`.

**Fix**: Used Absolute Import. Changed the import statement in `app/fetcher/fetch_and_store.py` from relative (`from .fetch_crypto import fetch_crypto_data`) to the absolute project path: `from app.fetcher.fetch_crypto import fetch_crypto_data`.

### 6. Database Host Resolution (`localhost` vs. `db`)
**Issue**: The `cron_scheduler` container failed to connect to Postgres because the script was looking for the database at ``localhost``. This was caused by the script reading ``DB_HOST=localhost`` from the local ``.env`` file via `dotenv`.

**Fix**:

1. **Removed `dotenv`**: Eliminated ``load_dotenv()`` from ``fetch_and_store.py`` as Docker Compose manages environment variables.

2. **Forced `DB_HOST`:** Explicitly set **`DB_HOST=db`** in the environment block of the ``cron_scheduler`` service in ``docker-compose.yml``, overriding any conflicting value from the ``.env`` file.

### 7. Cron Scheduler Access Denied (Security)
**Issue**: Initial plan involved mounting the Docker socket (``/var/run/docker.sock``) for the cron service to run ``docker exec``, posing a severe security risk.

**Fix: Created a Self-Contained Cron Service.** Configured ``cron_scheduler`` to use the main ``app`` image, removing the need for socket access and allowing it to run the Python script directly.

### 8. Crontab Command Failure
**Issue**: The cron job failed because the command in ``crontab/crons.conf`` was the direct, unreliable Python execution path, not the successful Django shell command.

**Fix**: Updated ``crontab/crons.conf`` to use the proven method: ``python manage.py shell -c "from app.fetcher.fetch_and_store import run_fetcher; run_fetcher()"``

## Next Step: Prometheus and Grafana Setup
The next logical step is to integrate Prometheus and Grafana for visualization and monitoring, ensuring the data you're fetching can be cleanly presented.

## I. Planning the Monitoring Stack
To achieve robust visualization, you will need to:

1. **Prometheus**: Scrapes metrics (needs an exporter).
2. **Grafana**: Queries Prometheus and displays the data.
3. **Django** Exporter: A library to expose your Django/Python metrics for Prometheus to scrape.

You will need to add two new services (``prometheus`` and ``grafana``) to your ``docker-compose.yml`` and potentially update your ``Dockerfile`` or Django code to expose basic metrics.