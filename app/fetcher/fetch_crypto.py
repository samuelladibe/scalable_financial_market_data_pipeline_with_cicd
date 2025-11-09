import requests
import pandas as pd
from datetime import datetime
import json

# Load API Key
with open("config/secrets.json") as f:
    secrets = json.load(f)
API_KEY = secrets["ALPHA_VANTAGE_API_KEY"]

# Function to fetch crypto data
def fetch_crypto_data(symbol: str, market: str, function: str = "DIGITAL_CURRENCY_DAILY"):
    """
    Fetch cryptocurrency data from Alpha Vantage.
    Args:
        symbol (str): Cryptocurrency symbol (e.g., "BTC").
        market (str): Market symbol (e.g., "USD").
        function (str): Alpha Vantage function (e.g., "DIGITAL_CURRENCY_INTRADAY").
    Returns:
        pd.DataFrame: Dataframe with the fetched data.
    """
    url = f"https://www.alphavantage.co/query"
    params = {
        "function": function,
        "symbol": symbol,
        "market": market,
        "apikey": API_KEY
    }
    
    response = requests.get(url, params=params)
    data = response.json()

    # Check for errors
    if "Note" in data:
        raise Exception("API limit reached. Response: " + str(data))
    elif "Error Message" in data:
        raise Exception(f"Error Message from API: {data['Error Message']}")
    elif f"Time Series (Digital Currency Daily)" not in data:
        raise Exception(f"No data returned. Full Response: {data}")
    
    # Extract time series data
    time_series = data[f"Time Series (Digital Currency Daily)"]
    
    # Convert to DataFrame
    df = pd.DataFrame.from_dict(time_series, orient="index")
    df.reset_index(inplace=True)
    df.rename(columns={"index": "timestamp"}, inplace=True)
    df["symbol"] = symbol
    df["market"] = market

    return df

# Fetch data for Bitcoin (BTC) in USD
try:
    crypto_df = fetch_crypto_data("BTC", "USD")
    print("Fetched intraday data successfully!")
    print(crypto_df.head())
    
    # Save to CSV
    current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
    # crypto_df.to_csv(f"crypto_data_daily_{current_time}.csv", index=False)
    print("Daily data saved to CSV!")
except Exception as e:
    print(f"Intraday data error: {e}")
    print("Trying daily data...")
    
    # Fallback to daily data
    try:
        crypto_df = fetch_crypto_data("BTC", "USD", function="DIGITAL_CURRENCY_DAILY")
        print("Fetched daily data successfully!")
        print(crypto_df.head())
        
        # Save to CSV
        current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        # crypto_df.to_csv(f"crypto_data_daily_{current_time}.csv", index=False)
        print("Daily data saved to CSV!")
    except Exception as e:
        print(f"Daily data error: {e}")
