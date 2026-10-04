#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  docker compose down >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '\n[1/6] Cài dependencies theo lock file\n'
npm ci

printf '\n[2/6] Build image và khởi động toàn hệ thống\n'
docker compose up -d --build --wait

printf '\n[3/6] Test chống double booking\n'
npm run test:concurrency

printf '\n[4/6] Test API Gateway\n'
npm run test:gateway

printf '\n[5/6] Test failover application và Gateway\n'
npm run test:failover
npm run test:gateway-failover

printf '\n[6/6] Trạng thái cuối\n'
docker compose ps

printf '\nCI LOCAL PASS — cùng chuỗi bước sẽ được Azure Pipelines chạy tự động.\n'
