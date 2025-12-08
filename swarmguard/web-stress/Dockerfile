FROM python:3.12-slim

WORKDIR /app

# Install curl for health check
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY *.py .
COPY stress/ ./stress/

ENV PYTHONUNBUFFERED=1

EXPOSE 8080

# Fixed health check using curl
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
