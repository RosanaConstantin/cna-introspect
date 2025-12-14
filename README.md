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

4. **Deploy Everything**
   ```bash
   ./scripts/deploy.sh
   ```

5. **Test the Flow**
   ```bash
   ./scripts/test.sh
   ```

## Services

- **ProductService**: Publishes product events to SNS/SQS
- **OrderService**: Subscribes to product events and processes orders

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
  -d '{"id":"prod-123","name":"Test Product","price":99.99}'
```

**Expected Response:**
```json
{"message":"Product created and event published","product":{"id":"prod-123","name":"Test Product","price":99.99}}
```

## Environment Details

- **Container Registry**: Amazon ECR
- **Kubernetes**: Amazon EKS 1.28+
- **Runtime**: Node.js 20.x LTS
- **Message Broker**: AWS SNS/SQS via Dapr
- **Monitoring**: CloudWatch Logs
- **Security**: Non-root containers, security contexts