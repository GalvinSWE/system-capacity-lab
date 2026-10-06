#!/usr/bin/env bash
set -euo pipefail

GATEWAY="http://127.0.0.1:4090"

printf '\n=== 1. Gateway routes /api/* to the application cluster ===\n'
application_response="$(curl --fail --silent --show-error "$GATEWAY/api/health")"
printf '%s\n' "$application_response"
grep -q 'instanceId' <<<"$application_response"

printf '\n=== 2. Gateway routes /ota/* to the separate OTA backend ===\n'
ota_response="$(curl --fail --silent --show-error "$GATEWAY/ota/status")"
printf '%s\n' "$ota_response"
grep -q 'mock-ota' <<<"$ota_response"

printf '\n=== 3. Admin route without an API key must be blocked ===\n'
unauthorized_status="$(curl --silent --output /dev/null --write-out '%{http_code}' "$GATEWAY/admin/stats")"
printf 'HTTP %s\n' "$unauthorized_status"
test "$unauthorized_status" = "401"

printf '\n=== 4. Admin route with an API key is allowed ===\n'
authorized_response="$(curl --fail --silent --show-error -H 'X-API-Key: lab-secret' "$GATEWAY/admin/stats")"
printf '%s\n' "$authorized_response"
grep -q 'application' <<<"$authorized_response"

printf '\n=== 5. Gateway adds a request ID for tracing ===\n'
request_id="$(curl --silent --dump-header - --output /dev/null "$GATEWAY/api/health" | tr -d '\r' | awk -F': ' 'tolower($1) == "x-request-id" {print $2}')"
printf 'X-Request-ID: %s\n' "$request_id"
test -n "$request_id"

printf '\n=== 6. Burst of 20 requests through the rate-limited route ===\n'
temp_dir="$(mktemp -d)"
cleanup() { rm -rf "$temp_dir"; }
trap cleanup EXIT

for number in {1..20}; do
  curl --silent --output /dev/null --write-out '%{http_code}' \
    "$GATEWAY/limited/health" >"$temp_dir/$number" &
done
wait

success_count="$(grep -l '^200$' "$temp_dir"/* | wc -l | tr -d ' ')"
limited_count="$(grep -l '^429$' "$temp_dir"/* | wc -l | tr -d ' ')"
printf 'HTTP 200: %s request\n' "$success_count"
printf 'HTTP 429: %s requests were rate limited\n' "$limited_count"
test "$limited_count" -gt 0

printf '\nPASS: routing, API-key policy, request ID and rate limiting all work\n'
