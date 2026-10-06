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

printf '\n=== Before the failure: requests are spread across both instances ===\n'
before="$(request_instances 10)"
printf '%s\n' "$before"

if ! grep -q 'app-a' <<<"$before" || ! grep -q 'app-b' <<<"$before"; then
  printf 'FAIL: did not observe both app-a and app-b\n' >&2
  exit 1
fi

printf '\n=== Simulating an app-a outage ===\n'
docker compose stop app-a >/dev/null

after="$(request_instances 10)"
printf '%s\n' "$after"

if grep -q 'app-a' <<<"$after" || ! grep -q 'app-b' <<<"$after"; then
  printf 'FAIL: traffic did not fully fail over to app-b\n' >&2
  docker compose start app-a >/dev/null
  exit 1
fi

printf 'PASS: app-a is down and app-b still served 10/10 requests\n'

printf '\n=== Restarting app-a ===\n'
docker compose start app-a >/dev/null

for attempt in {1..20}; do
  status="$(docker compose ps --format json app-a 2>/dev/null || true)"
  if grep -q 'healthy' <<<"$status"; then
    break
  fi
  sleep 1
done

# The lab's nginx resolves DNS once at startup. Reload it so it resolves
# the recovered instance again, like a load balancer returning a healthy node to the pool.
docker compose exec -T load-balancer nginx -s reload >/dev/null
sleep 2

recovered="$(request_instances 20)"
printf '%s\n' "$recovered"

if ! grep -q 'app-a' <<<"$recovered" || ! grep -q 'app-b' <<<"$recovered"; then
  printf 'FAIL: app-a did not rejoin after recovery\n' >&2
  exit 1
fi

printf 'PASS: app-a recovered and is receiving traffic again\n'
