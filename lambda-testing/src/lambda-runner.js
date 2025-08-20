const fs = require('fs');
const path = require('path');

/**
 * Local Lambda function runner for testing
 */
class LambdaRunner {
  constructor() {
    this.lambdaFunctions = new Map();
    this.loadLambdaFunctions();
  }

  loadLambdaFunctions() {
    // Load post-confirmation Lambda
    const postConfirmationPath = path.join(__dirname, '../../repositories/diagnyx-infra/lambda/cognito-triggers/post-confirmation/index.js');
    if (fs.existsSync(postConfirmationPath)) {
      delete require.cache[require.resolve(postConfirmationPath)];
      this.lambdaFunctions.set('post-confirmation', require(postConfirmationPath));
      console.log('Loaded post-confirmation Lambda function');
    }

    // Load pre-token-generation Lambda
    const preTokenPath = path.join(__dirname, '../../repositories/diagnyx-infra/lambda/cognito-triggers/pre-token-generation/index.js');
    if (fs.existsSync(preTokenPath)) {
      delete require.cache[require.resolve(preTokenPath)];
      this.lambdaFunctions.set('pre-token-generation', require(preTokenPath));
      console.log('Loaded pre-token-generation Lambda function');
    }
  }

  /**
   * Execute a Lambda function with test event and context
   */
  async executeLambda(functionName, event, context = {}) {
    const lambdaFunction = this.lambdaFunctions.get(functionName);
    if (!lambdaFunction) {
      throw new Error(`Lambda function '${functionName}' not found`);
    }

    // Default context
    const defaultContext = {
      callbackWaitsForEmptyEventLoop: false,
      functionName: functionName,
      functionVersion: '$LATEST',
      invokedFunctionArn: `arn:aws:lambda:us-east-1:123456789012:function:${functionName}`,
      memoryLimitInMB: '128',
      awsRequestId: 'test-request-id-' + Date.now(),
      logGroupName: `/aws/lambda/${functionName}`,
      logStreamName: `test-stream-${Date.now()}`,
      getRemainingTimeInMillis: () => 30000
    };

    const mergedContext = { ...defaultContext, ...context };

    console.log(`Executing Lambda function: ${functionName}`);
    console.log('Event:', JSON.stringify(event, null, 2));

    try {
      const result = await lambdaFunction.handler(event, mergedContext);
      console.log('Lambda execution completed successfully');
      return result;
    } catch (error) {
      console.error('Lambda execution failed:', error);
      throw error;
    }
  }

  /**
   * Create a Cognito post-confirmation event
   */
  createPostConfirmationEvent(userAttributes = {}) {
    const defaultAttributes = {
      sub: 'test-cognito-sub-' + Date.now(),
      email: 'test@example.com',
      email_verified: 'true',
      given_name: 'Test',
      family_name: 'User',
      'custom:account_type': 'INDIVIDUAL'
    };

    return {
      version: '1',
      region: 'us-east-1',
      userPoolId: 'us-east-1_test123456',
      userName: userAttributes.email || defaultAttributes.email,
      triggerSource: 'PostConfirmation_ConfirmSignUp',
      request: {
        userAttributes: { ...defaultAttributes, ...userAttributes }
      },
      response: {}
    };
  }

  /**
   * Create a Cognito pre-token-generation event
   */
  createPreTokenGenerationEvent(userAttributes = {}) {
    const defaultAttributes = {
      sub: 'test-cognito-sub-' + Date.now(),
      email: 'test@example.com',
      email_verified: 'true',
      given_name: 'Test',
      family_name: 'User',
      'custom:account_type': 'INDIVIDUAL'
    };

    return {
      version: '1',
      region: 'us-east-1',
      userPoolId: 'us-east-1_test123456',
      userName: userAttributes.email || defaultAttributes.email,
      triggerSource: 'TokenGeneration_HostedAuth',
      request: {
        userAttributes: { ...defaultAttributes, ...userAttributes },
        clientMetadata: {},
        groupConfiguration: {}
      },
      response: {
        claimsOverrideDetails: {}
      }
    };
  }

  /**
   * Create a test context with custom values
   */
  createContext(overrides = {}) {
    return {
      callbackWaitsForEmptyEventLoop: false,
      functionName: 'test-function',
      functionVersion: '$LATEST',
      invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:test-function',
      memoryLimitInMB: '128',
      awsRequestId: 'test-request-id-' + Date.now(),
      logGroupName: '/aws/lambda/test-function',
      logStreamName: 'test-stream-' + Date.now(),
      getRemainingTimeInMillis: () => 30000,
      ...overrides
    };
  }

  /**
   * Run post-confirmation Lambda with test data
   */
  async runPostConfirmation(userAttributes = {}, environment = {}) {
    // Set environment variables
    const originalEnv = { ...process.env };
    process.env = {
      ...process.env,
      API_ENDPOINT: 'http://localhost:8445',
      INTERNAL_API_KEY: 'test-internal-key',
      ENVIRONMENT: 'test',
      ...environment
    };

    try {
      const event = this.createPostConfirmationEvent(userAttributes);
      const context = this.createContext();
      const result = await this.executeLambda('post-confirmation', event, context);
      return result;
    } finally {
      // Restore original environment
      process.env = originalEnv;
    }
  }

  /**
   * Run pre-token-generation Lambda with test data
   */
  async runPreTokenGeneration(userAttributes = {}, environment = {}) {
    // Set environment variables
    const originalEnv = { ...process.env };
    process.env = {
      ...process.env,
      ENVIRONMENT: 'test',
      ...environment
    };

    try {
      const event = this.createPreTokenGenerationEvent(userAttributes);
      const context = this.createContext();
      const result = await this.executeLambda('pre-token-generation', event, context);
      return result;
    } finally {
      // Restore original environment
      process.env = originalEnv;
    }
  }

  /**
   * Get available Lambda functions
   */
  getAvailableFunctions() {
    return Array.from(this.lambdaFunctions.keys());
  }

  /**
   * Reload Lambda functions (useful for testing code changes)
   */
  reloadFunctions() {
    this.lambdaFunctions.clear();
    this.loadLambdaFunctions();
  }
}

module.exports = LambdaRunner;