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

### Results (local run, 2026-10-07)

Environment: Apple M1 Pro (10 cores, 32 GB), Docker 29.4, PostgreSQL 17.11, Node.js 24.15, one app process on the host with a 20-connection pool, 100,000 generated properties. Each run lasts 10 s; latency in ms; "Pool waiting" is the peak number of queries waiting for a connection, sampled every 100 ms from `/stats`.

| Workload | Concurrency | Req/s | p50 | p95 | p99 | Errors | Pool waiting |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| health (no DB) | 10 | 24,605 | 0.3 | 0.5 | 1.9 | 0 | — |
| health (no DB) | 50 | 24,076 | 1.8 | 4.0 | 6.5 | 0 | — |
| health (no DB) | 100 | 23,103 | 3.9 | 8.1 | 9.0 | 0 | — |
| health (no DB) | 300 | 20,575 | 13.1 | 19.7 | 22.9 | 0 | — |
| primary-key lookup | 10 | 14,457 | 0.6 | 1.1 | 2.4 | 0 | 0 |
| primary-key lookup | 50 | 16,064 | 2.8 | 5.8 | 7.7 | 0 | 16 |
| primary-key lookup | 100 | 16,280 | 5.7 | 10.0 | 11.7 | 0 | 74 |
| primary-key lookup | 300 | 15,515 | 18.3 | 25.6 | 32.1 | 0 | 271 |
| filtered + ordered search | 10 | 2,382 | 3.8 | 6.4 | 7.9 | 0 | 0 |
| filtered + ordered search | 50 | 2,725 | 17.6 | 25.2 | 31.1 | 0 | 30 |
| filtered + ordered search | 100 | 2,747 | 35.5 | 44.2 | 50.9 | 0 | 80 |
| filtered + ordered search | 300 | 2,687 | 109.1 | 125.5 | 173.6 | 0 | 280 |

What the numbers show:

- **Throughput plateaus as soon as the 20-connection pool saturates.** Primary-key lookups level off at about 16k req/s from concurrency 50; beyond that, extra concurrency only adds queueing (up to 271 waiting queries) and p95 grows from 1.1 ms to 25.6 ms with no gain in throughput. CPU was not measured in this run, so the next step is to separate pool size from process CPU.
- **Query shape matters more than concurrency.** The filtered and ordered search peaks around 2.7k req/s, about 6x below the primary-key lookup, because `EXPLAIN ANALYZE` shows each request reading all 33,333 rows for the city through a bitmap scan and then running a top-N sort to return 20 (about 4.8 ms inside PostgreSQL). More concurrency raises p95 to 125 ms without raising throughput. The next experiment is a composite index on `(city, nightly_price, id)`.
- **No errors at any level:** the system degrades by queueing, not by failing, so latency is the signal to watch.

Booking invariant (same run): 50 concurrent requests for the same unit and dates were sent in 83 ms; exactly 1 returned 201 and 49 returned 409.

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
