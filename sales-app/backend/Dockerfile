FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Run the app — Render uses the "Start Command" field separately,
# so CMD is here as a fallback.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
