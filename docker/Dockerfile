# Use a slim Python base image
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies to build wheels where necessary
RUN apt-get update \
	&& apt-get install -y --no-install-recommends build-essential gcc libpq-dev \
	&& rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Build wheels in builder to keep final image small
RUN pip wheel --no-cache-dir -r requirements.txt -w /wheels

FROM python:3.11-slim AS final
WORKDIR /app

# Install only runtime deps from wheels created in the builder stage
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf /wheels

# Copy app code and entrypoint
COPY ./src ./src
COPY ./docker/entrypoint.sh ./docker/entrypoint.sh

# Create a non-root user and ensure permissions
RUN adduser --disabled-password --gecos '' appuser \
	&& chown -R appuser:appuser /app \
	&& chmod +x ./docker/entrypoint.sh

USER appuser

EXPOSE 8000

ENTRYPOINT ["/app/docker/entrypoint.sh"]
CMD ["uvicorn", "cloud_devops_microservices.app:app", "--host", "0.0.0.0", "--port", "8000"]