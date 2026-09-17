<p align="center">
  <img src="frontend/public/logo.png" alt="Aero Bound Ventures logo" width="120" />
</p>

<h1 align="center">Aero Bound Ventures</h1>

<p align="center">
  A full-stack flight booking platform built with Next.js, FastAPI, PostgreSQL,
  Redis, and Kafka.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/Next.js-000000?logo=next.js&logoColor=white" alt="Next.js" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/Redis-DC382D?logo=redis&logoColor=white" alt="Redis" />
  <img src="https://img.shields.io/badge/Kafka-231F20?logo=apachekafka&logoColor=white" alt="Kafka" />
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white" alt="Kubernetes" />
</p>

## Overview

Aero Bound Ventures integrates flight search, booking, payments, authentication,
notifications, and administration in one application. The backend can use the
Amadeus API for live flight data or local fixtures for development and demos.

## Core Capabilities

- Search, price, book, and cancel flights
- Select seats and manage bookings
- Process Pesapal payments and refunds
- Authenticate with credentials or Google OAuth
- Deliver email and real-time notifications through Kafka and Redis
- Manage bookings, revenue, permissions, and uploaded tickets

## Architecture

```text
Next.js frontend
       |
       | REST and SSE
       v
FastAPI API ---- PostgreSQL
    |   |
    |   +------ Redis cache and Pub/Sub
    |
    +---------- Kafka ---- notification worker
    |
    +---------- Amadeus, Pesapal, Cloudinary, Google OAuth, SMTP
```

## Technology

| Area | Main tools |
|---|---|
| Frontend | Next.js, React, TypeScript, Tailwind CSS, Zustand, TanStack Query |
| Backend | FastAPI, Python, SQLModel, Alembic, uv |
| Data and events | PostgreSQL, Redis, Kafka |
| Observability | OpenTelemetry, Prometheus, Grafana, Loki, Tempo |
| Infrastructure | Docker Compose, Helm, Kubernetes, Terraform, AWS |
| Delivery and configuration | GitHub Actions, Doppler |

## Repository Layout

```text
backend/         FastAPI API, worker, migrations, tests, and Docker Compose
frontend/        Next.js application
docker/          Root docker-compose.yml's Postgres init SQL (schema + admin seed)
observability/   Root docker-compose.yml's Prometheus/Loki/Tempo/Grafana/otel-collector config
helm/            Backend and DopplerSecret Helm charts
terraform/       EC2 production and EKS staging infrastructure
scripts/         Local Kubernetes bootstrap automation
```

## Local Development

### Fastest path: Docker Compose (everything, one command)

The whole stack -- Postgres, Redis (+ UI), Kafka (+ UI), the FastAPI
backend, the notification worker, the Next.js frontend, and a full
observability stack (Prometheus, Grafana, Loki, Tempo, OpenTelemetry
Collector, cAdvisor, node-exporter) -- starts with:

```bash
docker compose up --build
```

A ready-to-use `.env` (with generated dev secrets) is already included,
so this works with no setup. First boot also creates all the database
tables and seeds a default login automatically -- see
[docker/README.md](docker/README.md).

Once everything is healthy:

| What | URL | Login |
|---|---|---|
| App (frontend) | http://localhost:3000 | `admin@example.com` / `password123` |
| Backend API docs | http://localhost:8000/docs | -- |
| Grafana | http://localhost:3001 | `admin` / `admin` |
| Prometheus | http://localhost:9090 | -- |
| Kafka UI | http://localhost:8080 | -- |
| Redis Commander | http://localhost:8081 | `admin` / `admin123` |

See [observability/README.md](observability/README.md) for how telemetry
flows from the app to Grafana, what the provisioned dashboard/alerts cover,
and a couple of platform-specific caveats (cAdvisor/node-exporter on
Docker Desktop).

Tear down with `docker compose down`, or `docker compose down -v` to
also wipe every database/queue/metrics volume (needed if you edit the
SQL init scripts, since they only run against a fresh volume).

This root `docker-compose.yml` is a new, fully self-contained way to run
everything locally without Doppler. The steps below (and
`backend/compose.yaml`) are the original Doppler-based workflow, still
used for the EC2 deployment path.

### Manual / per-service path

### Backend

Prerequisites: Docker, Docker Compose, and an authenticated
[Doppler CLI](https://docs.doppler.com/docs/install-cli).

```bash
cd backend
doppler setup
export DOPPLER_TOKEN="$(doppler configs tokens create docker --max-age 15m --plain)"
docker compose up -d --wait db redis kafka
docker compose build fastapi-app
docker compose run --rm migrate
docker compose up -d fastapi-app notification-worker
```

The API is available at `http://localhost:8000`; its Swagger documentation is
at `http://localhost:8000/docs`.

See [backend/README.md](backend/README.md) for configuration, migrations,
management commands, observability services, and Kubernetes development.

### Frontend

Prerequisite: Node.js 20 or later.

```bash
cd frontend
npm install
cp .env.example .env.local
npm run dev
```

The frontend is available at `http://localhost:3000`. Set
`NEXT_PUBLIC_API_BASE_URL=http://localhost:8000/api/v1` in `.env.local`.

## Verification

```bash
cd backend
uv run pytest
cd ../frontend
npm run lint
```

For infrastructure changes:

```bash
terraform -chdir=terraform validate
terraform -chdir=terraform plan
```

## Deployment

Docker Compose on EC2 remains the production deployment path. EKS is an
independent, production-like staging environment managed with Terraform, Helm,
GitHub Actions, and the Doppler Kubernetes Operator.

## License

MIT
