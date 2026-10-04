#!/usr/bin/env bash
set -euo pipefail

PROXY_URL="http://127.0.0.1:4080/health"

request_instances() {
  local count="$1"
  for ((number = 1; number <= count; number++)); do
    curl --fail --silent --show-error "$PROXY_URL"
    printf '\n'
  done
}

printf '\n=== Trước khi có sự cố: request được chia cho hai instance ===\n'
before="$(request_instances 10)"
printf '%s\n' "$before"

if ! grep -q 'app-a' <<<"$before" || ! grep -q 'app-b' <<<"$before"; then
  printf 'FAIL: chưa quan sát được cả app-a và app-b\n' >&2
  exit 1
fi

printf '\n=== Giả lập app-a bị sập ===\n'
docker compose stop app-a >/dev/null

after="$(request_instances 10)"
printf '%s\n' "$after"

if grep -q 'app-a' <<<"$after" || ! grep -q 'app-b' <<<"$after"; then
  printf 'FAIL: traffic chưa failover hoàn toàn sang app-b\n' >&2
  docker compose start app-a >/dev/null
  exit 1
fi

printf 'PASS: app-a sập nhưng 10/10 request vẫn được app-b phục vụ\n'

printf '\n=== Khởi động lại app-a ===\n'
docker compose start app-a >/dev/null

for attempt in {1..20}; do
  status="$(docker compose ps --format json app-a 2>/dev/null || true)"
  if grep -q 'healthy' <<<"$status"; then
    break
  fi
  sleep 1
done

# Nginx bản lab dùng DNS tĩnh khi khởi động. Reload để nó resolve lại
# instance vừa quay lại, tương đương bước load balancer đưa node healthy vào pool.
docker compose exec -T load-balancer nginx -s reload >/dev/null
sleep 2

recovered="$(request_instances 20)"
printf '%s\n' "$recovered"

if ! grep -q 'app-a' <<<"$recovered" || ! grep -q 'app-b' <<<"$recovered"; then
  printf 'FAIL: app-a chưa tham gia lại sau recovery\n' >&2
  exit 1
fi

printf 'PASS: app-a phục hồi và tham gia nhận traffic trở lại\n'
