#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/terraform"

APP_URL="$(terraform -chdir="$TF_DIR" output -raw application_url)"
APP="$(terraform -chdir="$TF_DIR" output -raw application_container)"
REDIS="$(terraform -chdir="$TF_DIR" output -raw redis_container)"
NETWORK="$(terraform -chdir="$TF_DIR" output -raw network_name)"
VOLUME="$(terraform -chdir="$TF_DIR" output -raw redis_volume_name)"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

wait_for_application() {
    for attempt in $(seq 1 30); do
        if curl -fsS --max-time 3 "$APP_URL/health" >/dev/null 2>&1; then
            return 0
        fi

        sleep 1
    done

    fail "Application did not become healthy."
}

read_counter() {
    curl -fsS --max-time 5 "$APP_URL/count" |
        python3 -c 'import json, sys; print(json.load(sys.stdin)["visits"])'
}

redis_mount() {
    docker inspect \
        --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' \
        "$REDIS"
}

verify_topology() {
    local members

    members="$(docker network inspect \
        --format '{{range .Containers}}{{println .Name}}{{end}}' \
        "$NETWORK")"

    [[ "$(grep -cve '^$' <<< "$members")" -eq 2 ]] ||
        fail "The network does not contain exactly two containers."

    grep -Fxq "$APP" <<< "$members" ||
        fail "Flask container is missing from the custom network."

    grep -Fxq "$REDIS" <<< "$members" ||
        fail "Redis container is missing from the custom network."

    [[ "$(redis_mount)" == "$VOLUME" ]] ||
        fail "Redis is not using the expected named volume."

    [[ "$(docker inspect \
        --format '{{len .HostConfig.PortBindings}}' "$REDIS")" == "0" ]] ||
        fail "Redis has a published host port."

    printf 'PASS: Exactly two containers share network %s.\n' "$NETWORK"
    printf 'PASS: Redis uses volume %s.\n' "$VOLUME"
    printf 'PASS: Redis has no published host port.\n'
}

verify_application() {
    printf '\n========== APPLICATION VERIFICATION ==========\n'

    wait_for_application
    verify_topology

    printf '\n[1] Application health\n'
    curl -fsS "$APP_URL/health"
    printf '\nPASS: Application health check succeeded.\n'

    printf '\n[2] Container-to-container communication\n'
    docker exec "$APP" python -c '
import os
import socket
from redis import Redis

host = os.environ["REDIS_HOST"]
port = int(os.environ["REDIS_PORT"])

print(f"Redis hostname: {host}")
print(f"Resolved address: {socket.gethostbyname(host)}")

client = Redis(host=host, port=port, socket_connect_timeout=2)
assert client.ping()
print("PASS: Flask container communicated with Redis.")
'

    printf '\n[3] Redis persistence configuration\n'

    appendonly="$(docker exec "$REDIS" \
        redis-cli --raw CONFIG GET appendonly | tail -n 1)"

    appendfsync="$(docker exec "$REDIS" \
        redis-cli --raw CONFIG GET appendfsync | tail -n 1)"

    [[ "$appendonly" == "yes" ]] ||
        fail "Append-only persistence is disabled."

    [[ "$appendfsync" == "always" ]] ||
        fail "Unexpected appendfsync configuration."

    printf 'appendonly: %s\n' "$appendonly"
    printf 'appendfsync: %s\n' "$appendfsync"
    printf 'PASS: Append-only persistence is enabled.\n'

    printf '\n[4] Visit counter verification\n'

    before="$(read_counter)"
    printf 'Initial counter: %s\n' "$before"

    for request in $(seq 1 5); do
        response="$(curl -fsS --max-time 5 "$APP_URL/")"

        actual="$(python3 -c \
            'import json, sys; print(json.load(sys.stdin)["visits"])' \
            <<< "$response")"

        expected="$((before + request))"

        [[ "$actual" -eq "$expected" ]] ||
            fail "Visit counter returned an unexpected value."

        printf 'Request %s: %s\n' "$request" "$response"
    done

    printf 'PASS: All five counter increments were correct.\n'

    printf '\n[5] Persistent data files\n'
    docker exec "$REDIS" ls -l /data/appendonlydir

    printf '\n========== ALL APPLICATION TESTS PASSED ==========\n'
}

verify_recovery() {
    printf '\n========== DATABASE RECOVERY TEST ==========\n'

    wait_for_application
    verify_topology

    before="$(read_counter)"

    [[ "$before" -gt 0 ]] ||
        fail "Run the application verification before the recovery test."

    old_id="$(docker inspect --format '{{.Id}}' "$REDIS")"
    old_volume="$(redis_mount)"

    project_label="$(docker inspect \
        --format '{{index .Config.Labels "com.cis4930.project"}}' \
        "$REDIS")"

    [[ "$project_label" == "assignment5" ]] ||
        fail "The Redis container does not belong to Assignment 5."

    printf 'Counter before replacement: %s\n' "$before"
    printf 'Original Redis container ID: %s\n' "$old_id"
    printf 'Persistent volume: %s\n' "$old_volume"

    printf '\n[1] Remove the Redis container\n'
    docker rm -f "$old_id"

    printf '\n[2] Reconcile infrastructure using Terraform\n'
    terraform -chdir="$TF_DIR" apply -auto-approve -no-color

    printf '\n[3] Verify recovered infrastructure\n'
    wait_for_application
    verify_topology

    new_id="$(docker inspect --format '{{.Id}}' "$REDIS")"
    new_volume="$(redis_mount)"
    after="$(read_counter)"

    printf 'Replacement Redis container ID: %s\n' "$new_id"
    printf 'Persistent volume after replacement: %s\n' "$new_volume"
    printf 'Counter after replacement: %s\n' "$after"

    [[ "$old_id" != "$new_id" ]] ||
        fail "The Redis container was not replaced."

    [[ "$old_volume" == "$new_volume" ]] ||
        fail "Redis is using a different volume."

    [[ "$before" -eq "$after" ]] ||
        fail "The visit counter was not preserved."

    printf 'PASS: Redis container was successfully recreated.\n'
    printf 'PASS: The original named volume was retained.\n'
    printf 'PASS: Counter value was preserved without data loss.\n'

    printf '\n[4] Verify operation after recovery\n'

    response="$(curl -fsS --max-time 5 "$APP_URL/")"

    updated="$(python3 -c \
        'import json, sys; print(json.load(sys.stdin)["visits"])' \
        <<< "$response")"

    [[ "$updated" -eq "$((after + 1))" ]] ||
        fail "Counter did not increment correctly after recovery."

    printf 'Counter after new request: %s\n' "$updated"
    printf 'PASS: Application remains operational after recovery.\n'

    printf '\n========== DATABASE RECOVERY TEST PASSED ==========\n'
}

case "${1:-verify}" in
    verify)
        verify_application
        ;;
    recover)
        verify_recovery
        ;;
    *)
        printf 'Usage: %s [verify|recover]\n' "$0" >&2
        exit 2
        ;;
esac
