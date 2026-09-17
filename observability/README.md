# observability/

Config and provisioning for the monitoring stack in `docker-compose.yml`:
OpenTelemetry Collector, Prometheus, Grafana, Loki, Promtail, and Tempo.

## How telemetry flows

```text
fastapi-app  ----\
notification-worker --\
                        >---- OTLP (traces+metrics+logs) ----> otel-collector --> Tempo (traces)
frontend (Next.js) ---/                                            |
                                                                     +--> exposes :8889/metrics --> scraped by Prometheus
db / redis / kafka (containers) --> cAdvisor --------------------------> scraped by Prometheus
host ----------------------------> node-exporter -----------------------> scraped by Prometheus
fastapi-app :80/metrics (prometheus-fastapi-instrumentator) ------------> scraped by Prometheus directly

every container's stdout ---------> Promtail (via Docker socket) -------> Loki

Prometheus, Loki, Tempo  ---- all three added as Grafana datasources, cross-linked
                              (trace -> logs, trace -> service graph, log -> trace)
```

- **Traces**: all three app processes are auto-instrumented via OpenTelemetry
  zero-code instrumentation -- no manual span code anywhere.
  - Backend (`fastapi-app`, `notification-worker`): the Dockerfile's `CMD`/
    `command` wraps the process with `opentelemetry-instrument`, which patches
    every installed `opentelemetry-instrumentation-*` package at startup (see
    `backend/pyproject.toml` -- fastapi, httpx, requests, redis, psycopg2,
    sqlalchemy, confluent-kafka, logging, system-metrics).
  - Frontend (`frontend`): Next.js's native `instrumentation.ts` hook
    (`frontend/src/instrumentation.ts`) registers `@vercel/otel`, which
    auto-instruments fetch calls, route handlers, and server actions.
  - All three export OTLP to `otel-collector`, which forwards to Tempo.

- **Metrics**: three sources feed Prometheus:
  1. `fastapi-app`'s own `/metrics` (HTTP request rate, latency, status
     codes -- from `prometheus-fastapi-instrumentator`, already in the app).
  2. `otel-collector`'s `prometheus` exporter (`:8889/metrics`) -- carries
     whatever the OTel auto-instrumentation captures for all three
     processes, including `opentelemetry-instrumentation-system-metrics`'
     process-level CPU/memory.
  3. `cadvisor` (container CPU/memory/network) and `node-exporter` (host
     CPU/memory/disk) -- scraped directly.

- **Logs**: `promtail` uses Docker service discovery
  (`docker_sd_configs`, via a read-only mount of the Docker socket) to tail
  **every** container's stdout/stderr and ship it to Loki -- this replaced
  the previous setup, which only read one file
  (`backend/promtail-config.yml` scraped just `.logs/backend.log`) and
  therefore missed the worker, frontend, and every infra container. The
  otel-collector also has a `loki` exporter wired up as a secondary path
  for anything that goes through OpenTelemetry log auto-instrumentation.

## Grafana

- URL: http://localhost:3001 (or `${GRAFANA_PORT}`)
- Login: `admin` / `admin` (`GF_ADMIN_USER` / `GF_ADMIN_PASSWORD` in `.env`)
- Datasources (Prometheus, Loki, Tempo) and the dashboard below are
  provisioned automatically on first boot from
  `observability/grafana/provisioning/`.
- **Bug fixed**: the original `backend/grafana/provisioning/datasources/loki.yml`
  had a stray backtick (`` access: proxy` ``) that made it invalid YAML --
  Grafana would have silently failed to load the Loki datasource. Fixed in
  `observability/grafana/provisioning/datasources/datasources.yml`.

### Dashboard

"Aero Bound Ventures - Service Overview" (`aero-bound-overview.json`), in
the "Aero Bound Ventures" folder:

- Backend API uptime, error rate (5xx %), request rate, P95 latency
- A table of every Prometheus scrape target's up/down status
- Request rate by status code, error rate over time
- Container CPU % and memory (per container, from cAdvisor)
- Node CPU % and memory % (from node-exporter)

### Alerting

Four Grafana-managed alert rules (`observability/grafana/provisioning/alerting/rules.yaml`),
evaluated every minute, firing after 5 minutes sustained:

- Container CPU > 70%
- Container memory > 70% **of its configured limit**
- Node CPU > 70%
- Node memory > 70%

All four route to a single email contact point (`ops-email`), sent to
`ALERT_EMAIL_TO` in `.env` -- delivery depends on the `MAIL_*` SMTP
settings in `.env` being real credentials (they're placeholders by
default, same as the rest of the app's email sending).

**Why "% of limit" for container memory**: `container_spec_memory_limit_bytes`
(from cAdvisor) is a huge sentinel value for containers with no memory cap,
which would make a raw usage-based percentage meaningless. So
`docker-compose.yml` sets `deploy.resources.limits.memory` on every
application/data-store service (this is honored by plain `docker compose up`
in Compose v2, not just Swarm) specifically so this alert has a real
denominator to compare against.

## Known platform caveats

- **cAdvisor** runs `privileged: true` with the standard host mounts
  (`/rootfs`, `/sys`, `/var/lib/docker`, `/dev/disk`) for the most reliable
  cross-platform metrics collection; on Docker Desktop (macOS/Windows) some
  disk-level metrics may still be unavailable since it's running inside a
  Linux VM, but container CPU/memory metrics work normally.
- **node-exporter** is run with bind-mounted `/proc`, `/sys`, `/` (not
  `network_mode: host`, which doesn't work on Docker Desktop) so it starts
  consistently everywhere; on Docker Desktop this reports the VM's
  resources, not literally the physical host's.
- Tempo's `metrics_generator` pushes span-derived RED metrics to Prometheus
  via `remote_write` (needs `--web.enable-remote-write-receiver`, already
  set on the `prometheus` service) -- this is a bonus signal, not required
  for the dashboard/alerts above, which all use cAdvisor/node-exporter/the
  app's own `/metrics` directly.
