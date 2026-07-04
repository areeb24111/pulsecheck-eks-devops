#!/usr/bin/env bash
set -Eeuo pipefail

K8S_NAMESPACE="${K8S_NAMESPACE:-pulsecheck}"
SERVICE_NAME="${SERVICE_NAME:-pulsecheck}"
WAIT_SECONDS="${WAIT_SECONDS:-600}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd kubectl

deadline=$((SECONDS + WAIT_SECONDS))
while [ "${SECONDS}" -lt "${deadline}" ]; do
  hostname="$(kubectl -n "${K8S_NAMESPACE}" get service "${SERVICE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  ip="$(kubectl -n "${K8S_NAMESPACE}" get service "${SERVICE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

  if [ -n "${hostname}" ]; then
    echo "Live URL: http://${hostname}/health"
    exit 0
  fi

  if [ -n "${ip}" ]; then
    echo "Live URL: http://${ip}/health"
    exit 0
  fi

  sleep 10
done

kubectl -n "${K8S_NAMESPACE}" get service "${SERVICE_NAME}" -o wide
echo "Timed out waiting for a load balancer endpoint." >&2
exit 1
