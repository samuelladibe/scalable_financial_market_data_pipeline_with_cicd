# Base image
FROM python:3.11-slim

# Set the working directory
WORKDIR /app

# Copy the requirements and install dependencies
COPY requirements.txt .

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the entire application code
COPY . .

# Expose the port (optional, if running a web app or API)
EXPOSE 8000

# Set the entrypoint (e.g., manage.py for Django or any main script)
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
