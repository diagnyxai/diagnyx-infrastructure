# Lambda Function Testing Framework

This directory contains a comprehensive testing framework for locally testing AWS Lambda functions used in the Diagnyx authentication system.

## Overview

The testing framework allows you to test Cognito Lambda triggers locally without deploying to AWS, providing fast feedback during development and ensuring reliability before deployment.

## Components

### Lambda Functions Tested

1. **Post-Confirmation Trigger** (`post-confirmation`)
   - Triggered after user email confirmation in Cognito
   - Activates user in the application database via API call
   - Handles different account types and organization assignments

2. **Pre-Token Generation Trigger** (`pre-token-generation`)
   - Triggered before JWT token generation in Cognito
   - Adds custom claims to tokens (account type, role, scope, etc.)
   - Customizes token scope based on user attributes

### Testing Infrastructure

- **MockApiServer**: Simulates the user service API for testing Lambda interactions
- **LambdaRunner**: Executes Lambda functions locally with test events and contexts
- **Integration Tests**: End-to-end testing of the complete authentication flow
- **Unit Tests**: Comprehensive test suites for individual Lambda functions

## Quick Start

### Installation

```bash
npm install
```

### Running Tests

```bash
# Run all unit tests
npm test

# Run unit tests with coverage
npm test:coverage

# Run unit tests in watch mode
npm test:watch

# Run integration tests
npm run test:integration

# Run end-to-end tests (includes server startup)
npm run test:e2e
```

### Manual Testing

```bash
# Start mock API server
npm run start-local-server

# Test post-confirmation trigger
npm run test:post-confirmation

# Test pre-token generation trigger
npm run test:pre-token
```

## Test Scenarios

### Post-Confirmation Lambda Tests

**Account Type Handling:**
- Individual users with basic profile data
- Team users with organization assignments
- Enterprise users with full organizational context
- Default account type handling for missing attributes

**API Integration:**
- User activation API calls with proper authentication
- Request payload validation and structure
- Error handling for API failures
- Timeout and retry behavior

**Data Validation:**
- Cognito attribute extraction and mapping
- Required field validation
- Custom attribute handling
- Null and empty value handling

### Pre-Token Generation Lambda Tests

**Claims Generation:**
- Account type claims based on user attributes
- Organization ID claims for team/enterprise users
- Role claims from database lookup
- Environment-specific claims

**Scope Management:**
- Individual user scopes (basic profile access)
- Team user scopes (team management capabilities)
- Enterprise user scopes (organization administration)
- Default scopes for unknown account types

**Token Structure:**
- Claims structure initialization
- Custom claims override handling
- Original event preservation
- Error recovery without token disruption

### Integration Test Scenarios

**Complete Signup Flow:**
1. User confirms email (post-confirmation trigger)
2. User record created in database
3. User logs in (pre-token generation trigger)
4. Custom claims added to JWT token
5. Token validation and scope verification

**Error Scenarios:**
- Missing user attributes
- Invalid account types
- API service unavailability
- Database connection failures

**Performance Testing:**
- Multiple concurrent user activations
- Token generation performance
- API call response times
- Memory and resource usage

## Mock API Server

The MockApiServer simulates the user service API endpoints needed for Lambda testing:

### Endpoints

- `GET /health` - Health check
- `POST /api/v1/internal/user/activate` - User activation (post-confirmation)
- `GET /api/v1/internal/user/:cognitoSub` - User lookup (pre-token)
- `PATCH /api/v1/internal/user/:cognitoSub/role` - Role updates

### Test Utilities

- `GET /api/test/users` - View all created users
- `GET /api/test/requests` - View all API requests
- `DELETE /api/test/reset` - Reset server state

### Authentication

All internal API endpoints require the `X-Internal-API-Key` header with value `test-internal-key` or `dev-internal-key`.

## Configuration

### Environment Variables

Lambda functions can be tested with different environment configurations:

```javascript
await lambdaRunner.runPostConfirmation(userAttributes, {
  API_ENDPOINT: 'http://localhost:8443',
  INTERNAL_API_KEY: 'test-key',
  ENVIRONMENT: 'test'
});
```

### Test Data

Test user attributes can be customized for different scenarios:

```javascript
const userAttributes = {
  sub: 'test-user-123',
  email: 'test@example.com',
  given_name: 'Test',
  family_name: 'User',
  'custom:account_type': 'TEAM',
  'custom:organization_id': 'org-456'
};
```

## Development Workflow

### Adding New Tests

1. Create test files in `src/__tests__/`
2. Use LambdaRunner to execute functions
3. Use MockApiServer to simulate API interactions
4. Validate results and side effects

### Testing Code Changes

1. Make changes to Lambda function code
2. Run `lambdaRunner.reloadFunctions()` to reload
3. Execute tests to verify changes
4. Use watch mode for continuous testing

### Integration Testing

1. Start mock server
2. Run complete user signup flow
3. Verify database state changes
4. Validate JWT token claims
5. Test error scenarios

## CI/CD Integration

The testing framework is designed for CI/CD pipelines:

```bash
# In CI environment
npm ci
npm run test:coverage
npm run test:integration
```

### Coverage Reports

Coverage reports are generated in the `coverage/` directory and include:
- Line coverage for all Lambda function code
- Branch coverage for conditional logic
- Function coverage for exported functions
- Statement coverage for all executable code

## Debugging

### Verbose Logging

Set environment variable for detailed logging:

```bash
DEBUG=lambda-testing npm test
```

### Request Inspection

View all API requests made during testing:

```javascript
const requests = mockServer.getRequests();
console.log('API Requests:', requests);
```

### State Inspection

View created users and their attributes:

```javascript
const users = mockServer.getUsers();
console.log('Created Users:', users);
```

## Best Practices

### Test Organization

- Group related tests in describe blocks
- Use descriptive test names
- Test both success and failure scenarios
- Include edge cases and boundary conditions

### Data Management

- Reset server state between tests
- Use unique identifiers for test users
- Clean up resources after tests
- Avoid test data dependencies

### Assertions

- Validate Lambda function return values
- Check API call parameters and headers
- Verify database state changes
- Assert expected claims in tokens

### Performance

- Keep test execution time reasonable
- Use appropriate timeouts
- Mock external dependencies
- Measure and monitor test performance

## Troubleshooting

### Common Issues

**Lambda function not found:**
- Verify file paths in LambdaRunner
- Check that functions export `handler`
- Ensure require.cache is cleared for reloads

**API server connection errors:**
- Check server is running on correct port
- Verify firewall and network settings
- Ensure proper startup timing

**Test failures:**
- Check environment variable configuration
- Verify test data and expectations
- Review server logs for API errors
- Validate Lambda function logic

### Debug Output

Enable debug output for troubleshooting:

```javascript
// In test files
console.log('Event:', JSON.stringify(event, null, 2));
console.log('Result:', JSON.stringify(result, null, 2));
console.log('Server State:', mockServer.getUsers());
```