FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy load balancer code
COPY lb.py .

# Expose load balancer port
EXPOSE 8081

# Run load balancer
CMD ["python", "-u", "lb.py"]
