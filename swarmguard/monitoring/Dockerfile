FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY lb_metrics_collector.py .

CMD ["python", "lb_metrics_collector.py"]
