FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8081

WORKDIR /app

COPY sensor_simulator.py ./

EXPOSE 8081

CMD ["python", "sensor_simulator.py", "--web", "--port", "8081"]
