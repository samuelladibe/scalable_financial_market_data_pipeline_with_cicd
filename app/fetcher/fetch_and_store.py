from fetch_crypto import fetch_crypto_data
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

# Database connection details
DB_NAME = "crypto_db"
DB_USER = "samuel"  # Change this if your username is different
DB_PASSWORD = "samuel"  # Replace with your PostgreSQL password
DB_HOST = "localhost"
DB_PORT = "5432"

def store_data_in_db(dataframe):
    """
    Store the crypto data in the PostgreSQL database.
    Args:
        dataframe (pd.DataFrame): DataFrame containing crypto data.
    """
    # Connect to the database
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        print("Connected to the database successfully!")

        # Insert data
        with conn.cursor() as cur:
            # Define the insert query
            insert_query = """
            INSERT INTO crypto_prices (
                timestamp, symbol, market, open_price, high_price, low_price, close_price, volume
            ) VALUES %s
            ON CONFLICT (timestamp, symbol, market) DO NOTHING;
            """

            # Prepare data for insertion
            rows = [
                (
                    row["timestamp"],
                    row["symbol"],
                    row["market"],
                    float(row["1a. open (USD)"]),
                    float(row["2a. high (USD)"]),
                    float(row["3a. low (USD)"]),
                    float(row["4a. close (USD)"]),
                    float(row["5. volume"])
                )
                for _, row in dataframe.iterrows()
            ]

            # Execute the query
            execute_values(cur, insert_query, rows)
            conn.commit()
            print("Data inserted successfully!")
    
    except Exception as e:
        print(f"Database error: {e}")
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")

# Fetch data and store in the database
try:
    crypto_df = fetch_crypto_data("BTC", "USD")
    
    # Convert timestamp column to datetime
    crypto_df["timestamp"] = pd.to_datetime(crypto_df["timestamp"])

    # Store in the database
    store_data_in_db(crypto_df)
except Exception as e:
    print(f"Error: {e}")


# Db connection test
# try:
#     conn = psycopg2.connect(
#         dbname="crypto_db",
#         user="samuel",
#         password="samuel",  # Leave blank for no password
#         host="localhost",
#         port="5432",
#     )
#     print("Connection successful!")
#     conn.close()
# except Exception as e:
#     print("Connection failed:", e)
