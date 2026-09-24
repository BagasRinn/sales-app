FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Railway passes repo root as build context, so we copy only the backend folder
COPY sales-app/backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY sales-app/backend/ .

# Run the app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
