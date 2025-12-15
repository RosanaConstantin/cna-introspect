#!/bin/bash
set -e

echo "🔥 FORCE CLEANUP - AWS Stack"
echo "============================"

AWS_REGION="us-east-1"
CLUSTER_NAME="dapr-microservices-cluster"
AWS_PROFILE="org-demo"
echo "Using AWS Profile: $AWS_PROFILE"
export AWS_PROFILE=$AWS_PROFILE

# Get account ID from org-demo profile
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text 2>/dev/null) || {
    echo "❌ AWS profile $AWS_PROFILE not configured"
    exit 1
}

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

# 1. Force delete all CloudFormation stacks
echo "1. Force deleting ALL related CloudFormation stacks..."
STACKS=$(aws cloudformation list-stacks --region $AWS_REGION --query 'StackSummaries[?contains(StackName, `dapr-microservices`) && StackStatus != `DELETE_COMPLETE`].StackName' --output text)

if [ -n "$STACKS" ]; then
    for stack in $STACKS; do
        echo "   Deleting stack: $stack"
        aws cloudformation delete-stack --stack-name $stack --region $AWS_REGION || true
    done
    
    echo "   Waiting for deletions..."
    sleep 30
else
    echo "   No stacks found"
fi

# 2. Force delete EKS cluster
echo ""
echo "2. Force deleting EKS cluster..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &>/dev/null; then
    eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION --force --wait || {
        echo "   eksctl failed, trying direct deletion..."
        aws eks delete-cluster --name $CLUSTER_NAME --region $AWS_REGION || true
    }
else
    echo "   Cluster not found"
fi

# 3. Delete node groups manually
echo ""
echo "3. Deleting node groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --query 'nodegroups' --output text 2>/dev/null || echo "")
if [ -n "$NODE_GROUPS" ]; then
    for ng in $NODE_GROUPS; do
        echo "   Deleting nodegroup: $ng"
        aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng --region $AWS_REGION || true
    done
fi

# 4. Delete ECR repositories
echo ""
echo "4. Force deleting ECR repositories..."
for repo in "product-service" "order-service"; do
    aws ecr delete-repository --repository-name $repo --region $AWS_REGION --force 2>/dev/null && echo "   ✅ $repo deleted" || echo "   ℹ️  $repo not found"
done

# 5. Delete IAM resources
echo ""
echo "5. Force deleting IAM resources..."
ROLE_NAME="DaprSNSSQSRole"
POLICY_NAME="DaprSNSSQSPolicy"

# Detach and delete role
if aws iam get-role --role-name $ROLE_NAME &>/dev/null; then
    aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" 2>/dev/null || true
    aws iam delete-role --role-name $ROLE_NAME 2>/dev/null && echo "   ✅ Role deleted" || echo "   ⚠️  Role deletion failed"
fi

# Delete policy
aws iam delete-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" 2>/dev/null && echo "   ✅ Policy deleted" || echo "   ℹ️  Policy not found"

# 6. Clean up VPC and security groups
echo ""
echo "6. Cleaning up VPC resources..."
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=eksctl-${CLUSTER_NAME}-cluster/VPC" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    echo "   Found VPC: $VPC_ID"
    
    # Delete security groups
    SG_IDS=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*eksctl*" --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")
    for sg in $SG_IDS; do
        aws ec2 delete-security-group --group-id $sg --region $AWS_REGION 2>/dev/null || true
    done
    
    # Delete subnets
    SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    for subnet in $SUBNET_IDS; do
        aws ec2 delete-subnet --subnet-id $subnet --region $AWS_REGION 2>/dev/null || true
    done
    
    # Delete VPC
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION 2>/dev/null || true
fi

# 7. Clean kubectl config
echo ""
echo "7. Cleaning kubectl config..."
kubectl config delete-context "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}" 2>/dev/null || true
kubectl config delete-cluster "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}" 2>/dev/null || true

# 8. Wait and verify cleanup
echo ""
echo "8. Waiting for cleanup to complete..."
sleep 60

echo ""
echo "🎉 FORCE CLEANUP COMPLETED!"
echo ""
echo "Verification:"
echo "-------------"
aws cloudformation list-stacks --region $AWS_REGION --query 'StackSummaries[?contains(StackName, `dapr-microservices`) && StackStatus != `DELETE_COMPLETE`]' --output table || echo "No stacks found"

echo ""
echo "💰 All AWS resources should be deleted and charges stopped"
echo "🔄 You can now run: eksctl create cluster -f infrastructure/eks-cluster.yaml"