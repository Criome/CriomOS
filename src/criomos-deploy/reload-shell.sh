#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: criomos-reload-shell <cluster> <node> <user>"
  echo "       criomos-reload-shell <user>"
  echo ""
  echo "Restart noctalia-shell in a user's Wayland session."
  echo "With one arg, runs locally for that user."
  echo ""
  echo "Examples:"
  echo "  criomos-reload-shell maisiliym zeus bird"
  echo "  criomos-reload-shell li"
  exit 1
}

[ $# -lt 1 ] && usage

if [ $# -ge 3 ]; then
  CLUSTER="$1"
  NODE="$2"
  TARGET_USER="$3"
  HOST="${NODE}.${CLUSTER}.criome"
  run() { ssh root@"${HOST}" "$@"; }
elif [ $# -eq 1 ]; then
  TARGET_USER="$1"
  run() { eval "$@"; }
else
  usage
fi

UID_NUM=$(run "id -u ${TARGET_USER}")
RUNTIME="/run/user/${UID_NUM}"

run "kill \$(pgrep -u ${TARGET_USER} quickshell) 2>/dev/null" || true
sleep 1
run "su - ${TARGET_USER} -c 'WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=${RUNTIME} noctalia-shell &'"

echo "Reloaded ${TARGET_USER}'s shell"
