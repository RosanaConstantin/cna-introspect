#!/bin/bash
set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Use org-demo profile
AWS_PROFILE="org-demo"
echo "Using AWS Profile: $AWS_PROFILE"
export AWS_PROFILE=$AWS_PROFILE

echo "Installing Dapr on EKS cluster..."
helm repo add dapr https://dapr.github.io/helm-charts/ || {
  echo "Error: Failed to add Dapr helm repository"
  exit 1
}
helm repo update || {
  echo "Error: Failed to update helm repositories"
  exit 1
}
helm install dapr dapr/dapr \
  --namespace dapr-system \
  --create-namespace \
  --set global.ha.enabled=false \
  --set dapr_scheduler.cluster.storageClassName=gp2 \
  --set dapr_placement.cluster.storageClassName=gp2 \
  --wait \
  --timeout 10m || {
  echo "Error: Failed to install Dapr"
  exit 1
}

echo "Deploying Dapr components..."
kubectl apply -f k8s/dapr-pubsub.yaml || {
  echo "Error: Failed to deploy Dapr components"
  exit 1
}

echo "Deploying microservices..."
kubectl apply -f k8s/product-service.yaml || {
  echo "Error: Failed to deploy ProductService"
  exit 1
}
kubectl apply -f k8s/order-service.yaml || {
  echo "Error: Failed to deploy OrderService"
  exit 1
}
kubectl apply -f k8s/hpa.yaml || {
  echo "Error: Failed to deploy HPA"
  exit 1
}

echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/product-service || {
  echo "Error: ProductService deployment failed to become ready"
  exit 1
}
kubectl wait --for=condition=available --timeout=300s deployment/order-service || {
  echo "Error: OrderService deployment failed to become ready"
  exit 1
}

echo "Getting service endpoints..."
kubectl get services

echo "Deployment completed successfully!"