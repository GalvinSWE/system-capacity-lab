#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  docker compose down >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '\n[1/6] Install dependencies from the lock file\n'
npm ci

printf '\n[2/6] Build images and start the full stack\n'
docker compose up -d --build --wait

printf '\n[3/6] Double-booking invariant test\n'
# Compose exposes the apps through the load balancer on 4080, not on 4000.
BASE_URL=http://127.0.0.1:4080 npm run test:concurrency

printf '\n[4/6] Test API Gateway\n'
npm run test:gateway

printf '\n[5/6] Application and gateway failover tests\n'
npm run test:failover
npm run test:gateway-failover

printf '\n[6/6] Final state\n'
docker compose ps

printf '\nCI LOCAL PASS: Azure Pipelines runs the same steps automatically.\n'
