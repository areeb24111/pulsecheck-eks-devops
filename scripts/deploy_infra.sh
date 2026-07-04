#!/usr/bin/env bash
set -Eeuo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
PROJECT_NAME="${PROJECT_NAME:-pulsecheck}"
CLUSTER_NAME="${CLUSTER_NAME:-pulsecheck-eks}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.36}"
ECR_STACK_NAME="${ECR_STACK_NAME:-${PROJECT_NAME}-ecr}"
NETWORK_STACK_NAME="${NETWORK_STACK_NAME:-${PROJECT_NAME}-network}"
EKS_STACK_NAME="${EKS_STACK_NAME:-${PROJECT_NAME}-eks}"
CREATE_NAT_GATEWAY="${CREATE_NAT_GATEWAY:-false}"
NODE_SUBNET_TIER="${NODE_SUBNET_TIER:-public}"
NODE_INSTANCE_TYPE="${NODE_INSTANCE_TYPE:-t3.small}"
NODE_DESIRED_CAPACITY="${NODE_DESIRED_CAPACITY:-2}"
DEPLOY_PRINCIPAL_ARN="${DEPLOY_PRINCIPAL_ARN:-}"
ADDITIONAL_ADMIN_PRINCIPAL_ARN="${ADDITIONAL_ADMIN_PRINCIPAL_ARN:-}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd aws

echo "==> Deploying ECR stack ${ECR_STACK_NAME}"
aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${ECR_STACK_NAME}" \
  --template-file cloudformation/01-ecr.yaml \
  --no-fail-on-empty-changeset \
  --parameter-overrides ProjectName="${PROJECT_NAME}"

echo "==> Deploying network stack ${NETWORK_STACK_NAME}"
aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${NETWORK_STACK_NAME}" \
  --template-file cloudformation/02-network.yaml \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    ClusterName="${CLUSTER_NAME}" \
    CreateNatGateway="${CREATE_NAT_GATEWAY}"

echo "==> Deploying EKS stack ${EKS_STACK_NAME}"
aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${EKS_STACK_NAME}" \
  --template-file cloudformation/04-eks-cluster-nodegroup.yaml \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    ClusterName="${CLUSTER_NAME}" \
    KubernetesVersion="${KUBERNETES_VERSION}" \
    NetworkStackName="${NETWORK_STACK_NAME}" \
    NodeSubnetTier="${NODE_SUBNET_TIER}" \
    NodeInstanceType="${NODE_INSTANCE_TYPE}" \
    NodeDesiredCapacity="${NODE_DESIRED_CAPACITY}" \
    DeployPrincipalArn="${DEPLOY_PRINCIPAL_ARN}" \
    AdditionalAdminPrincipalArn="${ADDITIONAL_ADMIN_PRINCIPAL_ARN}"

echo "==> Infrastructure deployment complete"
aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${EKS_STACK_NAME}" \
  --query "Stacks[0].Outputs" \
  --output table
