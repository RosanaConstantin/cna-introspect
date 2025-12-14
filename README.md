# EKS Microservices with Dapr Pub/Sub

This project demonstrates deploying containerized microservices on Amazon EKS with Dapr sidecars for event-driven pub/sub messaging using AWS SNS/SQS.

## Architecture

```
ProductService → Dapr Sidecar → AWS SNS/SQS → Dapr Sidecar → OrderService
```

## Prerequisites

- AWS Account with EKS, ECR, IAM, CloudWatch, VPC permissions
- Docker, AWS CLI, kubectl, eksctl, Helm 3+ installed
- Node.js 20.x LTS

## Quick Start

1. **Prerequisites Setup**
   ```bash
   # Configure AWS CLI
   aws configure
   
   # Verify tools
   docker --version
   kubectl version --client
   eksctl version
   helm version
   ```

2. **Build and Push Images**
   ```bash
   ./scripts/build-and-push.sh
   ```

3. **Create EKS Cluster**
   ```bash
   eksctl create cluster -f infrastructure/eks-cluster.yaml
   ```

4. **Setup IAM Roles for Service Accounts (IRSA)**
   ```bash
   chmod +x scripts/setup-irsa.sh
   ./scripts/setup-irsa.sh
   ```

5. **Deploy Everything**
   ```bash
   ./scripts/deploy.sh
   ```

6. **Test the Flow**
   ```bash
   ./scripts/test.sh
   ```

## Services

- **ProductService**: Publishes product events to SNS/SQS with input validation, structured logging, and retry mechanisms
- **OrderService**: Subscribes to product events and processes orders with comprehensive error handling

## Security Features

- **IAM Roles for Service Accounts (IRSA)**: No hardcoded AWS credentials
- **Input Validation**: Comprehensive validation for all API endpoints
- **Security Contexts**: Non-root containers with minimal privileges
- **Structured Logging**: JSON-formatted logs with correlation IDs
- **Error Handling**: Comprehensive error handling with proper HTTP status codes

## Observability Features

- **Correlation IDs**: Request tracing across services
- **Structured Logging**: JSON logs for better parsing and analysis
- **Health Checks**: Comprehensive health endpoints
- **Metrics**: CPU and memory-based auto-scaling
- **Multi-AZ Deployment**: High availability across availability zones

## Monitoring

View logs:
```bash
kubectl logs -l app=product-service -c product-service -f
kubectl logs -l app=order-service -c order-service -f
```

## API Endpoints

### ProductService (Port 80)
- `GET /health` - Health check
- `POST /api/products` - Create product and publish event

### OrderService (Internal)
- `GET /health` - Health check  
- `GET /dapr/subscribe` - Dapr subscription configuration
- `POST /api/orders/product-event` - Handle product events

## Testing

**Get LoadBalancer URL:**
```bash
kubectl get service product-service
```

**Send test event:**
```bash
curl -X POST http://<EXTERNAL-IP>/api/products \
  -H "Content-Type: application/json" \
  -H "x-correlation-id: test-123" \
  -d '{"id":"prod-123","name":"Test Product","price":99.99}'
```

**Expected Response:**
```json
{
  "message": "Product created and event published",
  "product": {
    "id": "prod-123",
    "name": "Test Product",
    "price": 99.99
  },
  "correlationId": "test-123"
}
```

## Environment Details

- **Container Registry**: Amazon ECR with versioned tags (v1.0.0)
- **Kubernetes**: Amazon EKS 1.28+ with multi-AZ deployment
- **Runtime**: Node.js 20.x LTS
- **Message Broker**: AWS SNS/SQS via Dapr
- **Authentication**: IAM Roles for Service Accounts (IRSA)
- **Monitoring**: CloudWatch Logs with structured JSON logging
- **Security**: Non-root containers, security contexts, input validation
- **Scaling**: Horizontal Pod Autoscaler with CPU and memory metrics
- **Error Handling**: Comprehensive error handling with retry mechanisms