# 1. CHANGE BASE IMAGE to a specific, stable Debian release
FROM python:3.11-slim-bookworm

# Set the working directory
WORKDIR /app

# Copy the requirements and install dependencies
COPY requirements.txt .

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# 2. Install dos2unix (for CRLF fix) and postgresql-client (for dbshell)
# Note: Debian "bookworm" is the current stable release.
# The 'install -y' is now safer on a recent, stable base.
RUN apt-get update \
    && apt-get install -y dos2unix postgresql-client cron \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the entire application code
COPY . .

# Convert the manage.py script to use Unix (LF) line endings
RUN dos2unix /app/manage.py

# Expose django the port
EXPOSE 8000

# Set the default command
CMD ["sh", "-c", "python", "manage.py", "runserver", "0.0.0.0:8000"]
