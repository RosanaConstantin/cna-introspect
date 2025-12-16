# EKS Microservices with Dapr Pub/Sub

[![AWS EKS](https://img.shields.io/badge/AWS-EKS-orange)](https://aws.amazon.com/eks/)
[![Dapr](https://img.shields.io/badge/Dapr-1.16.4-blue)](https://dapr.io/)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-green)](https://nodejs.org/)

This project demonstrates deploying containerized microservices on Amazon EKS with Dapr sidecars for event-driven pub/sub messaging using AWS SNS/SQS. This is a complete implementation of cloud-native microservices with production-ready features.

## Architecture

```
ProductService → Dapr Sidecar → AWS SNS/SQS → Dapr Sidecar → OrderService
      ↓                                                            ↓
  LoadBalancer                                               Internal Service
```

See [Architecture Diagram](architecture-diagram.md) for detailed flow.

## Prerequisites

### Required Tools
- **AWS Account** with permissions for:
  - EKS (Elastic Kubernetes Service)
  - ECR (Elastic Container Registry)
  - IAM (Identity and Access Management)
  - SNS/SQS (Simple Notification Service / Simple Queue Service)
  - CloudWatch, VPC
- **Docker** (Desktop or Engine)
- **AWS CLI v2**
- **kubectl** (Kubernetes CLI)
- **eksctl** (EKS CLI)
- **Helm 3+**

### Development Environment
- **Node.js 20.x LTS** (for local development)
- **macOS/Linux** (scripts use bash/zsh)

## Quick Start

### 1. Setup AWS Profile
```bash
# Configure AWS CLI with your credentials
aws configure --profile org-demo

# Or use the setup script
./scripts/setup-org-demo.sh
```

### 2. Build and Push Container Images
```bash
# Builds for AMD64 architecture and pushes to ECR
./scripts/build-and-push.sh
```

This will:
- Create ECR repositories if they don't exist
- Build Docker images for both services
- Push images with version tag `v1.0.0`

### 3. Create EKS Cluster
```bash
# Create cluster with OIDC provider
eksctl create cluster -f infrastructure/eks-cluster.yaml --profile org-demo

# Associate OIDC provider (required for IRSA)
eksctl utils associate-iam-oidc-provider \
  --cluster=dapr-microservices-cluster \
  --region=us-east-1 \
  --profile=org-demo \
  --approve
```

### 4. Setup IAM Roles for Service Accounts (IRSA)
```bash
./scripts/setup-irsa.sh
```

This creates:
- IAM policy for SNS/SQS access
- IAM role with OIDC trust relationship
- Service account annotations

### 5. Deploy Services
```bash
./scripts/deploy.sh
```

This deploys:
- Dapr runtime to `dapr-system` namespace
- Dapr pub/sub component (SNS/SQS)
- ProductService and OrderService
- LoadBalancer for ProductService
- Horizontal Pod Autoscaler

### 6. Verify Deployment
```bash
# Check pods are running
kubectl get pods

# Get LoadBalancer URL
kubectl get svc product-service

# Test health endpoint
curl http://<EXTERNAL-IP>/health
```

### 7. Test Event Flow
```bash
# Use automated test script
./scripts/test.sh

# Or manual test
curl -X POST http://<EXTERNAL-IP>/api/products \
  -H "Content-Type: application/json" \
  -d '{"id":"prod-123","name":"Test Product","price":99.99}'
```

## Project Structure

```
cna-introspect/
├── README.md                          # This file
├── DEPLOYMENT.md                      # Detailed deployment guide
├── TESTING.md                         # Testing procedures and evidence
├── SCREENSHOTS.md                     # Screenshots and command outputs
├── architecture-diagram.md            # System architecture
├── bedrock-insights.md               # GenAI-assisted insights
├── infrastructure/
│   └── eks-cluster.yaml              # EKS cluster configuration
├── k8s/
│   ├── dapr-pubsub.yaml              # Dapr SNS/SQS component
│   ├── product-service.yaml          # ProductService deployment
│   ├── order-service.yaml            # OrderService deployment
│   └── hpa.yaml                      # Horizontal Pod Autoscaler
├── scripts/
│   ├── setup-org-demo.sh             # AWS profile setup
│   ├── build-and-push.sh             # Build and push Docker images
│   ├── setup-irsa.sh                 # Setup IAM roles for service accounts
│   ├── deploy.sh                     # Deploy all components
│   ├── test.sh                       # End-to-end testing
│   ├── check-deployment.sh           # Deployment verification
│   └── cleanup-stack.sh              # Resource cleanup
└── services/
    ├── product-service/
    │   ├── Dockerfile
    │   ├── package.json
    │   └── server.js
    └── order-service/
        ├── Dockerfile
        ├── package.json
        └── server.js
```

## Services

### ProductService
- **Port**: 3000 (exposed via LoadBalancer on port 80)
- **Purpose**: Creates products and publishes events to SNS/SQS
- **Features**:
  - Input validation with detailed error messages
  - Structured JSON logging with correlation IDs
  - Retry mechanism with exponential backoff
  - Health check endpoint
  - Dapr pub/sub integration

**API Endpoints:**
- `GET /health` - Health check
- `POST /api/products` - Create product and publish event

**Request Example:**
```json
{
  "id": "prod-123",
  "name": "Test Product",
  "price": 99.99
}
```

### OrderService
- **Port**: 3001 (ClusterIP - internal only)
- **Purpose**: Subscribes to product events and creates orders
- **Features**:
  - Event-driven architecture via Dapr subscription
  - Comprehensive error handling
  - Automatic order creation from product events
  - Health check endpoint
  - Structured logging

**API Endpoints:**
- `GET /health` - Health check
- `GET /dapr/subscribe` - Dapr subscription configuration
- `POST /api/orders/product-event` - Handle product events (Dapr callback)

## Key Features

### Security
- ✅ **IAM Roles for Service Accounts (IRSA)**: No hardcoded AWS credentials
- ✅ **Non-root containers**: All containers run as user ID 1001
- ✅ **Security contexts**: Minimal privileges, no privilege escalation
- ✅ **Input validation**: Comprehensive validation for all API endpoints
- ✅ **Error handling**: Proper error handling without exposing sensitive info

### Observability
- ✅ **Correlation IDs**: Request tracing across services
- ✅ **Structured Logging**: JSON-formatted logs for parsing
- ✅ **Health Checks**: Liveness and readiness probes
- ✅ **CloudWatch Integration**: Centralized log aggregation
- ✅ **Dapr Metrics**: Built-in metrics on port 9090

### Scalability & Reliability
- ✅ **Horizontal Pod Autoscaler**: CPU and memory-based scaling
- ✅ **Multi-AZ Deployment**: High availability across availability zones
- ✅ **Resource Limits**: Defined CPU and memory constraints
- ✅ **Retry Mechanisms**: Exponential backoff for transient failures
- ✅ **LoadBalancer**: External access with health checks

### Event-Driven Architecture
- ✅ **Dapr Sidecars**: Service mesh for pub/sub
- ✅ **AWS SNS/SQS**: Managed message broker
- ✅ **Asynchronous Processing**: Decoupled services
- ✅ **Event Validation**: Schema validation for events
- ✅ **Dead Letter Queues**: Configurable via SNS/SQS

## Monitoring & Logging

### View Logs
```bash
# ProductService logs
kubectl logs -l app=product-service -c product-service -f

# OrderService logs
kubectl logs -l app=order-service -c order-service -f

# Dapr sidecar logs
kubectl logs -l app=product-service -c daprd -f
```

### Check Resources
```bash
# Pod status
kubectl get pods -o wide

# Service endpoints
kubectl get svc

# HPA status
kubectl get hpa

# Dapr components
kubectl get components
```

### SNS/SQS Resources
```bash
# List SNS topics
aws sns list-topics --profile org-demo

# List SQS queues
aws sqs list-queues --profile org-demo
```

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing procedures.

**Quick Test:**
```bash
# Get LoadBalancer URL
PRODUCT_URL=$(kubectl get svc product-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Send test request
curl -X POST http://$PRODUCT_URL/api/products \
  -H "Content-Type: application/json" \
  -H "x-correlation-id: test-$(date +%s)" \
  -d '{
    "id": "prod-456",
    "name": "Another Product",
    "price": 149.99
  }'

# Check OrderService received the event
kubectl logs -l app=order-service -c order-service --tail=20 | grep "product event"
```

## Cleanup

### Delete Deployments Only
```bash
kubectl delete -f k8s/product-service.yaml
kubectl delete -f k8s/order-service.yaml
kubectl delete -f k8s/dapr-pubsub.yaml
helm uninstall dapr -n dapr-system
```

### Delete Everything
```bash
# Delete cluster
eksctl delete cluster dapr-microservices-cluster --profile org-demo

# Delete ECR repositories
aws ecr delete-repository --repository-name product-service --force --profile org-demo
aws ecr delete-repository --repository-name order-service --force --profile org-demo

# Delete IAM resources
aws iam detach-role-policy --role-name DaprSNSSQSRole --policy-arn arn:aws:iam::$(aws sts get-caller-identity --profile org-demo --query Account --output text):policy/DaprSNSSQSPolicy --profile org-demo
aws iam delete-role --role-name DaprSNSSQSRole --profile org-demo
aws iam delete-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --profile org-demo --query Account --output text):policy/DaprSNSSQSPolicy --profile org-demo
```
## Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl get pods

# Describe pod for events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name> -c <container-name>
```

### IRSA/OIDC Issues
```bash
# Verify OIDC provider exists
aws eks describe-cluster --name dapr-microservices-cluster --region us-east-1 --profile org-demo --query "cluster.identity.oidc.issuer"

# Create if missing
eksctl utils associate-iam-oidc-provider --cluster=dapr-microservices-cluster --region=us-east-1 --profile org-demo --approve
```

### Image Pull Errors
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 --profile org-demo | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Rebuild for AMD64
docker buildx build --platform linux/amd64 -t product-service ./services/product-service
```

### LoadBalancer Not Ready
```bash
# Check service
kubectl describe svc product-service

# Wait for provisioning (can take 2-5 minutes)
kubectl get svc product-service -w
```

## Learning Outcomes

After completing this project, you will have learned:

1. ✅ **Container Orchestration**: Deploy and manage microservices on Amazon EKS
2. ✅ **Service Mesh**: Enable Dapr sidecars for service-to-service communication
3. ✅ **Event-Driven Architecture**: Implement pub/sub workflows using AWS SNS/SQS
4. ✅ **Security**: Configure IAM Roles for Service Accounts (IRSA) for secure AWS access
5. ✅ **Observability**: Monitor distributed interactions through Dapr logs and CloudWatch
6. ✅ **Kubernetes**: Understand Deployment, Service, HPA, and Component objects
7. ✅ **Infrastructure as Code**: Use eksctl and Helm for reproducible deployments
8. ✅ **CI/CD Ready**: Automated build, push, and deployment scripts

## References

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Dapr Documentation](https://docs.dapr.io/)
- [AWS SNS/SQS with Dapr](https://docs.dapr.io/reference/components-reference/supported-pubsub/setup-aws-snssqs/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## License

This project is for educational purposes as part of Cloud Native Application certification.

## Author

**Cloud Native Application Introspect Project**  
December 2025

---

**Need Help?** Check [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions or [TESTING.md](TESTING.md) for troubleshooting test scenarios.
