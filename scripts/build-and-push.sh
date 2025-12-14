#!/bin/bash
set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Check if Docker is running
echo "Checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker is not running. Please start Docker Desktop:"
  echo "   1. Run: open -a Docker"
  echo "   2. Wait for Docker to start (look for Docker icon in menu bar)"
  echo "   3. Run this script again"
  exit 1
fi
echo "✅ Docker is running"

# Configuration
AWS_REGION="us-east-1"
echo "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) || {
  echo "Error: Failed to get AWS Account ID. Please check AWS CLI configuration."
  exit 1
}
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "Using ECR Registry: $ECR_REGISTRY"

# Create ECR repositories if they don't exist
echo "Creating ECR repositories..."
aws ecr describe-repositories --repository-names product-service --region $AWS_REGION 2>/dev/null || {
  echo "Creating product-service repository..."
  aws ecr create-repository --repository-name product-service --region $AWS_REGION || {
    echo "Error: Failed to create product-service repository"
    exit 1
  }
}

aws ecr describe-repositories --repository-names order-service --region $AWS_REGION 2>/dev/null || {
  echo "Creating order-service repository..."
  aws ecr create-repository --repository-name order-service --region $AWS_REGION || {
    echo "Error: Failed to create order-service repository"
    exit 1
  }
}

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY || {
  echo "Error: Failed to login to ECR"
  exit 1
}

# Build and push ProductService
echo "Building ProductService..."
docker build -t product-service ./services/product-service || {
  echo "Error: Failed to build ProductService"
  exit 1
}
docker tag product-service:latest $ECR_REGISTRY/product-service:v1.0.0 || {
  echo "Error: Failed to tag ProductService"
  exit 1
}
docker push $ECR_REGISTRY/product-service:v1.0.0 || {
  echo "Error: Failed to push ProductService"
  exit 1
}

# Build and push OrderService
echo "Building OrderService..."
docker build -t order-service ./services/order-service || {
  echo "Error: Failed to build OrderService"
  exit 1
}
docker tag order-service:latest $ECR_REGISTRY/order-service:v1.0.0 || {
  echo "Error: Failed to tag OrderService"
  exit 1
}
docker push $ECR_REGISTRY/order-service:v1.0.0 || {
  echo "Error: Failed to push OrderService"
  exit 1
}

# Update Kubernetes manifests with ECR registry
sed -i.bak "s|<ECR_REGISTRY>|$ECR_REGISTRY|g" k8s/product-service.yaml
sed -i.bak "s|<ECR_REGISTRY>|$ECR_REGISTRY|g" k8s/order-service.yaml

echo "Images built and pushed successfully!"
echo "ECR Registry: $ECR_REGISTRY"