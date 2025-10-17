# Example app/apps.py
from django.apps import AppConfig

class FinancialAppConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'app' # <-- This is the label!
    # or
    label = 'financial_app' # <-- This would be your label!