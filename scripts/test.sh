#!/bin/bash
set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Use org-demo profile
AWS_PROFILE="org-demo"
echo "Using AWS Profile: $AWS_PROFILE"
export AWS_PROFILE=$AWS_PROFILE

# Get ProductService LoadBalancer URL
echo "Getting ProductService endpoint..."
PRODUCT_SERVICE_URL=$(kubectl get service product-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

# Fallback to IP if hostname is not available
if [ -z "$PRODUCT_SERVICE_URL" ]; then
    PRODUCT_SERVICE_URL=$(kubectl get service product-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

if [ -z "$PRODUCT_SERVICE_URL" ]; then
    echo "ProductService LoadBalancer not ready. Using port-forward..."
    kubectl port-forward service/product-service 8080:80 &
    PORT_FORWARD_PID=$!
    sleep 5
    PRODUCT_SERVICE_URL="localhost:8080"
else
    echo "Found LoadBalancer endpoint: $PRODUCT_SERVICE_URL"
fi

echo "Testing ProductService at: $PRODUCT_SERVICE_URL"

# Generate correlation ID for tracing
CORRELATION_ID=$(uuidgen 2>/dev/null || echo "test-$(date +%s)")
echo "Using correlation ID: $CORRELATION_ID"

# Send test product event with error handling
echo "Sending test product event..."
HTTP_STATUS=$(curl -w "%{http_code}" -s -o response.json -X POST http://$PRODUCT_SERVICE_URL/api/products \
  -H "Content-Type: application/json" \
  -H "x-correlation-id: $CORRELATION_ID" \
  -d '{
    "id": "prod-123",
    "name": "Test Product",
    "price": 99.99
  }' || echo "000")

if [ "$HTTP_STATUS" -eq "200" ]; then
    echo "✅ Product creation successful (HTTP $HTTP_STATUS)"
    cat response.json
    echo ""
else
    echo "❌ Product creation failed (HTTP $HTTP_STATUS)"
    cat response.json 2>/dev/null || echo "No response body"
    echo ""
fi

# Clean up response file
rm -f response.json

echo -e "\n\nChecking logs..."
echo "ProductService logs:"
kubectl logs -l app=product-service -c product-service --tail=10 || echo "Failed to get ProductService logs"

echo -e "\nOrderService logs:"
kubectl logs -l app=order-service -c order-service --tail=10 || echo "Failed to get OrderService logs"

echo -e "\nDapr sidecar logs:"
echo "ProductService Dapr:"
kubectl logs -l app=product-service -c daprd --tail=5 || echo "Failed to get ProductService Dapr logs"

echo -e "\nOrderService Dapr:"
kubectl logs -l app=order-service -c daprd --tail=5 || echo "Failed to get OrderService Dapr logs"

echo -e "\nPod status:"
kubectl get pods -l app=product-service -o wide || echo "Failed to get ProductService pods"
kubectl get pods -l app=order-service -o wide || echo "Failed to get OrderService pods"

# Clean up port-forward if used
if [ ! -z "${PORT_FORWARD_PID:-}" ]; then
    echo "Cleaning up port-forward..."
    kill $PORT_FORWARD_PID 2>/dev/null || echo "Port-forward already terminated"
fi

echo "\nTest completed!"