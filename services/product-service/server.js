const express = require('express');
const axios = require('axios');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;
const DAPR_HTTP_PORT = process.env.DAPR_HTTP_PORT || 3500;

app.use(express.json({ limit: '10mb' }));

// Structured logging helper
const log = (level, message, meta = {}) => {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    service: 'product-service',
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

// Input validation middleware
const validateProduct = (req, res, next) => {
  const { id, name, price } = req.body;
  const errors = [];
  
  if (!id || typeof id !== 'string' || id.trim().length === 0) {
    errors.push('Product ID is required and must be a non-empty string');
  }
  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    errors.push('Product name is required and must be a non-empty string');
  }
  if (price === undefined || typeof price !== 'number' || price <= 0) {
    errors.push('Product price is required and must be a positive number');
  }
  
  if (errors.length > 0) {
    log('warn', 'Validation failed', { correlationId: req.correlationId, errors });
    return res.status(400).json({ error: 'Validation failed', details: errors });
  }
  
  next();
};

// Retry helper with exponential backoff
const retryWithBackoff = async (fn, maxRetries = 3, baseDelay = 1000) => {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxRetries) throw error;
      const delay = baseDelay * Math.pow(2, attempt - 1);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
};

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'product-service',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Create product and publish event
app.post('/api/products', validateProduct, async (req, res) => {
  const correlationId = req.correlationId;
  
  try {
    const product = {
      id: req.body.id.trim(),
      name: req.body.name.trim(),
      price: req.body.price
    };
    
    log('info', 'Creating product', { correlationId, productId: product.id });

    // Publish event via Dapr with retry
    await retryWithBackoff(async () => {
      const response = await axios.post(
        `http://localhost:${DAPR_HTTP_PORT}/v1.0/publish/pubsub/product-events`,
        {
          productId: product.id,
          name: product.name,
          price: product.price,
          timestamp: new Date().toISOString(),
          correlationId
        },
        {
          timeout: 5000,
          headers: {
            'Content-Type': 'application/json',
            'x-correlation-id': correlationId
          }
        }
      );
      return response;
    });

    log('info', 'Product event published successfully', { correlationId, productId: product.id });
    res.json({ 
      message: 'Product created and event published', 
      product,
      correlationId
    });
  } catch (error) {
    log('error', 'Failed to publish product event', {
      correlationId,
      error: error.message,
      stack: error.stack
    });
    
    if (error.code === 'ECONNREFUSED') {
      res.status(503).json({ 
        error: 'Service temporarily unavailable', 
        correlationId,
        retryAfter: 30
      });
    } else {
      res.status(500).json({ 
        error: 'Failed to publish product event', 
        correlationId
      });
    }
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
    error: 'Internal server error', 
    correlationId: req.correlationId 
  });
});

app.listen(PORT, () => {
  log('info', 'Product Service started', { port: PORT });
});