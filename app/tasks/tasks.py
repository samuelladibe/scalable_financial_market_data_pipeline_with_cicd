from config.celery_config import celery
from app.fetcher.fetch_and_store import fetch_crypto_data, store_data_in_db
import pandas as pd

@celery.task
def fetch_and_store_tasks () :
    """"
        The function calls fetch_crypto_data to fetch data from Vantage API
        And we use also store_data_in_db to ingest data into PostgreSQL databalse
        
        Returns : dataframe of the data fetched.
    """
    try:
        crypto_df = fetch_crypto_data("BTC", "USD")
        crypto_df["timestamp"] = pd.to_datetime(crypto_df["timestamp"])
        store_data_in_db(crypto_df)
        print("Data ingestion successful !")
    except Exception as e:
        print(f"Task faile: {e}")