#!/bin/sh

# script that runs if the sandbox deprovison terraform destroy
# attempts to delete any and all trailing resources related to this tf module
# eks cluster
#  - node groups
# NOTE: this script is not concerned with destroying the VPC. That responsibility falls on the cloudformation stack.

set -u
set -o pipefail

# TODO: consider filtering by `sandbox.nuon.co/name = aws-eks` as well
TAG_KEY="install.nuon.co/id"
TAG_VALUE="${NUON_INSTALL_ID:-}"  # Defaults to env var
DRY_RUN="${DRY_RUN:-false}"  # Defaults to false if not set

# Usage function
usage() {
    echo "Usage: NUON_INSTALL_ID=<value> $0"
    echo "Set DRY_RUN=true in the environment for dry-run mode."
    exit 1
}

if [ -z "$TAG_VALUE" ]; then
    echo "Error: NUON_INSTALL_ID is required."
    usage
fi

# Determine dry-run behavior
if [ "$DRY_RUN" = "true" ]; then
    echo "Running in DRY-RUN mode. No resources will be deleted."
    RUN_CMD_PREFIX="echo [DRY-RUN]"
else
    RUN_CMD_PREFIX=""
fi

run_cmd() {
    $RUN_CMD_PREFIX "$@"
}

echo "Executing cleanup script"
echo "Region: $AWS_REGION"
echo "Profile: $AWS_PROFILE"
echo "Install ID: $TAG_VALUE"

aws sts get-caller-identity > /dev/null || { echo "AWS credentials not set up"; exit 1; }

# Delete EKS Clusters
#
# Delete EKS Clusters (including Node Groups)
#
echo "Fetching EKS clusters with tag $TAG_KEY=$TAG_VALUE..."
CLUSTERS=$(aws eks list-clusters --query "clusters[]" --output text --no-cli-pager)

for CLUSTER in $CLUSTERS; do
    TAGS=$(aws eks describe-cluster --name "$CLUSTER" --query "cluster.tags" --output json 2>/dev/null)
    if echo "$TAGS" | grep -q "\"$TAG_KEY\": \"$TAG_VALUE\""; then
        echo "Deleting node groups for cluster: $CLUSTER..."
        NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query "nodegroups[]" --output text)

        for NODE_GROUP in $NODE_GROUPS; do
            echo "Deleting node group: $NODE_GROUP in cluster: $CLUSTER..."
            run_cmd aws eks delete-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP" --no-cli-pager
            echo "Waiting for node group $NODE_GROUP to be deleted..."
            run_cmd aws eks wait nodegroup-deleted --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP" --no-cli-pager
        done

        echo "Deleting EKS cluster: $CLUSTER..."
        run_cmd aws eks delete-cluster --name "$CLUSTER" --no-cli-pager
        echo "Waiting for EKS cluster $CLUSTER to be deleted..."
        run_cmd aws eks wait cluster-deleted --name "$CLUSTER" --no-cli-pager
    fi
done

#
# Fetch VPCs
#
echo "Fetching VPCs with tag Name=$TAG_VALUE..."
VPC_IDS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$TAG_VALUE" | jq -r '.Vpcs[].VpcId')

if [[ -z "$VPC_IDS" ]]; then
    echo "No VPCs found for $TAG_VALUE."
    exit 0
fi

echo "Found VPCs: $VPC_IDS"

#
echo "Fetching ALBs tagged with $TAG_KEY: $TAG_VALUE..."
LB_ARNS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text --no-cli-pager)

for LB_ARN in $LB_ARNS; do
    TAGS=$(aws elbv2 describe-tags --resource-arns "$LB_ARN" --query "TagDescriptions[].Tags[]" --output json)

    if echo "$TAGS" | jq -e 'map(select(.Key == "install.nuon.co/id" and .Value == "'"$TAG_VALUE"'")) | length > 0' > /dev/null; then
        echo "Deleting Load Balancer $LB_ARN..."
        run_cmd aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" --no-cli-pager
        echo "Waiting for Load Balancer $LB_ARN to be deleted..."
        run_cmd aws elbv2 wait load-balancers-deleted --load-balancer-arns "$LB_ARN"
    fi
done

echo "ALB cleanup complete."
