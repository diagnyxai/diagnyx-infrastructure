const LambdaRunner = require('../lambda-runner');
const MockApiServer = require('../mock-api-server');

describe('Post-Confirmation Lambda Tests', () => {
  let lambdaRunner;
  let mockServer;
  let serverPort = 8444;

  beforeAll(async () => {
    // Start mock API server
    mockServer = new MockApiServer(serverPort);
    await mockServer.start();
    
    // Initialize Lambda runner
    lambdaRunner = new LambdaRunner();
    
    // Wait for server to be ready
    await new Promise(resolve => setTimeout(resolve, 1000));
  });

  afterAll(async () => {
    if (mockServer) {
      await mockServer.stop();
    }
  });

  beforeEach(() => {
    // Reset server state before each test
    mockServer.reset();
  });

  describe('Basic Functionality', () => {
    test('should load post-confirmation Lambda function', () => {
      const availableFunctions = lambdaRunner.getAvailableFunctions();
      expect(availableFunctions).toContain('post-confirmation');
    });

    test('should process post-confirmation trigger successfully', async () => {
      const userAttributes = {
        sub: 'test-user-123',
        email: 'john.doe@example.com',
        given_name: 'John',
        family_name: 'Doe',
        'custom:account_type': 'INDIVIDUAL'
      };

      const result = await lambdaRunner.runPostConfirmation(userAttributes);

      // Lambda should return the original event
      expect(result).toBeDefined();
      expect(result.triggerSource).toBe('PostConfirmation_ConfirmSignUp');
      expect(result.request.userAttributes.email).toBe('john.doe@example.com');
    });

    test('should create user record in database via API call', async () => {
      const userAttributes = {
        sub: 'test-user-456',
        email: 'jane.smith@example.com',
        given_name: 'Jane',
        family_name: 'Smith',
        'custom:account_type': 'TEAM'
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      // Verify API call was made
      const requests = mockServer.getRequests();
      const activationRequest = requests.find(req => 
        req.path === '/api/v1/internal/user/activate' && req.method === 'POST'
      );

      expect(activationRequest).toBeDefined();
      expect(activationRequest.body.action).toBe('activateUser');
      expect(activationRequest.body.data.cognitoSub).toBe('test-user-456');
      expect(activationRequest.body.data.email).toBe('jane.smith@example.com');
      expect(activationRequest.body.data.firstName).toBe('Jane');
      expect(activationRequest.body.data.lastName).toBe('Smith');
      expect(activationRequest.body.data.accountType).toBe('TEAM');
    });

    test('should create user with proper authentication headers', async () => {
      const userAttributes = {
        sub: 'test-user-789',
        email: 'test@example.com'
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      const requests = mockServer.getRequests();
      const activationRequest = requests.find(req => 
        req.path === '/api/v1/internal/user/activate'
      );

      expect(activationRequest.headers['x-internal-api-key']).toBe('test-internal-key');
      expect(activationRequest.headers['content-type']).toBe('application/json');
      expect(activationRequest.headers['user-agent']).toBe('Cognito-PostConfirmation-Lambda');
    });
  });

  describe('Different Account Types', () => {
    test('should handle INDIVIDUAL account type', async () => {
      const userAttributes = {
        sub: 'individual-user',
        email: 'individual@example.com',
        'custom:account_type': 'INDIVIDUAL'
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      const user = mockServer.getUser('individual-user');
      expect(user).toBeDefined();
      expect(user.accountType).toBe('INDIVIDUAL');
      expect(user.email).toBe('individual@example.com');
    });

    test('should handle TEAM account type', async () => {
      const userAttributes = {
        sub: 'team-user',
        email: 'team@example.com',
        'custom:account_type': 'TEAM',
        'custom:organization_id': 'org-123'
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      const user = mockServer.getUser('team-user');
      expect(user).toBeDefined();
      expect(user.accountType).toBe('TEAM');
      expect(user.organizationId).toBe('org-123');
    });

    test('should handle ENTERPRISE account type', async () => {
      const userAttributes = {
        sub: 'enterprise-user',
        email: 'enterprise@example.com',
        'custom:account_type': 'ENTERPRISE',
        'custom:organization_id': 'enterprise-org'
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      const user = mockServer.getUser('enterprise-user');
      expect(user).toBeDefined();
      expect(user.accountType).toBe('ENTERPRISE');
      expect(user.organizationId).toBe('enterprise-org');
    });

    test('should default to INDIVIDUAL when account type is missing', async () => {
      const userAttributes = {
        sub: 'default-user',
        email: 'default@example.com'
        // No account type specified
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      const user = mockServer.getUser('default-user');
      expect(user).toBeDefined();
      expect(user.accountType).toBe('INDIVIDUAL');
    });
  });

  describe('Error Handling', () => {
    test('should handle API server unavailable gracefully', async () => {
      // Stop the mock server to simulate unavailability
      await mockServer.stop();

      const userAttributes = {
        sub: 'error-user',
        email: 'error@example.com'
      };

      // Lambda should not throw error even if API call fails
      const result = await lambdaRunner.runPostConfirmation(userAttributes);
      
      expect(result).toBeDefined();
      expect(result.triggerSource).toBe('PostConfirmation_ConfirmSignUp');

      // Restart server for other tests
      mockServer = new MockApiServer(serverPort);
      await mockServer.start();
    });

    test('should handle invalid API response gracefully', async () => {
      // Mock server will return error for this specific user
      const userAttributes = {
        sub: '', // Empty sub will cause validation error
        email: 'invalid@example.com'
      };

      const result = await lambdaRunner.runPostConfirmation(userAttributes);
      
      expect(result).toBeDefined();
      expect(result.triggerSource).toBe('PostConfirmation_ConfirmSignUp');
    });

    test('should only process post-confirmation triggers', async () => {
      const event = lambdaRunner.createPostConfirmationEvent();
      event.triggerSource = 'PreSignUp_SignUp'; // Different trigger

      const result = await lambdaRunner.executeLambda('post-confirmation', event);

      // Should return event unchanged without processing
      expect(result).toEqual(event);
      
      // No API calls should have been made
      const requests = mockServer.getRequests();
      expect(requests.length).toBe(0);
    });

    test('should handle missing user attributes gracefully', async () => {
      const userAttributes = {
        sub: 'minimal-user'
        // Missing required email
      };

      const result = await lambdaRunner.runPostConfirmation(userAttributes);
      
      expect(result).toBeDefined();
      expect(result.triggerSource).toBe('PostConfirmation_ConfirmSignUp');
    });
  });

  describe('Trigger Source Validation', () => {
    test('should process PostConfirmation_ConfirmSignUp trigger', async () => {
      const event = lambdaRunner.createPostConfirmationEvent();
      event.triggerSource = 'PostConfirmation_ConfirmSignUp';

      await lambdaRunner.executeLambda('post-confirmation', event);

      const requests = mockServer.getRequests();
      expect(requests.length).toBeGreaterThan(0);
    });

    test('should process PostConfirmation_ConfirmForgotPassword trigger', async () => {
      const event = lambdaRunner.createPostConfirmationEvent();
      event.triggerSource = 'PostConfirmation_ConfirmForgotPassword';

      await lambdaRunner.executeLambda('post-confirmation', event);

      const requests = mockServer.getRequests();
      expect(requests.length).toBeGreaterThan(0);
    });

    test('should ignore other trigger sources', async () => {
      const event = lambdaRunner.createPostConfirmationEvent();
      event.triggerSource = 'PreSignUp_SignUp';

      await lambdaRunner.executeLambda('post-confirmation', event);

      const requests = mockServer.getRequests();
      expect(requests.length).toBe(0);
    });
  });

  describe('Environment Configuration', () => {
    test('should use custom API endpoint', async () => {
      const customPort = 9999;
      const customServer = new MockApiServer(customPort);
      await customServer.start();

      try {
        const userAttributes = {
          sub: 'custom-endpoint-user',
          email: 'custom@example.com'
        };

        await lambdaRunner.runPostConfirmation(userAttributes, {
          API_ENDPOINT: `http://localhost:${customPort}`,
          INTERNAL_API_KEY: 'custom-key'
        });

        const requests = customServer.getRequests();
        expect(requests.length).toBeGreaterThan(0);
        
        const activationRequest = requests.find(req => 
          req.path === '/api/v1/internal/user/activate'
        );
        expect(activationRequest.headers['x-internal-api-key']).toBe('custom-key');

      } finally {
        await customServer.stop();
      }
    });

    test('should use default values when environment variables are missing', async () => {
      const userAttributes = {
        sub: 'default-env-user',
        email: 'default@example.com'
      };

      // Clear environment variables
      await lambdaRunner.runPostConfirmation(userAttributes, {
        API_ENDPOINT: undefined,
        INTERNAL_API_KEY: undefined
      });

      const requests = mockServer.getRequests();
      const activationRequest = requests.find(req => 
        req.path === '/api/v1/internal/user/activate'
      );

      // Should use default values
      expect(activationRequest.headers['x-internal-api-key']).toBe('dev-internal-key');
    });
  });

  describe('Data Validation', () => {
    test('should extract all user attributes correctly', async () => {
      const userAttributes = {
        sub: 'full-data-user',
        email: 'fulldata@example.com',
        given_name: 'Full',
        family_name: 'Data User',
        'custom:account_type': 'ENTERPRISE',
        'custom:organization_id': 'full-org-123'
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      const user = mockServer.getUser('full-data-user');
      expect(user).toBeDefined();
      expect(user.cognitoSub).toBe('full-data-user');
      expect(user.email).toBe('fulldata@example.com');
      expect(user.firstName).toBe('Full');
      expect(user.lastName).toBe('Data User');
      expect(user.accountType).toBe('ENTERPRISE');
      expect(user.organizationId).toBe('full-org-123');
      expect(user.role).toBe('OWNER');
      expect(user.isActive).toBe(true);
    });

    test('should handle empty or null custom attributes', async () => {
      const userAttributes = {
        sub: 'empty-custom-user',
        email: 'emptycustom@example.com',
        given_name: 'Empty',
        family_name: 'Custom',
        'custom:account_type': '',
        'custom:organization_id': null
      };

      await lambdaRunner.runPostConfirmation(userAttributes);

      const user = mockServer.getUser('empty-custom-user');
      expect(user).toBeDefined();
      expect(user.accountType).toBe('INDIVIDUAL'); // Should default
      expect(user.organizationId).toBeNull();
    });
  });
});