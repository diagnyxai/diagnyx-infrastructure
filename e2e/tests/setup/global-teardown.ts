import { FullConfig } from '@playwright/test';
import AWS from 'aws-sdk';

async function globalTeardown(config: FullConfig) {
  console.log('🧹 Starting global teardown for E2E tests...');

  // Clean up test data if needed
  await cleanupTestUser();

  console.log('✅ Global teardown completed');
}

async function cleanupTestUser() {
  // Only clean up test user in CI or if explicitly requested
  if (!process.env.CLEANUP_TEST_USER || process.env.CLEANUP_TEST_USER !== 'true') {
    console.log('⏭️ Skipping test user cleanup (set CLEANUP_TEST_USER=true to enable)');
    return;
  }

  const cognito = new AWS.CognitoIdentityServiceProvider();
  const userPoolId = process.env.AWS_COGNITO_USER_POOL_ID!;
  const testEmail = process.env.TEST_USER_EMAIL!;

  try {
    console.log(`🗑️ Cleaning up test user: ${testEmail}`);
    
    await cognito.adminDeleteUser({
      UserPoolId: userPoolId,
      Username: testEmail,
    }).promise();

    console.log('✅ Test user cleaned up successfully');
  } catch (error: any) {
    if (error.code === 'UserNotFoundException') {
      console.log('ℹ️ Test user was already deleted');
    } else {
      console.error('❌ Failed to cleanup test user:', error);
      // Don't throw error - teardown should not fail
    }
  }
}

export default globalTeardown;