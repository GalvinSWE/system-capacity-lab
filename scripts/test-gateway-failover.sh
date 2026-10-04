#!/usr/bin/env bash
set -euo pipefail

PUBLIC_URL="http://127.0.0.1:4090/api/health"

gateway_for_request() {
  curl --fail --silent --show-error --dump-header - --output /dev/null \
    "$PUBLIC_URL" \
    | tr -d '\r' \
    | awk -F': ' 'tolower($1) == "x-gateway-instance" {print $2}'
}

request_gateways() {
  local count="$1"
  for ((number = 1; number <= count; number++)); do
    gateway_for_request
  done
}

printf '\n=== Trước sự cố: cả hai Gateway nhận traffic ===\n'
before="$(request_gateways 10)"
printf '%s\n' "$before"

if ! grep -q '^gateway-a$' <<<"$before" || ! grep -q '^gateway-b$' <<<"$before"; then
  printf 'FAIL: chưa quan sát được cả gateway-a và gateway-b\n' >&2
  exit 1
fi

printf '\n=== Giả lập gateway-a bị sập ===\n'
docker compose stop gateway-a >/dev/null

after="$(request_gateways 10)"
printf '%s\n' "$after"

if grep -q '^gateway-a$' <<<"$after" || ! grep -q '^gateway-b$' <<<"$after"; then
  printf 'FAIL: traffic chưa chuyển hoàn toàn sang gateway-b\n' >&2
  docker compose start gateway-a >/dev/null
  exit 1
fi

printf 'PASS: gateway-a sập nhưng 10/10 request vẫn qua gateway-b\n'

printf '\n=== Khởi động và đưa gateway-a trở lại pool ===\n'
docker compose start gateway-a >/dev/null

for attempt in {1..20}; do
  status="$(docker compose ps --format json gateway-a 2>/dev/null || true)"
  if grep -q 'healthy' <<<"$status"; then
    break
  fi
  sleep 1
done

docker compose exec -T public-entry nginx -s reload >/dev/null
sleep 2

recovered="$(request_gateways 20)"
printf '%s\n' "$recovered"

if ! grep -q '^gateway-a$' <<<"$recovered" || ! grep -q '^gateway-b$' <<<"$recovered"; then
  printf 'FAIL: gateway-a chưa tham gia lại sau recovery\n' >&2
  exit 1
fi

printf 'PASS: gateway-a phục hồi và cả hai Gateway tiếp tục chia traffic\n'
