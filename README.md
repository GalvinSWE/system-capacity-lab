# System Capacity and Concurrency Lab

A reproducible environment for measuring application and database capacity, protecting booking invariants under concurrency, and observing service failover.

The goal is not to present laptop numbers as production capacity. The goal is to make the measurement method, workload, environment, and bottleneck visible.

## Architecture

```text
public entry
  └─ gateway-a / gateway-b
       ├─ application load balancer
       │    └─ app-a / app-b
       │         └─ PostgreSQL
       └─ mock external service
```

## What it measures

- HTTP capacity without database access
- Primary-key lookup capacity
- Filtered and ordered search over 100,000 generated properties
- PostgreSQL connection-pool pressure
- Throughput, latency, and request errors under changing concurrency
- Database-level protection against overlapping reservations
- Application and gateway failover
- Gateway routing, API-key policy, and rate limiting

## Run locally

```bash
npm ci
docker compose up -d --build --wait
npm start
```

In another terminal:

```bash
npm run test:all
```

Stop the environment:

```bash
docker compose down
```

Use `docker compose down -v` only when you intentionally want to remove the lab database volume.

## Capacity experiments

```bash
npm run load:health
npm run load:database
npm run load:search
```

Change concurrency while keeping duration and environment constant. The final two arguments are concurrency and duration in seconds:

```bash
node scripts/load.js http://127.0.0.1:4000/health 10 10
node scripts/load.js http://127.0.0.1:4000/health 100 10
node scripts/load.js http://127.0.0.1:4000/health 300 10
```

Record at least:

| Environment | Workload | Concurrency | Req/s | p50 | p95 | Errors | DB pool waiting |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| local | health/database/search | — | — | — | — | — | — |

## Booking invariant

```bash
npm run test:concurrency
```

The test sends 50 concurrent requests for the same unit and date range. The required invariant is:

```text
exactly one request returns 201
all competing requests return 409
```

The invariant is protected by PostgreSQL rather than an application-only pre-check.

## Failover and gateway verification

```bash
npm run test:failover
npm run test:gateway
npm run test:gateway-failover
```

These scripts verify application failover, gateway routing, policy enforcement, rate limiting, and gateway-instance recovery.

## CI

```bash
npm run ci:local
```

`azure-pipelines.yml` describes the corresponding hosted validation flow:

```text
checkout → npm ci → compose up → invariant/failover tests → compose down
```

## Interpretation

- Compare workloads rather than relying on a single throughput number.
- Report hardware, software versions, dataset size, concurrency, and test duration.
- Treat rising latency, errors, pool waiters, CPU, memory, and database statistics as related signals.
- A local result is evidence about the experiment—not a production capacity promise.
