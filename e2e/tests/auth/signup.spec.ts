import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers';

test.describe('Signup Flow E2E Tests', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    await helpers.goToSignup();
  });

  test.describe('Page Rendering', () => {
    test('should render signup form with all required fields', async ({ page }) => {
      // Check page title and description
      await expect(page.locator('[data-testid="card-title"]')).toContainText('Create your account');
      await expect(page.locator('[data-testid="card-description"]')).toContainText('Sign up to get started with Diagnyx');

      // Check all form fields are present
      await expect(page.locator('[data-testid="input-name"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-email"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-password"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-confirmPassword"]')).toBeVisible();
      
      // Check account type selector
      await expect(page.locator('[data-testid="select-trigger"]')).toBeVisible();
      
      // Check password strength indicator
      await expect(page.locator('[data-testid="password-strength"]')).not.toBeVisible(); // Should be hidden initially
      
      // Check submit button
      await expect(page.locator('[data-testid="button"]')).toBeVisible();
      await expect(page.locator('[data-testid="button"]')).toContainText('Create account');
      
      // Check sign in link
      const signInLink = page.locator('text=Sign in');
      await expect(signInLink).toBeVisible();
      await expect(signInLink.locator('..').locator('a')).toHaveAttribute('href', '/login');
    });

    test('should show password strength indicator when password is entered', async ({ page }) => {
      await helpers.fillField('input-password', 'weak');
      await expect(page.locator('[data-testid="password-strength"]')).toBeVisible();
      await expect(page.locator('text=Password strength')).toBeVisible();
    });

    test('should have proper placeholders and labels', async ({ page }) => {
      await expect(page.locator('label').filter({ hasText: 'Full Name' })).toBeVisible();
      await expect(page.locator('label').filter({ hasText: 'Email' })).toBeVisible();
      await expect(page.locator('label').filter({ hasText: 'Password' })).toBeVisible();
      await expect(page.locator('label').filter({ hasText: 'Confirm Password' })).toBeVisible();
      await expect(page.locator('label').filter({ hasText: 'Account Type' })).toBeVisible();

      await expect(page.locator('[data-testid="input-name"]')).toHaveAttribute('placeholder', 'John Doe');
      await expect(page.locator('[data-testid="input-email"]')).toHaveAttribute('placeholder', 'john@example.com');
      await expect(page.locator('[data-testid="input-password"]')).toHaveAttribute('placeholder', 'Enter your password');
      await expect(page.locator('[data-testid="input-confirmPassword"]')).toHaveAttribute('placeholder', 'Confirm your password');
    });
  });

  test.describe('Form Validation', () => {
    test('should show validation errors for empty form submission', async ({ page }) => {
      await helpers.clickButton('button');

      await expect(page.locator('text=Name must be at least 2 characters')).toBeVisible();
      await expect(page.locator('text=Please enter a valid email address')).toBeVisible();
      await expect(page.locator('text=Password must be at least 12 characters')).toBeVisible();
    });

    test('should validate name length', async ({ page }) => {
      await helpers.fillField('input-name', 'J');
      await helpers.clickButton('button');

      await expect(page.locator('text=Name must be at least 2 characters')).toBeVisible();
    });

    test('should validate email format', async ({ page }) => {
      await helpers.fillField('input-email', 'invalid-email');
      await helpers.clickButton('button');

      await expect(page.locator('text=Please enter a valid email address')).toBeVisible();
    });

    test('should validate password requirements', async ({ page }) => {
      // Test minimum length
      await helpers.fillField('input-password', 'short');
      await helpers.clickButton('button');
      await expect(page.locator('text=Password must be at least 12 characters')).toBeVisible();

      // Test complexity requirements
      await helpers.fillField('input-password', '123456789012'); // Only numbers
      await helpers.clickButton('button');
      await expect(page.locator('text=Password must contain at least one lowercase letter')).toBeVisible();
    });

    test('should validate password confirmation match', async ({ page }) => {
      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', 'john@example.com');
      await helpers.fillField('input-password', 'StrongPassword123!');
      await helpers.fillField('input-confirmPassword', 'DifferentPassword123!');
      
      await helpers.clickButton('button');

      await expect(page.locator('text=Passwords don\'t match')).toBeVisible();
    });

    test('should clear validation errors when fields are corrected', async ({ page }) => {
      // Trigger validation errors
      await helpers.clickButton('button');
      await expect(page.locator('text=Name must be at least 2 characters')).toBeVisible();

      // Fix the name field
      await helpers.fillField('input-name', 'John Doe');
      await helpers.clickButton('button');

      // Name error should be gone
      await expect(page.locator('text=Name must be at least 2 characters')).not.toBeVisible();
    });
  });

  test.describe('Password Functionality', () => {
    test('should toggle password visibility', async ({ page }) => {
      const passwordInput = page.locator('[data-testid="input-password"]');
      const confirmPasswordInput = page.locator('[data-testid="input-confirmPassword"]');
      
      // Initially passwords should be hidden
      await expect(passwordInput).toHaveAttribute('type', 'password');
      await expect(confirmPasswordInput).toHaveAttribute('type', 'password');

      // Find and click password toggle buttons
      const toggleButtons = page.locator('button[type="button"]').filter({ hasText: '' });
      
      // Toggle password visibility
      await toggleButtons.first().click();
      await expect(passwordInput).toHaveAttribute('type', 'text');
      
      // Toggle confirm password visibility
      await toggleButtons.nth(1).click();
      await expect(confirmPasswordInput).toHaveAttribute('type', 'text');
    });

    test('should show password strength progression', async ({ page }) => {
      await helpers.fillField('input-password', 'a');
      await expect(page.locator('text=Weak')).toBeVisible();

      await helpers.fillField('input-password', 'aA1');
      await expect(page.locator('text=Fair')).toBeVisible();

      await helpers.fillField('input-password', 'aA1!');
      await expect(page.locator('text=Good')).toBeVisible();

      await helpers.fillField('input-password', 'MyStrongPassword123!');
      await expect(page.locator('text=Strong')).toBeVisible();
    });

    test('should show password requirements checklist', async ({ page }) => {
      await helpers.fillField('input-password', 'MyPassword123!');

      // Check that all requirements are visible
      await expect(page.locator('text=At least 12 characters')).toBeVisible();
      await expect(page.locator('text=One lowercase letter')).toBeVisible();
      await expect(page.locator('text=One uppercase letter')).toBeVisible();
      await expect(page.locator('text=One number')).toBeVisible();
      await expect(page.locator('text=One special character')).toBeVisible();

      // Check icons show properly (all should be check marks for this strong password)
      const checkIcons = page.locator('[data-testid="check-icon"]');
      await expect(checkIcons).toHaveCount(5);
    });
  });

  test.describe('Account Type Selection', () => {
    test('should default to INDIVIDUAL account type', async ({ page }) => {
      // Check that INDIVIDUAL is selected by default
      await expect(page.locator('[data-testid="select-value"]')).toContainText('Individual');
    });

    test('should allow changing account type', async ({ page }) => {
      // Click on select trigger
      await page.locator('[data-testid="select-trigger"]').click();
      
      // Select TEAM option
      await page.locator('[data-testid="select-item-TEAM"]').click();
      
      // Verify selection
      await expect(page.locator('[data-testid="select-value"]')).toContainText('Team');
    });
  });

  test.describe('Successful Signup Flow', () => {
    test('should complete signup and redirect to email verification', async ({ page }) => {
      const testEmail = helpers.generateTestEmail();
      const testName = helpers.generateTestName();
      const testPassword = 'TestPassword123!';

      // Fill out the form
      await helpers.fillField('input-name', testName);
      await helpers.fillField('input-email', testEmail);
      await helpers.fillField('input-password', testPassword);
      await helpers.fillField('input-confirmPassword', testPassword);

      // Wait for API call and submit
      const signupPromise = helpers.waitForApiCall('/api/auth/signup');
      await helpers.clickButton('button');

      // Wait for signup API call to complete
      const response = await signupPromise;
      expect(response.status()).toBe(200);

      // Should redirect to email verification page
      await expect(page).toHaveURL(`/verify-email?email=${encodeURIComponent(testEmail)}`);
      
      // Verify email verification page content
      await expect(page.locator('text=Verify your email')).toBeVisible();
      await expect(page.locator(`text=${testEmail}`)).toBeVisible();
    });

    test('should handle auto-login flow when signup is complete', async ({ page }) => {
      const testEmail = helpers.generateTestEmail();
      const testName = helpers.generateTestName();
      const testPassword = 'TestPassword123!';

      // Mock signup response that doesn't require confirmation
      await helpers.mockApiResponse(/\/api\/auth\/signup/, {
        success: true,
        requiresConfirmation: false
      });

      // Fill out the form
      await helpers.fillField('input-name', testName);
      await helpers.fillField('input-email', testEmail);
      await helpers.fillField('input-password', testPassword);
      await helpers.fillField('input-confirmPassword', testPassword);

      // Submit form
      await helpers.clickButton('button');

      // Should redirect to dashboard
      await expect(page).toHaveURL(/.*\/dashboard/);
      await helpers.expectAuthenticated();
    });

    test('should show loading state during signup', async ({ page }) => {
      // Fill form with valid data
      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', helpers.generateTestEmail());
      await helpers.fillField('input-password', 'TestPassword123!');
      await helpers.fillField('input-confirmPassword', 'TestPassword123!');

      // Mock a delayed response
      await page.route('**/api/auth/signup', route => {
        setTimeout(() => {
          route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ success: true, requiresConfirmation: true }),
          });
        }, 1000);
      });

      // Submit and check loading state
      await helpers.clickButton('button');
      
      // Button should be disabled and show loading text
      await expect(page.locator('[data-testid="button"]')).toBeDisabled();
      await expect(page.locator('text=Creating account...')).toBeVisible();
      await expect(page.locator('[data-testid="loader-icon"]')).toBeVisible();
    });
  });

  test.describe('Error Handling', () => {
    test('should handle email already exists error', async ({ page }) => {
      const testEmail = 'existing@example.com';
      
      // Mock signup error response
      await helpers.mockApiResponse(/\/api\/auth\/signup/, {
        success: false,
        error: 'An account with this email already exists'
      });

      // Fill out form
      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', testEmail);
      await helpers.fillField('input-password', 'TestPassword123!');
      await helpers.fillField('input-confirmPassword', 'TestPassword123!');

      await helpers.clickButton('button');

      // Should show error message
      await expect(page.locator('text=An account with this email already exists')).toBeVisible();
      
      // Should stay on signup page
      await expect(page).toHaveURL(/.*\/signup/);
    });

    test('should handle invalid password error', async ({ page }) => {
      // Mock signup error response
      await helpers.mockApiResponse(/\/api\/auth\/signup/, {
        success: false,
        error: 'Password does not meet requirements'
      });

      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', helpers.generateTestEmail());
      await helpers.fillField('input-password', 'weak');
      await helpers.fillField('input-confirmPassword', 'weak');

      await helpers.clickButton('button');

      await expect(page.locator('text=Password does not meet requirements')).toBeVisible();
    });

    test('should handle network errors', async ({ page }) => {
      // Mock network error
      await page.route('**/api/auth/signup', route => {
        route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'Internal server error' }),
        });
      });

      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', helpers.generateTestEmail());
      await helpers.fillField('input-password', 'TestPassword123!');
      await helpers.fillField('input-confirmPassword', 'TestPassword123!');

      await helpers.clickButton('button');

      // Should show generic error message
      await expect(page.locator('text=An error occurred. Please try again.')).toBeVisible();
    });

    test('should clear errors on retry', async ({ page }) => {
      // First attempt with error
      await helpers.mockApiResponse(/\/api\/auth\/signup/, {
        success: false,
        error: 'First error'
      });

      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', helpers.generateTestEmail());
      await helpers.fillField('input-password', 'TestPassword123!');
      await helpers.fillField('input-confirmPassword', 'TestPassword123!');

      await helpers.clickButton('button');
      await expect(page.locator('text=First error')).toBeVisible();

      // Second attempt with success
      await helpers.mockApiResponse(/\/api\/auth\/signup/, {
        success: true,
        requiresConfirmation: true
      });

      await helpers.clickButton('button');

      // Error should be cleared
      await expect(page.locator('text=First error')).not.toBeVisible();
    });
  });

  test.describe('Navigation', () => {
    test('should navigate to login page via sign in link', async ({ page }) => {
      const signInLink = page.locator('text=Sign in').locator('..');
      await signInLink.click();

      await expect(page).toHaveURL(/.*\/login/);
      await expect(page.locator('[data-testid="card-title"]')).toContainText('Welcome back');
    });

    test('should handle browser back navigation', async ({ page }) => {
      // Go to signup, then navigate away and back
      await page.goto('/login');
      await page.goBack();
      
      await expect(page).toHaveURL(/.*\/signup/);
      await expect(page.locator('[data-testid="card-title"]')).toContainText('Create your account');
    });
  });

  test.describe('Form Persistence', () => {
    test('should maintain form data during validation errors', async ({ page }) => {
      const testName = 'John Doe';
      const testEmail = 'john@example.com';
      
      await helpers.fillField('input-name', testName);
      await helpers.fillField('input-email', testEmail);
      await helpers.fillField('input-password', 'weak'); // Invalid password
      
      await helpers.clickButton('button');
      
      // Should show validation error but keep other field values
      await expect(page.locator('text=Password must be at least 12 characters')).toBeVisible();
      await expect(page.locator('[data-testid="input-name"]')).toHaveValue(testName);
      await expect(page.locator('[data-testid="input-email"]')).toHaveValue(testEmail);
    });

    test('should clear password fields on server error', async ({ page }) => {
      await helpers.mockApiResponse(/\/api\/auth\/signup/, {
        success: false,
        error: 'Server error'
      });

      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', helpers.generateTestEmail());
      await helpers.fillField('input-password', 'TestPassword123!');
      await helpers.fillField('input-confirmPassword', 'TestPassword123!');

      await helpers.clickButton('button');

      // Name and email should be preserved, passwords should be cleared
      await expect(page.locator('[data-testid="input-name"]')).toHaveValue('John Doe');
      await expect(page.locator('[data-testid="input-password"]')).toHaveValue('');
      await expect(page.locator('[data-testid="input-confirmPassword"]')).toHaveValue('');
    });
  });

  test.describe('Accessibility', () => {
    test('should have proper ARIA labels and roles', async ({ page }) => {
      // Check form has proper role
      await expect(page.locator('form')).toBeVisible();
      
      // Check labels are associated with inputs
      await expect(page.locator('label[for*="name"]')).toBeVisible();
      await expect(page.locator('label[for*="email"]')).toBeVisible();
      await expect(page.locator('label[for*="password"]')).toBeVisible();
      
      // Check submit button has proper type
      await expect(page.locator('[data-testid="button"]')).toHaveAttribute('type', 'submit');
    });

    test('should support keyboard navigation', async ({ page }) => {
      // Tab through form fields
      await page.keyboard.press('Tab'); // Name field
      await expect(page.locator('[data-testid="input-name"]')).toBeFocused();
      
      await page.keyboard.press('Tab'); // Email field
      await expect(page.locator('[data-testid="input-email"]')).toBeFocused();
      
      await page.keyboard.press('Tab'); // Password field
      await expect(page.locator('[data-testid="input-password"]')).toBeFocused();
    });

    test('should handle form submission with Enter key', async ({ page }) => {
      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', helpers.generateTestEmail());
      await helpers.fillField('input-password', 'TestPassword123!');
      await helpers.fillField('input-confirmPassword', 'TestPassword123!');

      // Focus on confirm password field and press Enter
      await page.locator('[data-testid="input-confirmPassword"]').focus();
      await page.keyboard.press('Enter');

      // Should trigger form submission
      await helpers.waitForApiCall('/api/auth/signup');
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
      await expect(page.locator('[data-testid="input-name"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-email"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-password"]')).toBeVisible();
      await expect(page.locator('[data-testid="input-confirmPassword"]')).toBeVisible();
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
});