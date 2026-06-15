# ---- Dockerfile for the Django application ----
# Base image: Python 3.12 (satisfies the "Python 3.9 or newer" requirement).
FROM python:3.12-slim

# Python behaviour inside the container:
#   PYTHONDONTWRITEBYTECODE=1 -> don't create .pyc cache files
#   PYTHONUNBUFFERED=1        -> show logs immediately (don't buffer output)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# All following commands run inside this folder in the container.
WORKDIR /app

# Copy ONLY the requirements first and install them.
# Docker caches this layer, so rebuilds are fast when code changes but deps don't.
COPY requirements.txt /app/
RUN pip install --upgrade pip && pip install -r requirements.txt

# Now copy the rest of the project source code into the image.
COPY . /app/

# The Django dev server will listen on this port inside the container.
EXPOSE 8000

# Default command: start the Django server, reachable from outside the container.
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
