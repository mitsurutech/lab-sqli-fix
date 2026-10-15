#!/usr/bin/env bash
# What the README promises, checked from inside the lab's own network: run by check.sh with
# 1 for the weak code and 2 for the fixed code. It types what a student types.
set -euo pipefail
: "${NET:?run through test/check.sh}"
phase=${1:?1 weak, 2 fixed}
probe() { docker run --rm --network "$NET" lab-check-probe bash -c "$1"; }
# The restart is asked for before this runs; wait for the shop to answer again.
for _ in $(seq 1 30); do
  probe 'curl -fs -o /dev/null "http://app:8000/search?q=Pen"' 2>/dev/null && break
  sleep 1
done
echo "- a normal search finds the pen and not the products that are not for sale"
probe '
set -eu
out=$(curl -fs -G --data-urlencode "q=pen" http://app:8000/search)
echo "$out" | grep -q "^Pen " || { echo "no pen in: $out" >&2; exit 1; }
[ "$(echo "$out" | wc -l)" = 1 ] || { echo "more than the pen in: $out" >&2; exit 1; }
'
echo "- a search for a name with an apostrophe in it"
probe '
b=http://app:8000/search
out=$(curl -s -G --data-urlencode "q=Baker'"'"'s" $b)
if [ '"$phase"' = 1 ]; then
  echo "$out" | grep -q "database error" || { echo "expected a database error, got: $out" >&2; exit 1; }
else
  echo "$out" | grep -q "^Baker'"'"'s apron " || { echo "the apron was not found: $out" >&2; exit 1; }
fi
'
echo "- an injected OR and an injected UNION"
probe '
b=http://app:8000/search
or=$(curl -s -G --data-urlencode "q=x'"'"' OR 1=1 --" $b)
un=$(curl -s -G --data-urlencode "q=x'"'"' UNION SELECT username, password FROM users --" $b)
if [ '"$phase"' = 1 ]; then
  echo "$or" | grep -q "Staff discount card" || { echo "the OR did not return everything: $or" >&2; exit 1; }
  echo "$or" | grep -q "Unreleased drone" || { echo "the OR did not return everything: $or" >&2; exit 1; }
  echo "$un" | grep -q "admin  hunter2" || { echo "the UNION did not return the users: $un" >&2; exit 1; }
else
  echo "$or" | grep -q "Staff discount card" && { echo "the OR still works: $or" >&2; exit 1; }
  echo "$un" | grep -q "hunter2" && { echo "the UNION still works: $un" >&2; exit 1; }
  true
fi
'
echo "- the lab's own check agrees"
if [ "$phase" = 1 ]; then
  ! docker exec "$APP" sh /tmp/app/lab-check >/dev/null || { echo "lab-check passed on the weak code" >&2; exit 1; }
else
  docker exec "$APP" sh /tmp/app/lab-check | tail -1 | grep -q "All checks pass" || { echo "lab-check fails on the fixed code" >&2; exit 1; }
fi
echo "  ok"
