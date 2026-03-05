# Backend API for Render (Docker). Python 3.12, Flask + Gunicorn.
# Build context: server/ (e.g. docker build -f server/Dockerfile server/)

FROM python:3.12-slim

# Install system deps for psycopg2 and any native libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Use encoding-safe requirements (requirements.txt.utf8); copy as requirements.txt for pip
COPY requirements.txt.utf8 ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY . .

# Render sets PORT; render_start.sh uses 0.0.0.0:${PORT:-5000}
ENV FLASK_APP=app:create_app
EXPOSE 5000

# Migrations + Gunicorn (same as native Render build)
CMD ["bash", "render_start.sh"]
