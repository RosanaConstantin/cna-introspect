# GenAI-Assisted Insights (Amazon Bedrock)

## Suggested Telemetry Points

### ProductService Telemetry
- **Request metrics**: HTTP request count, response time, error rate
- **Business metrics**: Products created per minute, event publish success rate
- **Infrastructure metrics**: CPU/memory usage, container restart count

### OrderService Telemetry  
- **Event processing**: Events received, processing time, failure rate
- **Business metrics**: Orders created per minute, order value distribution
- **Queue metrics**: Message queue depth, processing lag

## Recommended Retry & Resiliency Patterns

### Circuit Breaker Pattern
```javascript
// Add to ProductService
const CircuitBreaker = require('opossum');
const options = {
  timeout: 3000,
  errorThresholdPercentage: 50,
  resetTimeout: 30000
};
const breaker = new CircuitBreaker(publishEvent, options);
```

### Exponential Backoff
```javascript
// Add to event publishing
const retry = async (fn, retries = 3) => {
  try {
    return await fn();
  } catch (error) {
    if (retries > 0) {
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, 3 - retries) * 1000));
      return retry(fn, retries - 1);
    }
    throw error;
  }
};
```

## Dockerfile Analysis

### Recommendations
- ✅ Using Alpine Linux for smaller image size
- ✅ Multi-stage builds not needed for simple Node.js apps
- ⚠️ Consider adding health check: `HEALTHCHECK CMD curl -f http://localhost:3000/health`
- ⚠️ Run as non-root user for security

## Kubernetes Manifests Analysis

### Security Improvements
- Add security context to run containers as non-root
- Implement network policies for pod-to-pod communication
- Add resource quotas and limits

### Scaling Recommendations
- Configure Horizontal Pod Autoscaler (HPA)
- Add readiness and liveness probes
- Use PodDisruptionBudget for high availability

## SNS/SQS Scaling Patterns

### Auto Scaling Configuration
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Dead Letter Queue Pattern
- Configure DLQ for failed message processing
- Implement message retry with exponential backoff
- Monitor DLQ depth for alerting