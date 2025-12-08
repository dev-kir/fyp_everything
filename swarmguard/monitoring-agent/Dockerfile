FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY *.py .

ENV PYTHONUNBUFFERED=1
ENV NET_IFACE=eth0
ENV POLL_INTERVAL=5
ENV NODE_NAME=unknown

CMD ["python", "agent.py"]
