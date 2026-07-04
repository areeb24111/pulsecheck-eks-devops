#!/usr/bin/env bash
set -Eeuo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
PROJECT_NAME="${PROJECT_NAME:-pulsecheck}"
CLUSTER_NAME="${CLUSTER_NAME:-pulsecheck-eks}"
ECR_STACK_NAME="${ECR_STACK_NAME:-${PROJECT_NAME}-ecr}"
NETWORK_STACK_NAME="${NETWORK_STACK_NAME:-${PROJECT_NAME}-network}"
EKS_STACK_NAME="${EKS_STACK_NAME:-${PROJECT_NAME}-eks}"
K8S_NAMESPACE="${K8S_NAMESPACE:-pulsecheck}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd aws

if command -v kubectl >/dev/null 2>&1; then
  aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
  kubectl -n "${K8S_NAMESPACE}" delete service pulsecheck --ignore-not-found=true || true
  kubectl -n "${K8S_NAMESPACE}" delete deployment pulsecheck --ignore-not-found=true || true
  kubectl delete namespace "${K8S_NAMESPACE}" --ignore-not-found=true || true
  echo "Waiting briefly for AWS load balancer cleanup."
  sleep 90
fi

echo "==> Deleting EKS stack ${EKS_STACK_NAME}"
aws cloudformation delete-stack --region "${AWS_REGION}" --stack-name "${EKS_STACK_NAME}" || true
aws cloudformation wait stack-delete-complete --region "${AWS_REGION}" --stack-name "${EKS_STACK_NAME}" || true

echo "==> Deleting network stack ${NETWORK_STACK_NAME}"
aws cloudformation delete-stack --region "${AWS_REGION}" --stack-name "${NETWORK_STACK_NAME}" || true
aws cloudformation wait stack-delete-complete --region "${AWS_REGION}" --stack-name "${NETWORK_STACK_NAME}" || true

echo "==> Emptying ECR repository ${PROJECT_NAME}"
if aws ecr describe-repositories --region "${AWS_REGION}" --repository-names "${PROJECT_NAME}" >/dev/null 2>&1; then
  image_ids="$(aws ecr list-images --region "${AWS_REGION}" --repository-name "${PROJECT_NAME}" --query 'imageIds[*]' --output json)"
  if [ "${image_ids}" != "[]" ]; then
    aws ecr batch-delete-image --region "${AWS_REGION}" --repository-name "${PROJECT_NAME}" --image-ids "${image_ids}" >/dev/null
  fi
fi

echo "==> Deleting ECR stack ${ECR_STACK_NAME}"
aws cloudformation delete-stack --region "${AWS_REGION}" --stack-name "${ECR_STACK_NAME}" || true
aws cloudformation wait stack-delete-complete --region "${AWS_REGION}" --stack-name "${ECR_STACK_NAME}" || true

echo "==> Cleanup requested"
