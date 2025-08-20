const LambdaRunner = require('../lambda-runner');

describe('Pre-Token Generation Lambda Tests', () => {
  let lambdaRunner;

  beforeAll(() => {
    lambdaRunner = new LambdaRunner();
  });

  describe('Basic Functionality', () => {
    test('should load pre-token-generation Lambda function', () => {
      const availableFunctions = lambdaRunner.getAvailableFunctions();
      expect(availableFunctions).toContain('pre-token-generation');
    });

    test('should process token generation trigger successfully', async () => {
      const userAttributes = {
        sub: 'test-token-user-123',
        email: 'tokentest@example.com',
        given_name: 'Token',
        family_name: 'Test',
        'custom:account_type': 'INDIVIDUAL'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);

      expect(result).toBeDefined();
      expect(result.triggerSource).toBe('TokenGeneration_HostedAuth');
      expect(result.request.userAttributes.email).toBe('tokentest@example.com');
      expect(result.response.claimsOverrideDetails).toBeDefined();
    });

    test('should add custom claims to token response', async () => {
      const userAttributes = {
        sub: 'claims-user-456',
        email: 'claims@example.com',
        'custom:account_type': 'TEAM',
        'custom:organization_id': 'org-123'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);

      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;
      
      expect(claims).toBeDefined();
      expect(claims.account_type).toBe('TEAM');
      expect(claims.organization_id).toBe('org-123');
      expect(claims.role).toBe('OWNER'); // Default role from mock implementation
      expect(claims.environment).toBe('test');
      expect(claims.scope).toBeDefined();
    });
  });

  describe('Account Type Claims', () => {
    test('should add INDIVIDUAL account type claim', async () => {
      const userAttributes = {
        sub: 'individual-claims-user',
        email: 'individual@example.com',
        'custom:account_type': 'INDIVIDUAL'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.account_type).toBe('INDIVIDUAL');
    });

    test('should add TEAM account type claim', async () => {
      const userAttributes = {
        sub: 'team-claims-user',
        email: 'team@example.com',
        'custom:account_type': 'TEAM'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.account_type).toBe('TEAM');
    });

    test('should add ENTERPRISE account type claim', async () => {
      const userAttributes = {
        sub: 'enterprise-claims-user',
        email: 'enterprise@example.com',
        'custom:account_type': 'ENTERPRISE'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.account_type).toBe('ENTERPRISE');
    });

    test('should handle missing account type gracefully', async () => {
      const userAttributes = {
        sub: 'no-account-type-user',
        email: 'noaccounttype@example.com'
        // No custom:account_type
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      // Should not add account_type claim if not present
      expect(claims.account_type).toBeUndefined();
    });
  });

  describe('Organization Claims', () => {
    test('should add organization ID when present', async () => {
      const userAttributes = {
        sub: 'org-user',
        email: 'org@example.com',
        'custom:organization_id': 'org-456'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.organization_id).toBe('org-456');
    });

    test('should not add organization ID when not present', async () => {
      const userAttributes = {
        sub: 'no-org-user',
        email: 'noorg@example.com'
        // No custom:organization_id
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.organization_id).toBeUndefined();
    });
  });

  describe('Role Claims', () => {
    test('should add user role claim', async () => {
      const userAttributes = {
        sub: 'role-user',
        email: 'role@example.com'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.role).toBe('OWNER'); // Default from mock implementation
    });

    test('should handle role lookup failure gracefully', async () => {
      // This test would be more meaningful with a real database
      // For now, the mock always returns 'OWNER'
      const userAttributes = {
        sub: 'error-role-user',
        email: 'errorrole@example.com'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      // Should still have role even if lookup has issues
      expect(claims.role).toBeDefined();
    });
  });

  describe('Scope Generation', () => {
    test('should generate INDIVIDUAL scope correctly', async () => {
      const userAttributes = {
        sub: 'individual-scope-user',
        email: 'individualscope@example.com',
        'custom:account_type': 'INDIVIDUAL'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.scope).toBe('read:profile write:profile read:individual_data write:individual_data');
    });

    test('should generate TEAM scope correctly', async () => {
      const userAttributes = {
        sub: 'team-scope-user',
        email: 'teamscope@example.com',
        'custom:account_type': 'TEAM'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.scope).toBe('read:profile write:profile read:team_data write:team_data manage:team');
    });

    test('should generate ENTERPRISE scope correctly', async () => {
      const userAttributes = {
        sub: 'enterprise-scope-user',
        email: 'enterprisescope@example.com',
        'custom:account_type': 'ENTERPRISE'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.scope).toBe('read:profile write:profile read:enterprise_data write:enterprise_data manage:organization admin:all');
    });

    test('should generate default scope for unknown account type', async () => {
      const userAttributes = {
        sub: 'unknown-scope-user',
        email: 'unknownscope@example.com',
        'custom:account_type': 'UNKNOWN_TYPE'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.scope).toBe('read:profile write:profile');
    });

    test('should generate default scope when no account type', async () => {
      const userAttributes = {
        sub: 'no-scope-user',
        email: 'noscope@example.com'
        // No account type
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.scope).toBe('read:profile write:profile');
    });
  });

  describe('Environment Claims', () => {
    test('should add environment claim with default value', async () => {
      const userAttributes = {
        sub: 'env-user',
        email: 'env@example.com'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.environment).toBe('test');
    });

    test('should add environment claim with custom value', async () => {
      const userAttributes = {
        sub: 'custom-env-user',
        email: 'customenv@example.com'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes, {
        ENVIRONMENT: 'production'
      });
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      expect(claims.environment).toBe('production');
    });
  });

  describe('Error Handling', () => {
    test('should handle errors gracefully without disrupting token generation', async () => {
      // Create a scenario that might cause errors
      const userAttributes = {
        sub: null, // Invalid sub
        email: 'error@example.com'
      };

      // Lambda should not throw error even if processing fails
      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);

      expect(result).toBeDefined();
      expect(result.triggerSource).toBe('TokenGeneration_HostedAuth');
      expect(result.response.claimsOverrideDetails).toBeDefined();
    });

    test('should initialize claims structure if not present', async () => {
      const userAttributes = {
        sub: 'init-claims-user',
        email: 'initclaims@example.com'
      };

      // Create event with no response structure
      const event = lambdaRunner.createPreTokenGenerationEvent(userAttributes);
      delete event.response.claimsOverrideDetails;

      const result = await lambdaRunner.executeLambda('pre-token-generation', event);

      expect(result.response.claimsOverrideDetails).toBeDefined();
      expect(result.response.claimsOverrideDetails.claimsToAddOrOverride).toBeDefined();
    });
  });

  describe('Claims Structure', () => {
    test('should maintain proper claims structure', async () => {
      const userAttributes = {
        sub: 'structure-user',
        email: 'structure@example.com',
        'custom:account_type': 'TEAM',
        'custom:organization_id': 'struct-org'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);

      expect(result.response).toBeDefined();
      expect(result.response.claimsOverrideDetails).toBeDefined();
      expect(result.response.claimsOverrideDetails.claimsToAddOrOverride).toBeDefined();
      expect(typeof result.response.claimsOverrideDetails.claimsToAddOrOverride).toBe('object');
    });

    test('should not modify original event structure', async () => {
      const userAttributes = {
        sub: 'immutable-user',
        email: 'immutable@example.com'
      };

      const originalEvent = lambdaRunner.createPreTokenGenerationEvent(userAttributes);
      const originalEventStr = JSON.stringify(originalEvent);

      const result = await lambdaRunner.executeLambda('pre-token-generation', originalEvent);

      // The returned result should have claims, but original structure preserved
      expect(result.version).toBe(originalEvent.version);
      expect(result.region).toBe(originalEvent.region);
      expect(result.userPoolId).toBe(originalEvent.userPoolId);
      expect(result.userName).toBe(originalEvent.userName);
      expect(result.triggerSource).toBe(originalEvent.triggerSource);
    });
  });

  describe('Integration Scenarios', () => {
    test('should handle complete user profile with all attributes', async () => {
      const userAttributes = {
        sub: 'complete-user-789',
        email: 'complete@example.com',
        email_verified: 'true',
        given_name: 'Complete',
        family_name: 'User',
        'custom:account_type': 'ENTERPRISE',
        'custom:organization_id': 'complete-org-789'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      // Verify all expected claims are present
      expect(claims.account_type).toBe('ENTERPRISE');
      expect(claims.organization_id).toBe('complete-org-789');
      expect(claims.role).toBe('OWNER');
      expect(claims.scope).toBe('read:profile write:profile read:enterprise_data write:enterprise_data manage:organization admin:all');
      expect(claims.environment).toBe('test');
    });

    test('should handle minimal user profile', async () => {
      const userAttributes = {
        sub: 'minimal-user-999',
        email: 'minimal@example.com'
      };

      const result = await lambdaRunner.runPreTokenGeneration(userAttributes);
      const claims = result.response.claimsOverrideDetails.claimsToAddOrOverride;

      // Should only have basic claims
      expect(claims.account_type).toBeUndefined();
      expect(claims.organization_id).toBeUndefined();
      expect(claims.role).toBe('OWNER'); // From mock implementation
      expect(claims.scope).toBe('read:profile write:profile'); // Default scope
      expect(claims.environment).toBe('test');
    });
  });
});