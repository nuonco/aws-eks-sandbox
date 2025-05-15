#!/bin/sh

# script that runs if tf fails: attempts to delete any and all trailing resources

set -u
set -o pipefail

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
echo "Fetching ALBs tagged with nuon_install_id=$TAG_VALUE..."
LB_ARNS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text --no-cli-pager)

for LB_ARN in $LB_ARNS; do
    TAGS=$(aws elbv2 describe-tags --resource-arns "$LB_ARN" --query "TagDescriptions[].Tags[]" --output json)

    if echo "$TAGS" | jq -e 'map(select(.Key == "nuon_install_id" and .Value == "'"$TAG_VALUE"'")) | length > 0' > /dev/null; then
        echo "Deleting Load Balancer $LB_ARN..."
        run_cmd aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" --no-cli-pager
        echo "Waiting for Load Balancer $LB_ARN to be deleted..."
        run_cmd aws elbv2 wait load-balancers-deleted --load-balancer-arns "$LB_ARN"
    fi
done

echo "ALB cleanup complete."
#
# Delete NAT Gateways before ENIs
#
echo "Looking for NAT Gateways..."
aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=$TAG_VALUE*" | jq -r '.NatGateways[].NatGatewayId' | while read -r nat_gateway_id; do
    echo "Deleting NAT Gateway $nat_gateway_id"
    run_cmd aws ec2 delete-nat-gateway --nat-gateway-id "$nat_gateway_id" --no-cli-pager
    echo "Waiting for NAT Gateway $nat_gateway_id to be deleted..."
    run_cmd aws ec2 wait nat-gateway-available --nat-gateway-ids "$nat_gateway_id"
done

#
# VPC Cleanup: Resources
#
delete_vpc_resources() {
    local vpc_id="$1"
    echo "[ $vpc_id ] Cleaning up resources..."

    # Delete Network Interfaces (ENIs)
    echo "Looking for Network Interfaces in VPC $vpc_id..."
    aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" | jq -r '.NetworkInterfaces[].NetworkInterfaceId' | while read -r eni_id; do
        echo " - Deleting ENI $eni_id"
        run_cmd aws ec2 delete-network-interface --network-interface-id "$eni_id" --no-cli-pager
    done

    # Delete Security Groups
    aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" | jq -c '.SecurityGroups[]' | while read -r sg; do
        sg_id=$(echo "$sg" | jq -r '.GroupId')

        aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$sg_id" | jq -c '.SecurityGroupRules[]' | while read -r rule; do
            rule_id=$(echo "$rule" | jq -r '.SecurityGroupRuleId')
            direction=$(echo "$rule" | jq -r '.IsEgress')
            if [[ "$direction" == "true" ]]; then
                run_cmd aws ec2 revoke-security-group-egress --group-id "$sg_id" --security-group-rule-ids "$rule_id" --no-cli-pager
            else
                run_cmd aws ec2 revoke-security-group-ingress --group-id "$sg_id" --security-group-rule-ids "$rule_id" --no-cli-pager
            fi
        done

        echo " - Deleting security group $sg_id"
        run_cmd aws ec2 delete-security-group --group-id "$sg_id" --no-cli-pager
    done

    # Delete Internet Gateways
    aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" | jq -r '.InternetGateways[].InternetGatewayId' | while read -r ig_id; do
        run_cmd aws ec2 detach-internet-gateway --internet-gateway-id "$ig_id" --vpc-id "$vpc_id"
        run_cmd aws ec2 delete-internet-gateway --internet-gateway-id "$ig_id" --no-cli-pager
    done

    # Delete Subnets
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" | jq -r '.Subnets[].SubnetId' | while read -r sn_id; do
        run_cmd aws ec2 delete-subnet --subnet-id "$sn_id" --no-cli-pager
    done

    # Delete Route Tables
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" | jq -r '.RouteTables[].RouteTableId' | while read -r rt_id; do
        run_cmd aws ec2 delete-route-table --route-table-id "$rt_id" --no-cli-pager
    done
}

# Iterate over all VPCs and delete resources
for vpc_id in $VPC_IDS; do
    delete_vpc_resources "$vpc_id"
done

#
# Final VPC Cleanup
#
for vpc_id in $VPC_IDS; do
    echo "Deleting VPC $vpc_id"
    run_cmd aws ec2 delete-vpc --vpc-id "$vpc_id" --no-cli-pager
done

echo "Cleanup complete."
