# app/db/models.py

from django.db import models

class CryptoPrice(models.Model):
    # These fields must match the columns in your INSERT query
    timestamp = models.DateTimeField(primary_key=True) 
    symbol = models.CharField(max_length=10)
    market = models.CharField(max_length=50)
    open_price = models.DecimalField(max_digits=18, decimal_places=8)
    high_price = models.DecimalField(max_digits=18, decimal_places=8)
    low_price = models.DecimalField(max_digits=18, decimal_places=8)
    close_price = models.DecimalField(max_digits=18, decimal_places=8)
    volume = models.DecimalField(max_digits=20, decimal_places=8) 
    insertion_datetime = models.DateTimeField()

    class Meta:
        # **Crucial for your script:** Forces the table name to match your query
        db_table = 'crypto_prices'
        # Matches the ON CONFLICT constraint in your SQL
        unique_together = (('timestamp', 'symbol', 'market'),)
        
    def __str__(self):
        return f"{self.symbol} - {self.timestamp}"