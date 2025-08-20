import { FullConfig } from '@playwright/test';
import AWS from 'aws-sdk';

async function globalSetup(config: FullConfig) {
  console.log('🚀 Starting global setup for E2E tests...');

  // Set up AWS SDK for Cognito operations
  AWS.config.update({
    region: process.env.AWS_COGNITO_REGION || 'us-east-1',
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  });

  // Verify environment variables
  const requiredEnvVars = [
    'AWS_COGNITO_USER_POOL_ID',
    'AWS_COGNITO_CLIENT_ID',
    'TEST_USER_EMAIL',
    'TEST_USER_PASSWORD',
  ];

  const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
  if (missingVars.length > 0) {
    throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
  }

  // Create test user in Cognito if it doesn't exist
  await setupTestUser();

  console.log('✅ Global setup completed successfully');
}

async function setupTestUser() {
  const cognito = new AWS.CognitoIdentityServiceProvider();
  const userPoolId = process.env.AWS_COGNITO_USER_POOL_ID!;
  const testEmail = process.env.TEST_USER_EMAIL!;
  const testPassword = process.env.TEST_USER_PASSWORD!;
  const testName = process.env.TEST_USER_NAME || 'E2E Test User';

  try {
    console.log(`🔍 Checking if test user exists: ${testEmail}`);
    
    // Check if user already exists
    try {
      await cognito.adminGetUser({
        UserPoolId: userPoolId,
        Username: testEmail,
      }).promise();
      
      console.log('✅ Test user already exists');
      return;
    } catch (error: any) {
      if (error.code !== 'UserNotFoundException') {
        throw error;
      }
    }

    // Create test user
    console.log(`👤 Creating test user: ${testEmail}`);
    
    await cognito.adminCreateUser({
      UserPoolId: userPoolId,
      Username: testEmail,
      UserAttributes: [
        { Name: 'email', Value: testEmail },
        { Name: 'email_verified', Value: 'true' },
        { Name: 'given_name', Value: testName.split(' ')[0] },
        { Name: 'family_name', Value: testName.split(' ').slice(1).join(' ') || '' },
        { Name: 'custom:account_type', Value: 'INDIVIDUAL' },
      ],
      TemporaryPassword: 'TempPassword123!',
      MessageAction: 'SUPPRESS', // Don't send welcome email
    }).promise();

    // Set permanent password
    await cognito.adminSetUserPassword({
      UserPoolId: userPoolId,
      Username: testEmail,
      Password: testPassword,
      Permanent: true,
    }).promise();

    console.log('✅ Test user created successfully');
  } catch (error) {
    console.error('❌ Failed to setup test user:', error);
    throw error;
  }
}

export default globalSetup;