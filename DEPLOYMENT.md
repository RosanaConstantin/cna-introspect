# Deployment Guide

## Prerequisites Setup

1. **Install required tools**:
   ```bash
   # AWS CLI
   curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
   sudo installer -pkg AWSCLIV2.pkg -target /
   
   # kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
   chmod +x kubectl && sudo mv kubectl /usr/local/bin/
   
   # eksctl
   brew tap weaveworks/tap
   brew install weaveworks/tap/eksctl
   
   # Helm
   brew install helm
   ```

2. **Configure AWS credentials**:
   ```bash
   aws configure
   ```

## Step-by-Step Deployment

### 1. Create EKS Cluster
```bash
eksctl create cluster -f infrastructure/eks-cluster.yaml
```

### 2. Build and Push Container Images
```bash
./scripts/build-and-push.sh
```

### 3. Update AWS Credentials
Edit `k8s/dapr-pubsub.yaml` and replace placeholder values:
```yaml
stringData:
  AWS_ACCESS_KEY_ID: "your-actual-access-key"
  AWS_SECRET_ACCESS_KEY: "your-actual-secret-key"
```

### 4. Deploy Services
```bash
./scripts/deploy.sh
```

### 5. Test the Setup
```bash
./scripts/test.sh
```

## Monitoring Commands

```bash
# Check pod status
kubectl get pods

# View logs
kubectl logs -l app=product-service -c product-service -f
kubectl logs -l app=order-service -c order-service -f

# Check Dapr components
kubectl get components

# View services
kubectl get services
```

## Cleanup

```bash
# Delete services
kubectl delete -f k8s/

# Delete cluster
eksctl delete cluster dapr-microservices-cluster
```