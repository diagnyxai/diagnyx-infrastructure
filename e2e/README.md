# Diagnyx E2E Tests

This directory contains end-to-end tests for the Diagnyx authentication system using Playwright.

## Overview

The E2E test suite validates the complete authentication flow including:
- User signup with email verification
- User login with JWT token validation
- Password strength validation
- Email verification process
- Integration with AWS Cognito
- API Gateway authentication middleware

## Setup

### Prerequisites

1. **AWS Cognito Configuration**: Ensure you have a Cognito User Pool set up with the correct configuration
2. **Docker**: Required for running the test environment
3. **Node.js**: Version 18+ for running tests locally

### Environment Configuration

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Update the `.env` file with your AWS Cognito configuration:
   - `AWS_COGNITO_USER_POOL_ID`
   - `AWS_COGNITO_CLIENT_ID`
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

### Installation

```bash
# Install dependencies
npm install

# Install Playwright browsers
npx playwright install
```

## Running Tests

### Docker Environment (Recommended)

Start the complete test environment with Docker:

```bash
# Start all services
npm run docker:up

# Run E2E tests
npm run docker:test

# Stop all services
npm run docker:down
```

### Local Development

For faster iteration during development:

```bash
# Start services in background
npm run docker:up

# Run tests locally
npm run test:e2e

# Run tests with UI (headed mode)
npm run test:e2e:headed

# Debug tests
npm run test:e2e:debug
```

### Test Commands

- `npm run test:e2e` - Run all E2E tests (headless)
- `npm run test:e2e:headed` - Run tests with browser UI
- `npm run test:e2e:debug` - Run tests in debug mode
- `npm run test:e2e:ui` - Open Playwright test UI
- `npm run test:e2e:report` - View test results

## Test Structure

```
e2e/
├── tests/
│   ├── auth/                 # Authentication tests
│   │   ├── login.spec.ts     # Login flow tests
│   │   └── signup.spec.ts    # Signup flow tests
│   ├── setup/                # Test setup and configuration
│   │   ├── global-setup.ts   # Global test setup
│   │   ├── global-teardown.ts # Global test cleanup
│   │   └── auth.setup.ts     # Authentication setup
│   └── utils/                # Test utilities
│       └── test-helpers.ts   # Helper functions
├── docker-compose.e2e.yml    # E2E test environment
├── playwright.config.ts      # Playwright configuration
└── package.json              # Dependencies and scripts
```

## Test Environment

The E2E test environment includes:

- **PostgreSQL**: Test database (port 5433)
- **User Service**: Backend authentication service (port 8081)
- **API Gateway**: Authentication middleware (port 8444)
- **UI Service**: Frontend application (port 3003)
- **E2E Test Runner**: Playwright test execution

## Test Data Management

- **Test User**: Created automatically in Cognito during global setup
- **Database**: Fresh database for each test run
- **Cleanup**: Optional test user cleanup (set `CLEANUP_TEST_USER=true`)

## Debugging

### View Service Logs

```bash
# View all service logs
npm run docker:logs

# View specific service logs
docker logs diagnyx-user-service-e2e
docker logs diagnyx-api-gateway-e2e
docker logs diagnyx-ui-e2e
```

### Debug Test Failures

1. **Screenshots**: Automatically captured on test failure
2. **Videos**: Recorded for failed tests
3. **Traces**: Available for test debugging
4. **HTML Report**: Detailed test results with timeline

### Local Development Tips

1. Use `test:e2e:headed` to see tests running in browser
2. Add `await page.pause()` in tests to debug interactively
3. Use `test:e2e:debug` for step-by-step debugging
4. Check browser console for JavaScript errors

## CI/CD Integration

For CI/CD pipelines:

```bash
# Run tests in CI mode
CI=true npm run test:e2e

# Generate test reports
npm run test:e2e:report
```

## Architecture

### Service Communication

```
E2E Tests → UI (Next.js) → API Gateway → User Service → PostgreSQL
                                    ↓
                                AWS Cognito
```

### Authentication Flow Testing

1. **Signup Flow**: UI → API Gateway → User Service → Cognito
2. **Email Verification**: UI → Cognito (direct)
3. **Login Flow**: UI → API Gateway → User Service → Cognito
4. **JWT Validation**: API Gateway validates tokens from Cognito

## Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker logs and ensure ports are available
2. **Test timeouts**: Increase timeout values in environment variables
3. **Cognito errors**: Verify AWS credentials and User Pool configuration
4. **Database connection**: Ensure PostgreSQL is healthy before tests start

### Health Checks

All services include health checks:
- Database: `pg_isready` check
- Services: HTTP health endpoints
- UI: Root endpoint availability

### Resource Requirements

- **Memory**: 4GB+ recommended for Docker environment
- **CPU**: 2+ cores for parallel test execution
- **Storage**: 1GB+ for Docker images and test artifacts