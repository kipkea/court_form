# ==============================================================================
# Dockerfile: Court Smart Form & Print Studio (Backend + Web Frontend)
# Base OS: Debian Bookworm Slim with Python 3.12 & Thai Fonts
# ==============================================================================
FROM python:3.12-slim-bookworm

# Avoid prompts from debconf and set python environment
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8007 \
    HOST=0.0.0.0

# Install essential system libraries & Thai fonts (fonts-thai-tlwg)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    fonts-thai-tlwg \
    fontconfig \
    ca-certificates \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY backend/requirements.txt /app/backend/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy backend source code and pre-built frontend web build
COPY backend/ /app/backend/
COPY frontend/build/web/ /app/frontend/build/web/

# Make sure entrypoint script is executable
RUN chmod +x /app/backend/docker-entrypoint.sh

# Collect static files into backend/staticfiles for WhiteNoise
WORKDIR /app/backend
RUN python manage.py collectstatic --noinput

EXPOSE 8007

ENTRYPOINT ["/app/backend/docker-entrypoint.sh"]
CMD ["python", "serve_production.py"]
