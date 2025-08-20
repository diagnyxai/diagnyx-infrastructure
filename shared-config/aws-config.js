/**
 * Centralized AWS Configuration for Diagnyx Services
 * 
 * This file provides a single source of truth for AWS configurations
 * across all Diagnyx services (API Gateway, UI, User Service).
 * 
 * Environment Variables Required:
 * - AWS_COGNITO_USER_POOL_ID
 * - AWS_COGNITO_CLIENT_ID  
 * - AWS_REGION
 * - ENVIRONMENT (dev, staging, production)
 */

const validateRequired = (value, name) => {
  if (!value) {
    throw new Error(`Required environment variable ${name} is not set`);
  }
  return value;
};

const AWS_CONFIG = {
  // Development environment - for local development
  dev: {
    userPoolId: process.env.AWS_COGNITO_USER_POOL_ID || 'us-east-1_I9BoDreCg',
    clientId: process.env.AWS_COGNITO_CLIENT_ID || '4tnfqqkk59scbf0o90q488ec08',
    region: process.env.AWS_REGION || 'us-east-1',
    identityPoolId: process.env.AWS_COGNITO_IDENTITY_POOL_ID,
    oauth: {
      domain: process.env.AWS_COGNITO_DOMAIN || 'diagnyx-dev-auth.auth.us-east-1.amazoncognito.com',
      redirectSignIn: process.env.COGNITO_REDIRECT_SIGN_IN || 'http://localhost:3002/auth/callback',
      redirectSignOut: process.env.COGNITO_REDIRECT_SIGN_OUT || 'http://localhost:3002/auth/logout'
    },
    endpoints: {
      apiGateway: process.env.API_GATEWAY_URL || 'http://localhost:8443/api/v1',
      userService: process.env.USER_SERVICE_URL || 'http://localhost:8001'
    }
  },

  // Staging environment - for testing
  staging: {
    userPoolId: validateRequired(process.env.AWS_COGNITO_USER_POOL_ID, 'AWS_COGNITO_USER_POOL_ID'),
    clientId: validateRequired(process.env.AWS_COGNITO_CLIENT_ID, 'AWS_COGNITO_CLIENT_ID'),
    region: validateRequired(process.env.AWS_REGION, 'AWS_REGION'),
    identityPoolId: process.env.AWS_COGNITO_IDENTITY_POOL_ID,
    oauth: {
      domain: validateRequired(process.env.AWS_COGNITO_DOMAIN, 'AWS_COGNITO_DOMAIN'),
      redirectSignIn: validateRequired(process.env.COGNITO_REDIRECT_SIGN_IN, 'COGNITO_REDIRECT_SIGN_IN'),
      redirectSignOut: validateRequired(process.env.COGNITO_REDIRECT_SIGN_OUT, 'COGNITO_REDIRECT_SIGN_OUT')
    },
    endpoints: {
      apiGateway: validateRequired(process.env.API_GATEWAY_URL, 'API_GATEWAY_URL'),
      userService: validateRequired(process.env.USER_SERVICE_URL, 'USER_SERVICE_URL')
    }
  },

  // Production environment - strict validation
  production: {
    userPoolId: validateRequired(process.env.AWS_COGNITO_USER_POOL_ID, 'AWS_COGNITO_USER_POOL_ID'),
    clientId: validateRequired(process.env.AWS_COGNITO_CLIENT_ID, 'AWS_COGNITO_CLIENT_ID'),
    region: validateRequired(process.env.AWS_REGION, 'AWS_REGION'),
    identityPoolId: process.env.AWS_COGNITO_IDENTITY_POOL_ID,
    oauth: {
      domain: validateRequired(process.env.AWS_COGNITO_DOMAIN, 'AWS_COGNITO_DOMAIN'),
      redirectSignIn: validateRequired(process.env.COGNITO_REDIRECT_SIGN_IN, 'COGNITO_REDIRECT_SIGN_IN'),
      redirectSignOut: validateRequired(process.env.COGNITO_REDIRECT_SIGN_OUT, 'COGNITO_REDIRECT_SIGN_OUT')
    },
    endpoints: {
      apiGateway: validateRequired(process.env.API_GATEWAY_URL, 'API_GATEWAY_URL'),
      userService: validateRequired(process.env.USER_SERVICE_URL, 'USER_SERVICE_URL')
    }
  }
};

/**
 * Get AWS configuration for current environment
 * @param {string} environment - Environment name (dev, staging, production)
 * @returns {object} AWS configuration object
 */
const getAWSConfig = (environment = process.env.ENVIRONMENT || 'dev') => {
  const config = AWS_CONFIG[environment];
  
  if (!config) {
    throw new Error(`Unknown environment: ${environment}. Supported: dev, staging, production`);
  }
  
  return {
    ...config,
    environment,
    timestamp: new Date().toISOString()
  };
};

/**
 * Validate AWS configuration for current environment
 * @param {string} environment - Environment name
 * @returns {boolean} true if configuration is valid
 */
const validateAWSConfig = (environment = process.env.ENVIRONMENT || 'dev') => {
  try {
    const config = getAWSConfig(environment);
    
    // Basic validation
    if (!config.userPoolId || !config.clientId || !config.region) {
      return false;
    }
    
    // Environment-specific validation
    if (environment === 'production') {
      // Production requires all fields to be set
      return !!(config.oauth.domain && config.oauth.redirectSignIn && 
               config.oauth.redirectSignOut && config.endpoints.apiGateway);
    }
    
    return true;
  } catch (error) {
    console.error('AWS configuration validation failed:', error.message);
    return false;
  }
};

module.exports = {
  AWS_CONFIG,
  getAWSConfig,
  validateAWSConfig
};