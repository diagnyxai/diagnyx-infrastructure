/**
 * Centralized AWS Configuration for Diagnyx Services (TypeScript)
 * 
 * This file provides a single source of truth for AWS configurations
 * across all Diagnyx services with proper TypeScript typing.
 */

export interface OAuthConfig {
  domain: string;
  redirectSignIn: string;
  redirectSignOut: string;
}

export interface EndpointsConfig {
  apiGateway: string;
  userService: string;
}

export interface AWSEnvironmentConfig {
  userPoolId: string;
  clientId: string;
  region: string;
  identityPoolId?: string;
  oauth: OAuthConfig;
  endpoints: EndpointsConfig;
}

export interface AWSConfigWithMeta extends AWSEnvironmentConfig {
  environment: string;
  timestamp: string;
}

const validateRequired = (value: string | undefined, name: string): string => {
  if (!value) {
    throw new Error(`Required environment variable ${name} is not set`);
  }
  return value;
};

export const AWS_CONFIG: Record<string, AWSEnvironmentConfig> = {
  // Development environment - for local development  
  dev: {
    userPoolId: process.env.NEXT_PUBLIC_AWS_COGNITO_USER_POOL_ID || 'us-east-1_I9BoDreCg',
    clientId: process.env.NEXT_PUBLIC_AWS_COGNITO_CLIENT_ID || '4tnfqqkk59scbf0o90q488ec08',
    region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1',
    identityPoolId: process.env.NEXT_PUBLIC_AWS_COGNITO_IDENTITY_POOL_ID,
    oauth: {
      domain: process.env.NEXT_PUBLIC_AWS_COGNITO_DOMAIN || 'diagnyx-dev-auth.auth.us-east-1.amazoncognito.com',
      redirectSignIn: process.env.NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_IN || 'http://localhost:3002/auth/callback',
      redirectSignOut: process.env.NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_OUT || 'http://localhost:3002/auth/logout'
    },
    endpoints: {
      apiGateway: process.env.NEXT_PUBLIC_API_GATEWAY_URL || 'http://localhost:8443/api/v1',
      userService: process.env.NEXT_PUBLIC_USER_SERVICE_URL || 'http://localhost:8001'
    }
  },

  // Staging environment - for testing
  staging: {
    userPoolId: validateRequired(process.env.NEXT_PUBLIC_AWS_COGNITO_USER_POOL_ID, 'NEXT_PUBLIC_AWS_COGNITO_USER_POOL_ID'),
    clientId: validateRequired(process.env.NEXT_PUBLIC_AWS_COGNITO_CLIENT_ID, 'NEXT_PUBLIC_AWS_COGNITO_CLIENT_ID'),
    region: validateRequired(process.env.NEXT_PUBLIC_AWS_REGION, 'NEXT_PUBLIC_AWS_REGION'),
    identityPoolId: process.env.NEXT_PUBLIC_AWS_COGNITO_IDENTITY_POOL_ID,
    oauth: {
      domain: validateRequired(process.env.NEXT_PUBLIC_AWS_COGNITO_DOMAIN, 'NEXT_PUBLIC_AWS_COGNITO_DOMAIN'),
      redirectSignIn: validateRequired(process.env.NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_IN, 'NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_IN'),
      redirectSignOut: validateRequired(process.env.NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_OUT, 'NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_OUT')
    },
    endpoints: {
      apiGateway: validateRequired(process.env.NEXT_PUBLIC_API_GATEWAY_URL, 'NEXT_PUBLIC_API_GATEWAY_URL'),
      userService: validateRequired(process.env.NEXT_PUBLIC_USER_SERVICE_URL, 'NEXT_PUBLIC_USER_SERVICE_URL')
    }
  },

  // Production environment - strict validation
  production: {
    userPoolId: validateRequired(process.env.NEXT_PUBLIC_AWS_COGNITO_USER_POOL_ID, 'NEXT_PUBLIC_AWS_COGNITO_USER_POOL_ID'),
    clientId: validateRequired(process.env.NEXT_PUBLIC_AWS_COGNITO_CLIENT_ID, 'NEXT_PUBLIC_AWS_COGNITO_CLIENT_ID'),
    region: validateRequired(process.env.NEXT_PUBLIC_AWS_REGION, 'NEXT_PUBLIC_AWS_REGION'),
    identityPoolId: process.env.NEXT_PUBLIC_AWS_COGNITO_IDENTITY_POOL_ID,
    oauth: {
      domain: validateRequired(process.env.NEXT_PUBLIC_AWS_COGNITO_DOMAIN, 'NEXT_PUBLIC_AWS_COGNITO_DOMAIN'),
      redirectSignIn: validateRequired(process.env.NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_IN, 'NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_IN'),
      redirectSignOut: validateRequired(process.env.NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_OUT, 'NEXT_PUBLIC_COGNITO_REDIRECT_SIGN_OUT')
    },
    endpoints: {
      apiGateway: validateRequired(process.env.NEXT_PUBLIC_API_GATEWAY_URL, 'NEXT_PUBLIC_API_GATEWAY_URL'),
      userService: validateRequired(process.env.NEXT_PUBLIC_USER_SERVICE_URL, 'NEXT_PUBLIC_USER_SERVICE_URL')
    }
  }
};

/**
 * Get AWS configuration for current environment
 * @param environment - Environment name (dev, staging, production)
 * @returns AWS configuration object with metadata
 */
export const getAWSConfig = (environment: string = process.env.NODE_ENV || 'dev'): AWSConfigWithMeta => {
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
 * @param environment - Environment name
 * @returns true if configuration is valid
 */
export const validateAWSConfig = (environment: string = process.env.NODE_ENV || 'dev'): boolean => {
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
    console.error('AWS configuration validation failed:', (error as Error).message);
    return false;
  }
};

export default AWS_CONFIG;