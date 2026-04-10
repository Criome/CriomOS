#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: criomos-deploy <cluster> <node> [--boot] [--commit <hash>]"
  echo ""
  echo "Build fullOs on <node>, set system profile, and activate."
  echo ""
  echo "  --boot     Set boot entry only, don't activate (for kernel changes)"
  echo "  --commit   Build specific commit (default: current main)"
  echo ""
  echo "Examples:"
  echo "  criomos-deploy maisiliym zeus"
  echo "  criomos-deploy maisiliym zeus --boot"
  echo "  criomos-deploy maisiliym prometheus --commit abc123"
  exit 1
}

[ $# -lt 2 ] && usage

CLUSTER="$1"; shift
NODE="$1"; shift
MODE="switch"
COMMIT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --boot)   MODE="boot"; shift ;;
    --commit) COMMIT="$2"; shift 2 ;;
    *)        usage ;;
  esac
done

REPO="github:criome/CriomOS"

if [ -z "$COMMIT" ]; then
  COMMIT=$(jj log -r main -T 'commit_id' --no-graph 2>/dev/null)
fi

REF="${REPO}/${COMMIT}"
ATTR="${REF}#crioZones.${CLUSTER}.${NODE}.fullOs"
HOST="${NODE}.${CLUSTER}.criome"

echo "Deploying ${CLUSTER}/${NODE} from ${COMMIT:0:12} (${MODE})..."
ssh root@"${HOST}" \
  "nix build ${ATTR} --no-write-lock-file -o /tmp/criomos-deploy \
   && nix-env -p /nix/var/nix/profiles/system --set \$(readlink /tmp/criomos-deploy) \
   && \$(readlink /tmp/criomos-deploy)/bin/switch-to-configuration ${MODE}"

echo "Done: ${CLUSTER}/${NODE} ${MODE}"
