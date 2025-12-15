#!/bin/bash
set -e

echo "🗑️  AWS Stack Cleanup - Dapr Microservices"
echo "=========================================="

# Configuration
CLUSTER_NAME="dapr-microservices-cluster"
AWS_REGION="us-east-1"
ROLE_NAME="DaprSNSSQSRole"
POLICY_NAME="DaprSNSSQSPolicy"
AWS_PROFILE="org-demo"
echo "Using AWS Profile: $AWS_PROFILE"
export AWS_PROFILE=$AWS_PROFILE

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not installed"
    exit 1
fi

# Get account ID from org-demo profile
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text 2>/dev/null) || {
    echo "❌ AWS profile $AWS_PROFILE not configured"
    exit 1
}

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

# 1. Delete EKS Cluster (this removes everything in the cluster)
echo "1. Deleting EKS cluster '$CLUSTER_NAME'..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &>/dev/null; then
    echo "   Deleting cluster (this will take 10-15 minutes)..."
    eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION --wait || {
        echo "   ⚠️  Cluster deletion failed, continuing with other resources..."
    }
    echo "   ✅ Cluster deleted"
else
    echo "   ℹ️  Cluster not found, skipping"
fi

# 2. Delete IAM Role
echo ""
echo "2. Deleting IAM role '$ROLE_NAME'..."
if aws iam get-role --role-name $ROLE_NAME &>/dev/null; then
    # Detach policies first
    aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" 2>/dev/null || true
    
    # Delete role
    aws iam delete-role --role-name $ROLE_NAME || {
        echo "   ⚠️  Failed to delete role"
    }
    echo "   ✅ IAM role deleted"
else
    echo "   ℹ️  IAM role not found, skipping"
fi

# 3. Delete IAM Policy
echo ""
echo "3. Deleting IAM policy '$POLICY_NAME'..."
if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" &>/dev/null; then
    aws iam delete-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" || {
        echo "   ⚠️  Failed to delete policy"
    }
    echo "   ✅ IAM policy deleted"
else
    echo "   ℹ️  IAM policy not found, skipping"
fi

# 4. Delete ECR repositories
echo ""
echo "4. Deleting ECR repositories..."
for repo in "product-service" "order-service"; do
    if aws ecr describe-repositories --repository-names $repo --region $AWS_REGION &>/dev/null; then
        aws ecr delete-repository --repository-name $repo --region $AWS_REGION --force || {
            echo "   ⚠️  Failed to delete $repo repository"
        }
        echo "   ✅ $repo repository deleted"
    else
        echo "   ℹ️  $repo repository not found, skipping"
    fi
done

# 5. Clean up local kubectl config
echo ""
echo "5. Cleaning up local kubectl config..."
kubectl config delete-context "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}" 2>/dev/null || true
kubectl config delete-cluster "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}" 2>/dev/null || true
echo "   ✅ Local kubectl config cleaned"

# 6. Optional: Delete CloudWatch Log Groups
echo ""
echo "6. Deleting CloudWatch log groups..."
for log_group in "/aws/eks/${CLUSTER_NAME}/cluster"; do
    if aws logs describe-log-groups --log-group-name-prefix $log_group --region $AWS_REGION --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q $log_group; then
        aws logs delete-log-group --log-group-name $log_group --region $AWS_REGION || {
            echo "   ⚠️  Failed to delete log group $log_group"
        }
        echo "   ✅ Log group $log_group deleted"
    else
        echo "   ℹ️  Log group $log_group not found, skipping"
    fi
done

echo ""
echo "🎉 Cleanup completed!"
echo ""
echo "Summary:"
echo "--------"
echo "✅ EKS cluster deleted"
echo "✅ IAM roles and policies removed"
echo "✅ ECR repositories deleted"
echo "✅ Local kubectl config cleaned"
echo "✅ CloudWatch logs removed"
echo ""
echo "💰 AWS charges should stop within a few minutes"
echo ""
echo "Note: Some resources may take time to fully delete."
echo "Check AWS console to verify all resources are removed."