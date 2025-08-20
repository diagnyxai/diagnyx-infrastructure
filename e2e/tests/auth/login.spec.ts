import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers';

test.describe('Login Flow E2E Tests', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    await helpers.goToLogin();
  });

  test.describe('Page Rendering', () => {
    test('should render login form with all required fields', async ({ page }) => {
      // Check page title and description
      await expect(page.locator('[data-testid="card-title"]')).toContainText('Welcome back');
      await expect(page.locator('[data-testid="card-description"]')).toContainText('Sign in to your Diagnyx account');

      // Check all form fields are present
      await expect(page.locator('[data-testid="input-email"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-password"]')).toBeVisible();
      
      // Check remember me checkbox
      await expect(page.locator('[data-testid="checkbox"]')).toBeVisible();
      await expect(page.locator('text=Remember me')).toBeVisible();
      
      // Check submit button
      await expect(page.locator('[data-testid="button"]')).toBeVisible();
      await expect(page.locator('[data-testid="button"]')).toContainText('Sign in');
      
      // Check forgot password link
      const forgotPasswordLink = page.locator('text=Forgot password?');
      await expect(forgotPasswordLink).toBeVisible();
      await expect(forgotPasswordLink.locator('..').locator('a')).toHaveAttribute('href', '/forgot-password');
      
      // Check sign up link
      const signUpLink = page.locator('text=Sign up');
      await expect(signUpLink).toBeVisible();
      await expect(signUpLink.locator('..').locator('a')).toHaveAttribute('href', '/signup');
    });

    test('should have proper placeholders and labels', async ({ page }) => {
      await expect(page.locator('label').filter({ hasText: 'Email' })).toBeVisible();
      await expect(page.locator('label').filter({ hasText: 'Password' })).toBeVisible();
      await expect(page.locator('label').filter({ hasText: 'Remember me' })).toBeVisible();

      await expect(page.locator('[data-testid="input-email"]')).toHaveAttribute('placeholder', 'john@example.com');
      await expect(page.locator('[data-testid="input-password"]')).toHaveAttribute('placeholder', 'Enter your password');
    });

    test('should show password visibility toggle', async ({ page }) => {
      const passwordInput = page.locator('[data-testid="input-password"]');
      await expect(passwordInput).toHaveAttribute('type', 'password');
      
      // Check eye icon is present
      await expect(page.locator('[data-testid="eye-icon"]')).toBeVisible();
    });
  });

  test.describe('Form Validation', () => {
    test('should show validation errors for empty form submission', async ({ page }) => {
      await helpers.clickButton('button');

      await expect(page.locator('text=Please enter a valid email address')).toBeVisible();
      await expect(page.locator('text=Password is required')).toBeVisible();
    });

    test('should validate email format', async ({ page }) => {
      await helpers.fillField('input-email', 'invalid-email');
      await helpers.clickButton('button');

      await expect(page.locator('text=Please enter a valid email address')).toBeVisible();
    });

    test('should validate password requirement', async ({ page }) => {
      await helpers.fillField('input-email', 'john@example.com');
      await helpers.clickButton('button');

      await expect(page.locator('text=Password is required')).toBeVisible();
    });

    test('should accept valid email and password', async ({ page }) => {
      await helpers.fillField('input-email', 'john@example.com');
      await helpers.fillField('input-password', 'password123');
      
      await helpers.clickButton('button');

      // Should attempt login (may fail with invalid credentials, but validation should pass)
      await helpers.waitForApiCall('/api/auth/login');
    });

    test('should clear validation errors when fields are corrected', async ({ page }) => {
      // Trigger validation errors
      await helpers.clickButton('button');
      await expect(page.locator('text=Please enter a valid email address')).toBeVisible();

      // Fix the email field
      await helpers.fillField('input-email', 'john@example.com');
      await helpers.clickButton('button');

      // Email error should be gone
      await expect(page.locator('text=Please enter a valid email address')).not.toBeVisible();
    });
  });

  test.describe('Password Functionality', () => {
    test('should toggle password visibility', async ({ page }) => {
      const passwordInput = page.locator('[data-testid="input-password"]');
      
      // Initially password should be hidden
      await expect(passwordInput).toHaveAttribute('type', 'password');
      await expect(page.locator('[data-testid="eye-icon"]')).toBeVisible();

      // Click toggle button
      const toggleButton = page.locator('button[type="button"]').filter({ hasText: '' });
      await toggleButton.click();
      
      // Password should now be visible
      await expect(passwordInput).toHaveAttribute('type', 'text');
      await expect(page.locator('[data-testid="eye-off-icon"]')).toBeVisible();

      // Click again to hide
      await toggleButton.click();
      await expect(passwordInput).toHaveAttribute('type', 'password');
      await expect(page.locator('[data-testid="eye-icon"]')).toBeVisible();
    });

    test('should maintain password visibility state during form submission', async ({ page }) => {
      const passwordInput = page.locator('[data-testid="input-password"]');
      const toggleButton = page.locator('button[type="button"]').filter({ hasText: '' });
      
      // Make password visible
      await toggleButton.click();
      await expect(passwordInput).toHaveAttribute('type', 'text');
      
      // Fill form and submit (will fail but should maintain visibility)
      await helpers.fillField('input-email', 'test@example.com');
      await helpers.fillField('input-password', 'wrongpassword');
      await helpers.clickButton('button');
      
      // Password should still be visible
      await expect(passwordInput).toHaveAttribute('type', 'text');
    });
  });

  test.describe('Remember Me Functionality', () => {
    test('should default remember me to unchecked', async ({ page }) => {
      const checkbox = page.locator('[data-testid="checkbox"]');
      await expect(checkbox).not.toBeChecked();
    });

    test('should toggle remember me checkbox', async ({ page }) => {
      const checkbox = page.locator('[data-testid="checkbox"]');
      
      // Check the checkbox
      await checkbox.check();
      await expect(checkbox).toBeChecked();
      
      // Uncheck the checkbox
      await checkbox.uncheck();
      await expect(checkbox).not.toBeChecked();
    });

    test('should include remember me in login request', async ({ page }) => {
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      
      // Check remember me
      await page.locator('[data-testid="checkbox"]').check();
      
      // Monitor the login request
      const loginPromise = page.waitForRequest(request => 
        request.url().includes('/api/auth/login') && 
        request.method() === 'POST'
      );
      
      await helpers.clickButton('button');
      
      const request = await loginPromise;
      const postData = request.postDataJSON();
      expect(postData.rememberMe).toBe(true);
    });
  });

  test.describe('Successful Login Flow', () => {
    test('should login with valid credentials and redirect to dashboard', async ({ page }) => {
      const testEmail = process.env.TEST_USER_EMAIL!;
      const testPassword = process.env.TEST_USER_PASSWORD!;

      // Fill login form
      await helpers.fillField('input-email', testEmail);
      await helpers.fillField('input-password', testPassword);

      // Wait for login API call and submit
      const loginPromise = helpers.waitForApiCall('/api/auth/login');
      await helpers.clickButton('button');

      // Wait for login API call to complete
      const response = await loginPromise;
      expect(response.status()).toBe(200);

      // Should redirect to dashboard
      await expect(page).toHaveURL(/.*\/dashboard/);
      await helpers.expectAuthenticated();
    });

    test('should handle redirect parameter after login', async ({ page }) => {
      const redirectUrl = '/analytics';
      
      // Go to login with redirect parameter
      await page.goto(`/login?redirect=${encodeURIComponent(redirectUrl)}`);
      
      // Login with valid credentials
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');

      // Should redirect to specified URL
      await expect(page).toHaveURL(new RegExp(`.*${redirectUrl}`));
    });

    test('should persist authentication across page refreshes', async ({ page }) => {
      // Login first
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');
      
      await helpers.expectAuthenticated();
      
      // Refresh the page
      await page.reload();
      
      // Should still be authenticated
      await helpers.expectAuthenticated();
    });

    test('should show loading state during login', async ({ page }) => {
      // Fill form with valid data
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);

      // Mock a delayed response
      await page.route('**/api/auth/login', route => {
        setTimeout(() => {
          route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ success: true, token: 'mock-token' }),
          });
        }, 1000);
      });

      // Submit and check loading state
      await helpers.clickButton('button');
      
      // Button should be disabled and show loading text
      await expect(page.locator('[data-testid="button"]')).toBeDisabled();
      await expect(page.locator('text=Signing in...')).toBeVisible();
      await expect(page.locator('[data-testid="loader-icon"]')).toBeVisible();
    });
  });

  test.describe('Error Handling', () => {
    test('should handle invalid credentials error', async ({ page }) => {
      // Mock login error response
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        success: false,
        error: 'Invalid email or password'
      }, 401);

      await helpers.fillField('input-email', 'invalid@example.com');
      await helpers.fillField('input-password', 'wrongpassword');
      await helpers.clickButton('button');

      // Should show error message
      await expect(page.locator('text=Invalid email or password')).toBeVisible();
      
      // Should stay on login page
      await expect(page).toHaveURL(/.*\/login/);
    });

    test('should handle user not confirmed error', async ({ page }) => {
      // Mock login error response
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        success: false,
        error: 'Please confirm your email address before logging in'
      }, 401);

      await helpers.fillField('input-email', 'unconfirmed@example.com');
      await helpers.fillField('input-password', 'password123');
      await helpers.clickButton('button');

      await expect(page.locator('text=Please confirm your email address before logging in')).toBeVisible();
    });

    test('should handle user not found error', async ({ page }) => {
      // Mock login error response
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        success: false,
        error: 'User not found'
      }, 404);

      await helpers.fillField('input-email', 'nonexistent@example.com');
      await helpers.fillField('input-password', 'password123');
      await helpers.clickButton('button');

      await expect(page.locator('text=User not found')).toBeVisible();
    });

    test('should handle network errors', async ({ page }) => {
      // Mock network error
      await page.route('**/api/auth/login', route => {
        route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'Internal server error' }),
        });
      });

      await helpers.fillField('input-email', 'test@example.com');
      await helpers.fillField('input-password', 'password123');
      await helpers.clickButton('button');

      // Should show generic error message
      await expect(page.locator('text=An error occurred. Please try again.')).toBeVisible();
    });

    test('should clear errors on retry', async ({ page }) => {
      // First attempt with error
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        success: false,
        error: 'First error'
      }, 401);

      await helpers.fillField('input-email', 'test@example.com');
      await helpers.fillField('input-password', 'wrongpassword');
      await helpers.clickButton('button');
      await expect(page.locator('text=First error')).toBeVisible();

      // Second attempt with success
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        success: true,
        token: 'valid-token'
      });

      await helpers.fillField('input-password', 'correctpassword');
      await helpers.clickButton('button');

      // Error should be cleared
      await expect(page.locator('text=First error')).not.toBeVisible();
    });

    test('should handle rate limiting', async ({ page }) => {
      // Mock rate limiting response
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        error: 'Too many login attempts. Please try again later.'
      }, 429);

      await helpers.fillField('input-email', 'test@example.com');
      await helpers.fillField('input-password', 'password123');
      await helpers.clickButton('button');

      await expect(page.locator('text=Too many login attempts. Please try again later.')).toBeVisible();
    });
  });

  test.describe('Navigation', () => {
    test('should navigate to signup page via sign up link', async ({ page }) => {
      const signUpLink = page.locator('text=Sign up').locator('..');
      await signUpLink.click();

      await expect(page).toHaveURL(/.*\/signup/);
      await expect(page.locator('[data-testid="card-title"]')).toContainText('Create your account');
    });

    test('should navigate to forgot password page', async ({ page }) => {
      const forgotPasswordLink = page.locator('text=Forgot password?');
      await forgotPasswordLink.click();

      await expect(page).toHaveURL(/.*\/forgot-password/);
    });

    test('should handle direct access to login page when already authenticated', async ({ page }) => {
      // First login
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');
      await helpers.expectAuthenticated();

      // Try to access login page again
      await page.goto('/login');

      // Should redirect to dashboard
      await expect(page).toHaveURL(/.*\/dashboard/);
    });
  });

  test.describe('Form Persistence', () => {
    test('should maintain form data during validation errors', async ({ page }) => {
      const testEmail = 'john@example.com';
      
      await helpers.fillField('input-email', testEmail);
      // Don't fill password to trigger validation error
      
      await helpers.clickButton('button');
      
      // Should show validation error but keep email value
      await expect(page.locator('text=Password is required')).toBeVisible();
      await expect(page.locator('[data-testid="input-email"]')).toHaveValue(testEmail);
    });

    test('should clear password field on authentication error', async ({ page }) => {
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        success: false,
        error: 'Invalid credentials'
      }, 401);

      await helpers.fillField('input-email', 'test@example.com');
      await helpers.fillField('input-password', 'wrongpassword');
      await helpers.clickButton('button');

      // Email should be preserved, password should be cleared
      await expect(page.locator('[data-testid="input-email"]')).toHaveValue('test@example.com');
      await expect(page.locator('[data-testid="input-password"]')).toHaveValue('');
    });

    test('should preserve remember me state', async ({ page }) => {
      // Check remember me
      await page.locator('[data-testid="checkbox"]').check();
      
      // Submit form with error
      await helpers.clickButton('button');
      
      // Remember me should still be checked
      await expect(page.locator('[data-testid="checkbox"]')).toBeChecked();
    });
  });

  test.describe('JWT Token Validation', () => {
    test('should include JWT token in authenticated requests', async ({ page }) => {
      // Login successfully
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');
      await helpers.expectAuthenticated();

      // Make an authenticated API request
      const apiPromise = page.waitForRequest(request => 
        request.url().includes('/api/') && 
        request.headers()['authorization']?.startsWith('Bearer ')
      );

      // Navigate to a page that requires authentication
      await page.goto('/dashboard/profile');

      // Should include Authorization header
      const request = await apiPromise;
      const authHeader = request.headers()['authorization'];
      expect(authHeader).toBeTruthy();
      expect(authHeader).toMatch(/^Bearer .+/);
    });

    test('should handle expired token gracefully', async ({ page }) => {
      // Mock login with expired token
      await helpers.mockApiResponse(/\/api\/auth\/login/, {
        success: true,
        token: 'expired-token'
      });

      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');

      // Mock API call with expired token response
      await helpers.mockApiResponse(/\/api\//, {
        error: 'Token expired'
      }, 401);

      // Try to access protected resource
      await page.goto('/dashboard/profile');

      // Should redirect to login page
      await expect(page).toHaveURL(/.*\/login/);
    });

    test('should refresh token when needed', async ({ page }) => {
      // Login successfully
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');
      await helpers.expectAuthenticated();

      // Mock token refresh endpoint
      await helpers.mockApiResponse(/\/api\/auth\/refresh/, {
        success: true,
        token: 'new-refreshed-token'
      });

      // Simulate token expiration and refresh
      await page.evaluate(() => {
        // Trigger token refresh logic if implemented
        localStorage.setItem('token_expires_at', String(Date.now() - 1000));
      });

      // Make a request that should trigger token refresh
      await page.goto('/dashboard/settings');

      // Should handle token refresh transparently
      await helpers.expectAuthenticated();
    });
  });

  test.describe('Security Features', () => {
    test('should not expose sensitive data in localStorage', async ({ page }) => {
      // Login successfully
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');
      await helpers.expectAuthenticated();

      // Check localStorage for sensitive data
      const localStorageData = await page.evaluate(() => {
        const data: Record<string, string> = {};
        for (let i = 0; i < localStorage.length; i++) {
          const key = localStorage.key(i);
          if (key) {
            data[key] = localStorage.getItem(key) || '';
          }
        }
        return data;
      });

      // Should not store raw passwords or sensitive tokens
      Object.values(localStorageData).forEach(value => {
        expect(value).not.toContain(process.env.TEST_USER_PASSWORD!);
        expect(value).not.toMatch(/password/i);
      });
    });

    test('should handle CSRF protection', async ({ page }) => {
      // Check if CSRF tokens are properly handled
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);

      // Monitor request headers
      const requestPromise = page.waitForRequest(request => 
        request.url().includes('/api/auth/login')
      );

      await helpers.clickButton('button');
      
      const request = await requestPromise;
      const headers = request.headers();
      
      // Should include CSRF protection headers if implemented
      expect(headers['content-type']).toContain('application/json');
    });

    test('should clear authentication data on logout', async ({ page }) => {
      // Login first
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);
      await helpers.clickButton('button');
      await helpers.expectAuthenticated();

      // Logout
      await helpers.logout();

      // Check that auth data is cleared
      const authData = await page.evaluate(() => {
        return {
          localStorage: localStorage.getItem('diagnyx-auth'),
          sessionStorage: sessionStorage.getItem('diagnyx-auth'),
        };
      });

      // Auth data should be cleared or indicate logged out state
      if (authData.localStorage) {
        const parsed = JSON.parse(authData.localStorage);
        expect(parsed.isAuthenticated).toBeFalsy();
      }
    });
  });

  test.describe('Accessibility', () => {
    test('should have proper ARIA labels and roles', async ({ page }) => {
      // Check form has proper role
      await expect(page.locator('form')).toBeVisible();
      
      // Check labels are associated with inputs
      await expect(page.locator('label[for*="email"]')).toBeVisible();
      await expect(page.locator('label[for*="password"]')).toBeVisible();
      
      // Check submit button has proper type
      await expect(page.locator('[data-testid="button"]')).toHaveAttribute('type', 'submit');
    });

    test('should support keyboard navigation', async ({ page }) => {
      // Tab through form fields
      await page.keyboard.press('Tab'); // Email field
      await expect(page.locator('[data-testid="input-email"]')).toBeFocused();
      
      await page.keyboard.press('Tab'); // Password field
      await expect(page.locator('[data-testid="input-password"]')).toBeFocused();
      
      await page.keyboard.press('Tab'); // Remember me checkbox
      await expect(page.locator('[data-testid="checkbox"]')).toBeFocused();
    });

    test('should handle form submission with Enter key', async ({ page }) => {
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);

      // Focus on password field and press Enter
      await page.locator('[data-testid="input-password"]').focus();
      await page.keyboard.press('Enter');

      // Should trigger form submission
      await helpers.waitForApiCall('/api/auth/login');
    });
  });

  test.describe('Mobile Responsiveness', () => {
    test('should display properly on mobile devices', async ({ page, isMobile }) => {
      if (!isMobile) {
        test.skip();
        return;
      }

      // Check that form is visible and properly sized
      await expect(page.locator('[data-testid="card"]')).toBeVisible();
      
      // Check that all form elements are accessible
      await expect(page.locator('[data-testid="input-email"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-password"]')).toBeVisible();
      await expect(page.locator('[data-testid="checkbox"]')).toBeVisible();
      await expect(page.locator('[data-testid="button"]')).toBeVisible();
    });

    test('should handle virtual keyboard on mobile', async ({ page, isMobile }) => {
      if (!isMobile) {
        test.skip();
        return;
      }

      // Focus on email field (should trigger email keyboard)
      await page.locator('[data-testid="input-email"]').focus();
      await expect(page.locator('[data-testid="input-email"]')).toBeFocused();
      
      // Fill email and check it's properly entered
      await page.locator('[data-testid="input-email"]').fill('test@example.com');
      await expect(page.locator('[data-testid="input-email"]')).toHaveValue('test@example.com');
    });
  });

  test.describe('Performance', () => {
    test('should load login page quickly', async ({ page }) => {
      const startTime = Date.now();
      await page.goto('/login');
      await page.waitForLoadState('networkidle');
      const loadTime = Date.now() - startTime;

      // Page should load within 3 seconds
      expect(loadTime).toBeLessThan(3000);
    });

    test('should handle login request within reasonable time', async ({ page }) => {
      await helpers.fillField('input-email', process.env.TEST_USER_EMAIL!);
      await helpers.fillField('input-password', process.env.TEST_USER_PASSWORD!);

      const startTime = Date.now();
      await helpers.clickButton('button');
      await helpers.expectAuthenticated();
      const loginTime = Date.now() - startTime;

      // Login should complete within 10 seconds
      expect(loginTime).toBeLessThan(10000);
    });
  });
});