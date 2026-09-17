# --- Stage 1: Build -----
FROM python:3.12-slim AS builder

# Install uv.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app/backend

COPY pyproject.toml uv.lock ./

# NOTE: intentionally not --frozen. pyproject.toml now declares several
# opentelemetry-instrumentation-* packages that aren't in the committed
# uv.lock (that lock predates them and can't be regenerated without
# network access at authoring time), so uv needs to re-resolve here.
# It still reuses the existing lock for anything unaffected.
RUN uv sync --no-cache --no-dev

COPY . .

# --- Stage 2: Runtime -----
FROM python:3.12-slim AS runtime

WORKDIR /app/backend

ENV PYTHONPATH=/app
ENV PATH="/app/backend/.venv/bin:$PATH"
# Standard OpenTelemetry zero-code auto-instrumentation resource
# attributes shared by every process using this image; service.name is
# set per-container in docker-compose.yml (OTEL_SERVICE_NAME) since the
# same image runs both the API and the notification worker.
ENV OTEL_PYTHON_LOG_CORRELATION=true
ENV OTEL_TRACES_EXPORTER=otlp
ENV OTEL_METRICS_EXPORTER=otlp
ENV OTEL_LOGS_EXPORTER=otlp
ENV OTEL_EXPORTER_OTLP_PROTOCOL=grpc

COPY --from=builder /app/backend /app/backend

CMD ["opentelemetry-instrument", "fastapi", "run", "main.py", "--port", "80", "--host", "0.0.0.0"]
