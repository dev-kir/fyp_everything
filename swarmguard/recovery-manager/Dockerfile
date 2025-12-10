FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY *.py .
COPY config.yaml /app/config.yaml

ENV PYTHONUNBUFFERED=1
ENV CONFIG_PATH=/app/config.yaml

EXPOSE 5000

CMD ["python", "manager.py"]
