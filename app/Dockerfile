FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .

RUN python -m pip install --no-cache-dir -r requirements.txt \
    && python -m gunicorn --version

RUN useradd --create-home --uid 10001 appuser

COPY app.py .

USER appuser

EXPOSE 5000

CMD ["/usr/local/bin/python", "-m", "gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
