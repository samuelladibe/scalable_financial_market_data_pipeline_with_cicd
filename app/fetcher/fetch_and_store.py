import os
from datetime import datetime
from fetch_crypto import fetch_crypto_data
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

load_dotenv()

# Database connection details
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER") # Change this if your username is different
DB_PASSWORD = os.getenv("DB_PASSWORD") # Replace with your PostgreSQL password
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")

# print(f"DB_NAME: {DB_NAME}, DB_USER: {DB_USER}, DB_PASSWORD: {DB_PASSWORD}, DB_HOST: {DB_HOST}, DB_PORT: {DB_PORT}")

def store_data_in_db(dataframe):
    """
    Store the crypto data in the PostgreSQL database.
    Args:
        dataframe (pd.DataFrame): DataFrame containing crypto data.
    """
    # Connect to the database
    try:
        print("Attempting to connect to the database...")
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        
        if conn:
            print("Connected to the database successfully!")

            # Insert data
            with conn.cursor() as cur:
                # Define the insert query
                insert_query = """
                INSERT INTO crypto_prices (
                    timestamp, symbol, market, open_price, high_price, low_price, close_price, volume, insertion_datetime
                ) VALUES %s
                ON CONFLICT (timestamp, symbol, market) DO NOTHING;
                """

                # Prepare data for insertion
                rows = [
                    (
                        row["timestamp"],
                        row["symbol"],
                        row["market"],
                        float(row["1. open"]),
                        float(row["2. high"]),
                        float(row["3. low"]),
                        float(row["4. close"]),
                        float(row["5. volume"]),
                        datetime.now().strftime("%Y%m%d %H%M%S")            # add insertion_datetime to handle metadata
                    )
                    for _, row in dataframe.iterrows()
                ]

                print("Rows to insert:", rows[:5]) # Print the first 5 rows
                # Execute the query
                execute_values(cur, insert_query, rows)
                conn.commit()
                print("Data inserted successfully!")
                
                conn.close()
        else:
            print("Database connection failed. Exiting script.")
    except psycopg2.DatabaseError as db_err:
        print(f"Database error: {db_err}")
    except Exception as e:
        print(f"Unexpected error: {e}")
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")

# Fetch data and store in the database
try:
    crypto_df = fetch_crypto_data("BTC", "USD")
    
    # Convert timestamp column to datetime
    crypto_df["timestamp"] = pd.to_datetime(crypto_df["timestamp"])

    print("Crypto DataFrame Columns:", crypto_df.columns)
    print(crypto_df.head())
    # Store in the database
    store_data_in_db(crypto_df)
except Exception as e:
    print(f"Error: {e}")
