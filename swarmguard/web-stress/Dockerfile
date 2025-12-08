FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY *.py .
COPY stress/ ./stress/

ENV PYTHONUNBUFFERED=1

EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=3s CMD python -c "import requests; requests.get('http://localhost:8080/health')"

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
