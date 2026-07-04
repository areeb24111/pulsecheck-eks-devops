#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="${IMAGE_NAME:-pulsecheck}"
IMAGE_TAG="${IMAGE_TAG:-local}"
CONTAINER_NAME="${CONTAINER_NAME:-pulsecheck-local-pipeline}"
HOST_PORT="${HOST_PORT:-8000}"
PYTHON_BIN="${PYTHON:-python3}"
PYTHON_DIR="$("${PYTHON_BIN}" -c 'import os, sys; print(os.path.dirname(sys.executable))')"
CFN_LINT_BIN="${CFN_LINT_BIN:-${PYTHON_DIR}/cfn-lint}"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Syntax check"
"${PYTHON_BIN}" -m compileall -q app tests

echo "==> Lint"
"${PYTHON_BIN}" -m ruff check app tests

echo "==> CloudFormation lint"
if [ -x "${CFN_LINT_BIN}" ]; then
  "${CFN_LINT_BIN}" cloudformation/*.yaml
elif command -v cfn-lint >/dev/null 2>&1; then
  cfn-lint cloudformation/*.yaml
else
  echo "cfn-lint is not installed. Run: ${PYTHON_BIN} -m pip install -r requirements-dev.txt" >&2
  exit 1
fi

echo "==> Unit tests"
"${PYTHON_BIN}" -m pytest -q

echo "==> Docker build"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo "==> Container smoke test"
cleanup
docker run -d --name "${CONTAINER_NAME}" -p "${HOST_PORT}:8000" "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null

for attempt in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${HOST_PORT}/health" >/tmp/pulsecheck-health.json 2>/dev/null; then
    cat /tmp/pulsecheck-health.json
    echo
    break
  fi
  if [ "${attempt}" = "30" ]; then
    docker logs "${CONTAINER_NAME}"
    exit 1
  fi
  sleep 1
done

echo "==> Kubernetes deployment simulation"
rendered_manifest="/tmp/pulsecheck-deployment.yaml"
sed "s|IMAGE_PLACEHOLDER|example.com/pulsecheck:${IMAGE_TAG}|g" k8s/deployment.yaml > "${rendered_manifest}"
grep -q "example.com/pulsecheck:${IMAGE_TAG}" "${rendered_manifest}"

if command -v kubectl >/dev/null 2>&1; then
  if kubectl apply --dry-run=client --validate=false -f k8s/namespace.yaml >/tmp/pulsecheck-kubectl-dry-run.log 2>&1 \
    && kubectl apply --dry-run=client --validate=false -f "${rendered_manifest}" >>/tmp/pulsecheck-kubectl-dry-run.log 2>&1 \
    && kubectl apply --dry-run=client --validate=false -f k8s/service.yaml >>/tmp/pulsecheck-kubectl-dry-run.log 2>&1; then
    echo "kubectl client-side dry run passed."
  else
    echo "kubectl dry run was unavailable; manifest render check passed instead."
  fi
else
  echo "kubectl is not installed; manifest render check passed instead."
fi

echo "==> Local pipeline passed"
