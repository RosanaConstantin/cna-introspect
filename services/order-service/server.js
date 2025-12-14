const express = require('express');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json({ limit: '10mb' }));

// Structured logging helper
const log = (level, message, meta = {}) => {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    service: 'order-service',
    message,
    ...meta
  };
  console.log(JSON.stringify(logEntry));
};

// Request logging middleware with correlation ID
app.use((req, res, next) => {
  const correlationId = req.headers['x-correlation-id'] || crypto.randomUUID();
  req.correlationId = correlationId;
  res.setHeader('x-correlation-id', correlationId);
  
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    log('info', 'HTTP Request', {
      correlationId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`
    });
  });
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'order-service',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Dapr subscription endpoint
app.get('/dapr/subscribe', (req, res) => {
  const subscriptions = [
    {
      pubsubname: 'pubsub',
      topic: 'product-events',
      route: '/api/orders/product-event'
    }
  ];
  
  log('info', 'Dapr subscription requested', { 
    correlationId: req.correlationId,
    subscriptions 
  });
  
  res.json(subscriptions);
});

// Validate product event data
const validateProductEvent = (eventData) => {
  const errors = [];
  
  if (!eventData) {
    errors.push('Event data is required');
    return errors;
  }
  
  if (!eventData.productId || typeof eventData.productId !== 'string') {
    errors.push('Product ID is required and must be a string');
  }
  if (!eventData.name || typeof eventData.name !== 'string') {
    errors.push('Product name is required and must be a string');
  }
  if (eventData.price === undefined || typeof eventData.price !== 'number' || eventData.price <= 0) {
    errors.push('Product price is required and must be a positive number');
  }
  
  return errors;
};

// Handle product events
app.post('/api/orders/product-event', async (req, res) => {
  const correlationId = req.correlationId;
  
  try {
    const event = req.body.data;
    const eventCorrelationId = event?.correlationId || correlationId;
    
    log('info', 'Received product event', { 
      correlationId: eventCorrelationId,
      productId: event?.productId 
    });
    
    // Validate event data
    const validationErrors = validateProductEvent(event);
    if (validationErrors.length > 0) {
      log('warn', 'Invalid product event data', {
        correlationId: eventCorrelationId,
        errors: validationErrors
      });
      return res.status(400).json({ 
        success: false, 
        error: 'Invalid event data',
        details: validationErrors,
        correlationId: eventCorrelationId
      });
    }
    
    // Process order based on product event
    const order = {
      orderId: `order-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`,
      productId: event.productId,
      productName: event.name,
      price: event.price,
      quantity: 1,
      total: event.price,
      timestamp: new Date().toISOString(),
      correlationId: eventCorrelationId
    };
    
    // Simulate order processing (could be database save, external API call, etc.)
    await new Promise(resolve => setTimeout(resolve, 100));
    
    log('info', 'Order created successfully', {
      correlationId: eventCorrelationId,
      orderId: order.orderId,
      productId: order.productId,
      total: order.total
    });
    
    res.json({ 
      success: true, 
      orderId: order.orderId,
      correlationId: eventCorrelationId
    });
    
  } catch (error) {
    log('error', 'Failed to process product event', {
      correlationId,
      error: error.message,
      stack: error.stack
    });
    
    res.status(500).json({ 
      success: false, 
      error: 'Failed to process product event',
      correlationId
    });
  }
});

// Global error handler
app.use((error, req, res, next) => {
  log('error', 'Unhandled error', {
    correlationId: req.correlationId,
    error: error.message,
    stack: error.stack
  });
  res.status(500).json({ 
    success: false,
    error: 'Internal server error', 
    correlationId: req.correlationId 
  });
});

app.listen(PORT, () => {
  log('info', 'Order Service started', { port: PORT });
});