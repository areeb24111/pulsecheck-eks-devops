#!/usr/bin/env bash
set -Eeuo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
PROJECT_NAME="${PROJECT_NAME:-pulsecheck}"
CLUSTER_NAME="${CLUSTER_NAME:-pulsecheck-eks}"
ECR_STACK_NAME="${ECR_STACK_NAME:-${PROJECT_NAME}-ecr}"
K8S_NAMESPACE="${K8S_NAMESPACE:-pulsecheck}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short=12 HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd aws
require_cmd docker
require_cmd kubectl

REPOSITORY_URI="$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${ECR_STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='RepositoryUri'].OutputValue" \
  --output text)"

if [ -z "${REPOSITORY_URI}" ] || [ "${REPOSITORY_URI}" = "None" ]; then
  echo "Could not resolve ECR repository URI from stack ${ECR_STACK_NAME}." >&2
  exit 1
fi

IMAGE_URI="${REPOSITORY_URI}:${IMAGE_TAG}"
REGISTRY="${REPOSITORY_URI%%/*}"

echo "==> Logging in to ECR"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY}"

echo "==> Building and pushing ${IMAGE_URI} for ${DOCKER_PLATFORM}"
docker build --platform "${DOCKER_PLATFORM}" -t "${IMAGE_URI}" -t "${REPOSITORY_URI}:latest" .
docker push "${IMAGE_URI}"
docker push "${REPOSITORY_URI}:latest"

echo "==> Updating kubeconfig for ${CLUSTER_NAME}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

rendered_manifest="$(mktemp)"
trap 'rm -f "${rendered_manifest}"' EXIT
sed "s|IMAGE_PLACEHOLDER|${IMAGE_URI}|g" k8s/deployment.yaml > "${rendered_manifest}"

echo "==> Applying Kubernetes manifests"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f "${rendered_manifest}"
kubectl apply -f k8s/service.yaml
kubectl -n "${K8S_NAMESPACE}" rollout status deployment/pulsecheck --timeout=300s

echo "==> Waiting for endpoint"
./scripts/get_endpoint.sh
