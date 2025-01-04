import os
import pandas as pd
from fetch_and_store import fetch_crypto_data, store_data_in_db

def run_fetch_and_store():
    """
    Fetch cryptocurrency data and store it in the database.
    """
    try:
        # Fetch data
        crypto_df = fetch_crypto_data("BTC", "USD")
        crypto_df["timestamp"] = pd.to_datetime(crypto_df["timestamp"])

        # Store in the database
        store_data_in_db(crypto_df)
        print("Data fetched and stored successfully!")
    except Exception as e:
        print(f"Error during fetch and store: {e}")
