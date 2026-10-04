#!/usr/bin/env bash
set -euo pipefail

printf '\n=== 1. Endpoint không dùng database ===\n'
npm run load:health

printf '\n=== 2. Endpoint đọc một bản ghi database ===\n'
npm run load:database

printf '\n=== 3. Endpoint tìm kiếm database ===\n'
npm run load:search

printf '\n=== 4. 50 request cùng đặt một phòng ===\n'
npm run test:concurrency

printf '\n=== 5. Trạng thái application và database ===\n'
curl --fail --silent --show-error http://127.0.0.1:4000/stats
printf '\n'
