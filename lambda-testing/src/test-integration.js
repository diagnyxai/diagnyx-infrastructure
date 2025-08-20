const LambdaRunner = require('./lambda-runner');
const MockApiServer = require('./mock-api-server');

/**
 * Integration test script for Lambda functions
 * Tests the complete flow: Post-confirmation -> User activation -> Pre-token with claims
 */
async function runIntegrationTests() {
  console.log('🚀 Starting Lambda Integration Tests...\n');

  const lambdaRunner = new LambdaRunner();
  const mockServer = new MockApiServer(8445);

  try {
    // Start mock API server
    console.log('📡 Starting mock API server...');
    await mockServer.start();
    console.log('✅ Mock API server started on port 8445\n');

    // Test scenarios
    const testScenarios = [
      {
        name: 'Individual User Signup Flow',
        userAttributes: {
          sub: 'individual-integration-user',
          email: 'individual@diagnyx.com',
          given_name: 'John',
          family_name: 'Individual',
          'custom:account_type': 'INDIVIDUAL'
        }
      },
      {
        name: 'Team User Signup Flow',
        userAttributes: {
          sub: 'team-integration-user',
          email: 'team@diagnyx.com',
          given_name: 'Jane',
          family_name: 'Team',
          'custom:account_type': 'TEAM',
          'custom:organization_id': 'team-org-123'
        }
      },
      {
        name: 'Enterprise User Signup Flow',
        userAttributes: {
          sub: 'enterprise-integration-user',
          email: 'enterprise@diagnyx.com',
          given_name: 'Bob',
          family_name: 'Enterprise',
          'custom:account_type': 'ENTERPRISE',
          'custom:organization_id': 'enterprise-org-456'
        }
      }
    ];

    for (const scenario of testScenarios) {
      console.log(`🧪 Testing: ${scenario.name}`);
      await runScenario(lambdaRunner, mockServer, scenario);
      console.log('');
    }

    // Test error scenarios
    console.log('🔥 Testing Error Scenarios...');
    await testErrorScenarios(lambdaRunner, mockServer);

    // Test performance
    console.log('⚡ Testing Performance...');
    await testPerformance(lambdaRunner, mockServer);

    console.log('🎉 All integration tests completed successfully!');

  } catch (error) {
    console.error('❌ Integration tests failed:', error);
    process.exit(1);
  } finally {
    // Cleanup
    console.log('\n🧹 Cleaning up...');
    await mockServer.stop();
    console.log('✅ Cleanup completed');
  }
}

async function runScenario(lambdaRunner, mockServer, scenario) {
  const { name, userAttributes } = scenario;

  try {
    // Step 1: Simulate post-confirmation trigger
    console.log('  🔸 Step 1: Running post-confirmation trigger');
    const postConfirmationResult = await lambdaRunner.runPostConfirmation(userAttributes);
    
    if (!postConfirmationResult || postConfirmationResult.triggerSource !== 'PostConfirmation_ConfirmSignUp') {
      throw new Error('Post-confirmation trigger failed');
    }
    console.log('  ✅ Post-confirmation trigger completed');

    // Step 2: Verify user was created in database
    console.log('  🔸 Step 2: Verifying user activation');
    const user = mockServer.getUser(userAttributes.sub);
    
    if (!user) {
      throw new Error('User was not created in database');
    }

    // Validate user data
    if (user.email !== userAttributes.email) {
      throw new Error(`Email mismatch: expected ${userAttributes.email}, got ${user.email}`);
    }

    if (user.accountType !== userAttributes['custom:account_type']) {
      throw new Error(`Account type mismatch: expected ${userAttributes['custom:account_type']}, got ${user.accountType}`);
    }

    console.log('  ✅ User activation verified');
    console.log(`     - User ID: ${user.id}`);
    console.log(`     - Email: ${user.email}`);
    console.log(`     - Account Type: ${user.accountType}`);
    console.log(`     - Role: ${user.role}`);

    // Step 3: Simulate pre-token generation trigger
    console.log('  🔸 Step 3: Running pre-token generation trigger');
    const preTokenResult = await lambdaRunner.runPreTokenGeneration(userAttributes);
    
    if (!preTokenResult || !preTokenResult.response.claimsOverrideDetails) {
      throw new Error('Pre-token generation trigger failed');
    }

    const claims = preTokenResult.response.claimsOverrideDetails.claimsToAddOrOverride;
    console.log('  ✅ Pre-token generation completed');
    console.log('     - Custom claims added:');
    Object.entries(claims).forEach(([key, value]) => {
      console.log(`       ${key}: ${value}`);
    });

    // Step 4: Validate claims
    console.log('  🔸 Step 4: Validating token claims');
    validateClaims(claims, userAttributes);
    console.log('  ✅ Token claims validated');

    // Step 5: Verify API integration
    console.log('  🔸 Step 5: Verifying API integration');
    const requests = mockServer.getRequests().filter(req => 
      req.body?.data?.cognitoSub === userAttributes.sub
    );

    if (requests.length === 0) {
      throw new Error('No API requests found for user activation');
    }

    const activationRequest = requests.find(req => 
      req.path === '/api/v1/internal/user/activate'
    );

    if (!activationRequest) {
      throw new Error('User activation API request not found');
    }

    console.log('  ✅ API integration verified');
    console.log(`     - Requests made: ${requests.length}`);
    console.log(`     - Auth header: ${activationRequest.headers['x-internal-api-key'] ? 'Present' : 'Missing'}`);

    console.log(`✅ ${name} completed successfully`);

  } catch (error) {
    console.error(`❌ ${name} failed:`, error.message);
    throw error;
  }
}

