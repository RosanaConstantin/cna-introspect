# Architecture Diagram

```mermaid
graph TB
    subgraph "Amazon EKS Cluster"
        subgraph "ProductService Pod"
            PS[ProductService:3000]
            PSD[Dapr Sidecar]
            PS --> PSD
        end
        
        subgraph "OrderService Pod"
            OS[OrderService:3001]
            OSD[Dapr Sidecar]
            OSD --> OS
        end
        
        subgraph "Dapr Components"
            PC[PubSub Component<br/>AWS SNS/SQS]
        end
        
        PSD --> PC
        PC --> OSD
    end
    
    subgraph "AWS Services"
        SNS[Amazon SNS]
        SQS[Amazon SQS]
        ECR[Amazon ECR]
        CW[CloudWatch Logs]
    end
    
    PC --> SNS
    SNS --> SQS
    
    subgraph "External"
        CLIENT[Client/API Gateway]
        LB[Load Balancer]
    end
    
    CLIENT --> LB
    LB --> PS
    
    PS -.-> CW
    OS -.-> CW
    
    ECR -.-> PS
    ECR -.-> OS
```

## Flow Description

1. **Client Request**: External client sends HTTP POST to ProductService via LoadBalancer
2. **Event Publishing**: ProductService publishes product event via Dapr sidecar to SNS/SQS
3. **Event Consumption**: OrderService receives event via Dapr sidecar subscription
4. **Order Processing**: OrderService processes the product event and creates an order
5. **Monitoring**: All logs are sent to CloudWatch for observability

## Key Components

- **ProductService**: REST API that publishes product events
- **OrderService**: Event subscriber that processes product events
- **Dapr Sidecars**: Handle service-to-service communication and pub/sub
- **AWS SNS/SQS**: Message broker for reliable event delivery
- **EKS**: Managed Kubernetes service hosting the microservices
- **ECR**: Container registry for Docker images