#!/bin/bash
set -e

echo "Setting up org-demo AWS Profile for EKS Deployment"
echo "=================================================="

AWS_PROFILE="org-demo"

# Check if profile exists
echo "1. Checking if profile '$AWS_PROFILE' exists..."
if aws configure list-profiles | grep -q "^$AWS_PROFILE$"; then
    echo "✅ Profile '$AWS_PROFILE' found"
    
    # Test profile access
    echo "2. Testing profile access..."
    ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text 2>/dev/null) || {
        echo "❌ Profile '$AWS_PROFILE' exists but cannot access AWS"
        echo "Fix with: aws configure --profile $AWS_PROFILE"
        exit 1
    }
    
    echo "✅ Profile working - Account ID: $ACCOUNT_ID"
    
    # Update Kubernetes manifests with correct account ID
    echo "3. Updating Kubernetes manifests..."
    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
    
    # Update dapr-pubsub.yaml
    sed -i.bak "s|<AWS_ACCOUNT_ID>|$ACCOUNT_ID|g" k8s/dapr-pubsub.yaml
    
    # Update kubectl config for EKS
    echo "4. Updating kubectl configuration..."
    aws eks update-kubeconfig --region us-east-1 --name dapr-microservices-cluster --profile $AWS_PROFILE 2>/dev/null || {
        echo "ℹ️  EKS cluster not found (will be created later)"
    }
    
    echo ""
    echo "✅ org-demo profile setup completed!"
    echo "Account ID: $ACCOUNT_ID"
    echo "ECR Registry: $ECR_REGISTRY"
    echo ""
    echo "All scripts are now configured to use org-demo profile"
    
else
    echo "❌ Profile '$AWS_PROFILE' not found"
    echo ""
    echo "Available profiles:"
    aws configure list-profiles
    echo ""
    echo "To create org-demo profile:"
    echo "  aws configure --profile org-demo"
    echo ""
    echo "You'll need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region: us-east-1"
    exit 1
fi

echo ""
echo "🚀 Ready to deploy with org-demo profile!"
echo ""
echo "Next steps:"
echo "1. ./scripts/build-and-push.sh"
echo "2. eksctl create cluster -f infrastructure/eks-cluster.yaml"
echo "3. ./scripts/setup-irsa.sh"
echo "4. ./scripts/deploy.sh"
echo "5. ./scripts/test.sh"