#!/usr/bin/env bash
# Starts the lab the way the platform runs it and plays a student through it: the attacks
# work on the weak code, the fix is made inside the running container, the attacks then fail,
# normal use still works, the fix survives the lab being stopped and started, and the weak
# code can be put back.
#   test/check.sh
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
project="lab-check"
override="$root/test/hardened.generated.yaml"

# Every service gets the hardening, and memory-swap equal to its memory limit.
services=$(docker compose -f "$root/compose.yaml" config --services)
{
  cat "$root/test/hardened.yaml"
  echo "services:"
  for s in $services; do
    mem=$(docker compose -f "$root/compose.yaml" config --format json \
      | python3 -c "import json,sys; d=json.load(sys.stdin)['services']['$s']; print(((d.get('deploy') or {}).get('resources') or {}).get('limits',{}).get('memory') or 536870912)")
    printf '  %s:\n    <<: *hardened\n    hostname: %s\n    memswap_limit: %s\n' "$s" "$s" "$mem"
  done
} > "$override"

compose() { docker compose -p "$project" -f "$root/compose.yaml" -f "$override" "$@"; }
cleanup() { docker compose -p "$project" down -v --remove-orphans >/dev/null 2>&1 || true; rm -f "$override"; }
trap cleanup EXIT
docker compose -p "$project" down -v --remove-orphans >/dev/null 2>&1 || true

# local.yaml, the file the README tells you to run on your own machine, is valid beside it.
docker compose -f "$root/compose.yaml" -f "$root/local.yaml" config --quiet

docker build -q -t lab-check-probe -f "$root/test/Dockerfile.probe" "$root/test" >/dev/null
compose up -d --wait --wait-timeout 300

# The hardening really took: a check that ran without it proves nothing.
for c in $(compose ps -q); do
  docker inspect "$c" --format '{{.Name}} {{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}} {{.HostConfig.PidsLimit}} {{.HostConfig.Memory}}={{.HostConfig.MemorySwap}}' \
    | tee /dev/stderr | grep -q '\[ALL\] \[no-new-privileges\] 256 \([0-9]*\)=\1$' || { echo "not hardened" >&2; exit 1; }
done
NET="${project}_lab" APP="$(compose ps -q app)" bash "$root/test/lab.sh" 1
echo "- the fix is made inside the running container and the shop is restarted"
docker exec "$(compose ps -q app)" sed -i 's|^    rows = .*|    rows = db.execute("SELECT name, price FROM products WHERE public = 1 AND name LIKE ?", ("%" + term + "%",)).fetchall()|' /tmp/app/app.py
docker restart "$(compose ps -q app)" >/dev/null
NET="${project}_lab" APP="$(compose ps -q app)" bash "$root/test/lab.sh" 2
echo "- the lab is stopped and started again and the fix is still there"
compose down --remove-orphans >/dev/null
compose up -d --wait --wait-timeout 300
NET="${project}_lab" APP="$(compose ps -q app)" bash "$root/test/lab.sh" 2
echo "- starting again from the weak code"
docker exec "$(compose ps -q app)" rm /tmp/app/app.py
docker restart "$(compose ps -q app)" >/dev/null
NET="${project}_lab" APP="$(compose ps -q app)" bash "$root/test/lab.sh" 1
echo "ok"
