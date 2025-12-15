#!/bin/bash

echo "Checking Dapr Cluster Deployment Status..."
echo "=========================================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not installed"
    echo "Install: brew install awscli"
    exit 1
fi

# Check AWS credentials
echo "1. Checking AWS credentials..."
aws sts get-caller-identity &> /dev/null || {
    echo "❌ AWS not configured. Run: aws configure"
    exit 1
}
echo "✅ AWS credentials configured"

# Check for EKS cluster
echo ""
echo "2. Checking for EKS cluster 'dapr-microservices-cluster'..."
CLUSTER_STATUS=$(aws eks describe-cluster --name dapr-microservices-cluster --region us-east-1 --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" = "NOT_FOUND" ]; then
    echo "❌ Cluster 'dapr-microservices-cluster' does not exist"
    echo ""
    echo "To deploy the cluster:"
    echo "  eksctl create cluster -f infrastructure/eks-cluster.yaml"
elif [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
    echo "✅ Cluster is ACTIVE"
    
    # Check kubectl connection
    echo ""
    echo "3. Checking kubectl connection..."
    kubectl cluster-info &> /dev/null && {
        echo "✅ kubectl connected to cluster"
        
        # Check Dapr installation
        echo ""
        echo "4. Checking Dapr installation..."
        kubectl get namespace dapr-system &> /dev/null && {
            echo "✅ Dapr namespace exists"
            kubectl get pods -n dapr-system
        } || {
            echo "❌ Dapr not installed"
            echo "Run: ./scripts/deploy.sh"
        }
        
        # Check microservices
        echo ""
        echo "5. Checking microservices..."
        kubectl get pods -l app=product-service &> /dev/null && {
            echo "✅ ProductService deployed"
        } || {
            echo "❌ ProductService not deployed"
        }
        
        kubectl get pods -l app=order-service &> /dev/null && {
            echo "✅ OrderService deployed"
        } || {
            echo "❌ OrderService not deployed"
        }
        
    } || {
        echo "❌ kubectl not connected to cluster"
        echo "Run: aws eks update-kubeconfig --region us-east-1 --name dapr-microservices-cluster"
    }
else
    echo "⚠️  Cluster status: $CLUSTER_STATUS"
fi

echo ""
echo "Deployment check completed."