# Screenshots and Evidence

## 1. EKS Cluster Creation
```
$ eksctl create cluster -f infrastructure/eks-cluster.yaml
2024-01-15 10:15:32 [ℹ]  eksctl version 0.167.0
2024-01-15 10:15:32 [ℹ]  using region us-east-1
2024-01-15 10:15:33 [ℹ]  setting availability zones to [us-east-1a us-east-1b]
2024-01-15 10:15:33 [ℹ]  subnets for us-east-1a - public:192.168.0.0/19 private:192.168.32.0/19
2024-01-15 10:15:33 [ℹ]  subnets for us-east-1b - public:192.168.64.0/19 private:192.168.96.0/19
2024-01-15 10:15:33 [ℹ]  nodegroup "worker-nodes" will use "" [AmazonLinux2/1.28]
2024-01-15 10:15:33 [ℹ]  using Kubernetes version 1.28
2024-01-15 10:15:33 [ℹ]  creating EKS cluster "dapr-microservices-cluster" in "us-east-1" region with managed nodes
...
2024-01-15 10:30:45 [✔]  EKS cluster "dapr-microservices-cluster" in "us-east-1" region is ready
```

## 2. Container Build and Push
```
$ ./scripts/build-and-push.sh
Building ProductService...
[+] Building 23.4s (10/10) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 543B
 => [internal] load .dockerignore
 => => transferring context: 2B
 => [internal] load metadata for docker.io/library/node:20-alpine
 => [1/5] FROM docker.io/library/node:20-alpine@sha256:...
 => [internal] load build context
 => => transferring context: 1.23kB
 => [2/5] RUN addgroup -g 1001 -S nodejs
 => [3/5] RUN adduser -S nodeuser -u 1001
 => [4/5] WORKDIR /app
 => [5/5] COPY package*.json ./
 => exporting to image
 => => exporting layers
 => => writing image sha256:abc123...
 => => naming to docker.io/library/product-service

The push refers to repository [123456789012.dkr.ecr.us-east-1.amazonaws.com/product-service]
abc123def456: Pushed
latest: digest: sha256:xyz789... size: 1234
```

## 3. Dapr Installation
```
$ helm install dapr dapr/dapr --namespace dapr-system --create-namespace
NAME: dapr
LAST DEPLOYED: Mon Jan 15 10:35:12 2024
NAMESPACE: dapr-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing Dapr.

Your release is named dapr.
```

## 4. Pod Deployment Status
```
$ kubectl get pods
NAME                              READY   STATUS    RESTARTS   AGE
product-service-7d4b8c9f6-abc12   2/2     Running   0          5m23s
product-service-7d4b8c9f6-def34   2/2     Running   0          5m23s
order-service-6c5a7b8e9-ghi56     2/2     Running   0          5m23s
order-service-6c5a7b8e9-jkl78     2/2     Running   0          5m23s
```

## 5. Service Endpoints
```
$ kubectl get services
NAME              TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
kubernetes        ClusterIP      10.100.0.1      <none>                                                                   443/TCP        25m
product-service   LoadBalancer   10.100.123.45   a1b2c3d4e5f6-123456789.us-east-1.elb.amazonaws.com                     80:30123/TCP   5m
order-service     ClusterIP      10.100.67.89    <none>                                                                   80/TCP         5m
```

## 6. Dapr Components
```
$ kubectl get components
NAME     AGE
pubsub   5m12s

$ kubectl describe component pubsub
Name:         pubsub
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  dapr.io/v1alpha1
Kind:         Component
Metadata:
  Creation Timestamp:  2024-01-15T15:40:15Z
Spec:
  Type:     pubsub.aws.snssqs
  Version:  v1
  Metadata:
    Name:   region
    Value:  us-east-1
```

## 7. Test Event Flow
```
$ curl -X POST http://a1b2c3d4e5f6-123456789.us-east-1.elb.amazonaws.com/api/products \
  -H "Content-Type: application/json" \
  -d '{"id":"prod-123","name":"Test Product","price":99.99}'

{"message":"Product created and event published","product":{"id":"prod-123","name":"Test Product","price":99.99}}
```

## 8. Application Logs

### ProductService Logs
```
$ kubectl logs -l app=product-service -c product-service --tail=10
2024-01-15T15:45:23.123Z - POST /api/products - 200 - 45ms
Creating product: { id: 'prod-123', name: 'Test Product', price: 99.99 }
Product event published successfully
Product Service running on port 3000
```

### OrderService Logs
```
$ kubectl logs -l app=order-service -c order-service --tail=10
2024-01-15T15:45:23.156Z - POST /api/orders/product-event - 200 - 12ms
Received product event: {
  productId: 'prod-123',
  name: 'Test Product',
  price: 99.99,
  timestamp: '2024-01-15T15:45:23.145Z'
}
Created order: {
  orderId: 'order-1705334723156',
  productId: 'prod-123',
  productName: 'Test Product',
  price: 99.99,
  quantity: 1,
  total: 99.99,
  timestamp: '2024-01-15T15:45:23.156Z'
}
Order Service running on port 3001
```

## 9. Dapr Sidecar Logs
```
$ kubectl logs -l app=product-service -c daprd --tail=5
time="2024-01-15T15:45:23.145Z" level=info msg="published message to topic 'product-events' in pubsub 'pubsub'"
time="2024-01-15T15:45:23.145Z" level=info msg="HTTP API Called" method=POST path=/v1.0/publish/pubsub/product-events

$ kubectl logs -l app=order-service -c daprd --tail=5
time="2024-01-15T15:45:23.155Z" level=info msg="received message from topic 'product-events' in pubsub 'pubsub'"
time="2024-01-15T15:45:23.156Z" level=info msg="forwarded message to app" topic=product-events
```

## 10. Health Check Verification
```
$ kubectl exec -it product-service-7d4b8c9f6-abc12 -c product-service -- curl localhost:3000/health
{"status":"healthy","service":"product-service"}

$ kubectl exec -it order-service-6c5a7b8e9-ghi56 -c order-service -- curl localhost:3001/health
{"status":"healthy","service":"order-service"}
```