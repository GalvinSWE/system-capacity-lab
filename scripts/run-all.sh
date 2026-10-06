#!/usr/bin/env bash
set -euo pipefail

printf '\n=== 1. Endpoint without database access ===\n'
npm run load:health

printf '\n=== 2. Endpoint reading one database row ===\n'
npm run load:database

printf '\n=== 3. Database search endpoint ===\n'
npm run load:search

printf '\n=== 4. 50 requests booking the same room ===\n'
npm run test:concurrency

printf '\n=== 5. Application and database state ===\n'
curl --fail --silent --show-error http://127.0.0.1:4000/stats
printf '\n'