function validateClaims(claims, userAttributes) {
  // Validate account type claim
  if (userAttributes['custom:account_type']) {
    if (claims.account_type !== userAttributes['custom:account_type']) {
      throw new Error(`Account type claim mismatch: expected ${userAttributes['custom:account_type']}, got ${claims.account_type}`);
    }
  }

  // Validate organization ID claim
  if (userAttributes['custom:organization_id']) {
    if (claims.organization_id !== userAttributes['custom:organization_id']) {
      throw new Error(`Organization ID claim mismatch: expected ${userAttributes['custom:organization_id']}, got ${claims.organization_id}`);
    }
  }

  // Validate role claim
  if (!claims.role) {
    throw new Error('Role claim is missing');
  }

  // Validate scope claim
  if (!claims.scope || typeof claims.scope !== 'string') {
    throw new Error('Scope claim is missing or invalid');
  }

  // Validate scope content based on account type
  const accountType = userAttributes['custom:account_type'] || 'INDIVIDUAL';
  const expectedScopePatterns = {
    'INDIVIDUAL': ['read:profile', 'write:profile', 'read:individual_data', 'write:individual_data'],
    'TEAM': ['read:profile', 'write:profile', 'read:team_data', 'write:team_data', 'manage:team'],
    'ENTERPRISE': ['read:profile', 'write:profile', 'read:enterprise_data', 'write:enterprise_data', 'manage:organization', 'admin:all']
  };

  const expectedScopes = expectedScopePatterns[accountType] || expectedScopePatterns['INDIVIDUAL'];
  for (const expectedScope of expectedScopes) {
    if (!claims.scope.includes(expectedScope)) {
      throw new Error(`Missing expected scope: ${expectedScope} in ${claims.scope}`);
    }
  }

  // Validate environment claim
  if (!claims.environment) {
    throw new Error('Environment claim is missing');
  }
}

async function testErrorScenarios(lambdaRunner, mockServer) {
  const errorScenarios = [
    {
      name: 'Missing Email',
      userAttributes: {
        sub: 'error-no-email-user',
        given_name: 'Error',
        family_name: 'User'
        // No email
      }
    },
    {
      name: 'Empty Cognito Sub',
      userAttributes: {
        sub: '',
        email: 'empty-sub@example.com'
      }
    },
    {
      name: 'Invalid Account Type',
      userAttributes: {
        sub: 'invalid-account-type-user',
        email: 'invalid@example.com',
        'custom:account_type': 'INVALID_TYPE'
      }
    }
  ];

  for (const scenario of errorScenarios) {
    console.log(`  🔸 Testing error scenario: ${scenario.name}`);
    
    try {
      // These should not throw errors but handle gracefully
      const postResult = await lambdaRunner.runPostConfirmation(scenario.userAttributes);
      const preResult = await lambdaRunner.runPreTokenGeneration(scenario.userAttributes);
      
      // Verify they return valid results even with bad input
      if (!postResult || !preResult) {
        throw new Error('Lambda functions should return results even with invalid input');
      }

      console.log(`  ✅ Error scenario handled gracefully: ${scenario.name}`);
    } catch (error) {
      console.error(`  ❌ Error scenario failed: ${scenario.name}`, error.message);
    }
  }
}

async function testPerformance(lambdaRunner, mockServer) {
  const iterations = 10;
  const userAttributes = {
    sub: 'performance-test-user',
    email: 'performance@example.com',
    given_name: 'Performance',
    family_name: 'Test',
    'custom:account_type': 'TEAM'
  };

  console.log(`  🔸 Running ${iterations} iterations for performance testing`);

  const startTime = Date.now();
  
  for (let i = 0; i < iterations; i++) {
    const testUser = {
      ...userAttributes,
      sub: `performance-test-user-${i}`,
      email: `performance${i}@example.com`
    };

    await lambdaRunner.runPostConfirmation(testUser);
    await lambdaRunner.runPreTokenGeneration(testUser);
  }

  const endTime = Date.now();
  const totalTime = endTime - startTime;
  const avgTime = totalTime / iterations;

  console.log(`  ✅ Performance test completed`);
  console.log(`     - Total time: ${totalTime}ms`);
  console.log(`     - Average time per iteration: ${avgTime.toFixed(2)}ms`);
  console.log(`     - Users created: ${mockServer.getUsers().filter(u => u.email.includes('performance')).length}`);

  if (avgTime > 1000) {
    console.log(`  ⚠️  Warning: Average execution time is high (${avgTime.toFixed(2)}ms)`);
  }
}

// Run the integration tests
if (require.main === module) {
  runIntegrationTests().catch(error => {
    console.error('Integration tests failed:', error);
    process.exit(1);
  });
}

module.exports = { runIntegrationTests };