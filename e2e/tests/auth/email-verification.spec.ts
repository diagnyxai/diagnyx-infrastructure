import { test, expect } from '@playwright/test';
import { TestHelpers } from '../utils/test-helpers';

test.describe('Email Verification Flow E2E Tests', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
  });

  test.describe('Page Access and Rendering', () => {
    test('should redirect to signup when no email parameter', async ({ page }) => {
      await page.goto('/verify-email');
      
      // Should redirect to signup page
      await expect(page).toHaveURL(/.*\/signup/);
    });

    test('should render verification form with email parameter', async ({ page }) => {
      const testEmail = 'test@example.com';
      await helpers.goToEmailVerification(testEmail);

      // Check page content
      await expect(page.locator('text=Verify your email')).toBeVisible();
      await expect(page.locator(`text=${testEmail}`)).toBeVisible();
      await expect(page.locator('text=Enter the 6-digit code')).toBeVisible();
      await expect(page.locator('[data-testid="mail-icon"]')).toBeVisible();
    });

    test('should render 6 input fields for verification code', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      await expect(inputs).toHaveCount(6);

      // Check each input has proper attributes
      for (let i = 0; i < 6; i++) {
        const input = inputs.nth(i);
        await expect(input).toHaveAttribute('type', 'text');
        await expect(input).toHaveAttribute('inputMode', 'numeric');
        await expect(input).toHaveAttribute('maxLength', '1');
        await expect(input).toHaveAttribute('autoComplete', 'off');
      }
    });

    test('should render verify and resend buttons', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      // Verify email button
      const verifyButton = page.locator('[data-testid="button"]');
      await expect(verifyButton).toBeVisible();
      await expect(verifyButton).toContainText('Verify email');
      await expect(verifyButton).toBeDisabled(); // Should be disabled initially

      // Resend code button
      const resendButton = page.locator('[data-testid="outline-button"]');
      await expect(resendButton).toBeVisible();
      await expect(resendButton).toContainText('Resend verification code');
    });

    test('should render back to signup link', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const signupLink = page.locator('text=Go back to signup');
      await expect(signupLink).toBeVisible();
      await expect(signupLink.locator('..').locator('a')).toHaveAttribute('href', '/signup');
    });
  });

  test.describe('Code Input Functionality', () => {
    test('should allow typing single digits in each input', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Type digits in sequence
      await inputs.nth(0).fill('1');
      await inputs.nth(1).fill('2');
      await inputs.nth(2).fill('3');

      await expect(inputs.nth(0)).toHaveValue('1');
      await expect(inputs.nth(1)).toHaveValue('2');
      await expect(inputs.nth(2)).toHaveValue('3');
    });

    test('should auto-focus next input when typing', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Type in first input
      await inputs.nth(0).focus();
      await page.keyboard.type('1');
      
      // Second input should be focused
      await expect(inputs.nth(1)).toBeFocused();
    });

    test('should handle backspace navigation', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Fill first two inputs
      await inputs.nth(0).fill('1');
      await inputs.nth(1).fill('2');
      
      // Focus on second input and press backspace
      await inputs.nth(1).focus();
      await page.keyboard.press('Backspace');
      
      // First input should be focused and second should be cleared
      await expect(inputs.nth(0)).toBeFocused();
      await expect(inputs.nth(1)).toHaveValue('');
    });

    test('should limit input to single character', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const input = page.locator('[data-testid^="input-verification"]').first();
      
      // Try to type multiple characters
      await input.fill('123');
      
      // Should only accept first character
      await expect(input).toHaveValue('1');
    });

    test('should enable submit button when all fields are filled', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      const submitButton = page.locator('[data-testid="button"]');
      
      // Initially disabled
      await expect(submitButton).toBeDisabled();
      
      // Fill all inputs
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }
      
      // Should be enabled
      await expect(submitButton).not.toBeDisabled();
    });

    test('should handle paste functionality', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Mock clipboard with 6-digit code
      await page.evaluate(() => {
        Object.defineProperty(navigator, 'clipboard', {
          value: {
            readText: () => Promise.resolve('123456')
          },
          writable: true
        });
      });
      
      // Focus first input and paste
      await inputs.nth(0).focus();
      await page.keyboard.press('Control+v');
      
      // All inputs should be filled
      for (let i = 0; i < 6; i++) {
        await expect(inputs.nth(i)).toHaveValue((i + 1).toString());
      }
    });

    test('should filter non-numeric characters in paste', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Mock clipboard with mixed content
      await page.evaluate(() => {
        Object.defineProperty(navigator, 'clipboard', {
          value: {
            readText: () => Promise.resolve('a1b2c3d4e5f6g')
          },
          writable: true
        });
      });
      
      await inputs.nth(0).focus();
      await page.keyboard.press('Control+v');
      
      // Should only use numeric characters
      await expect(inputs.nth(0)).toHaveValue('1');
      await expect(inputs.nth(1)).toHaveValue('2');
      await expect(inputs.nth(2)).toHaveValue('3');
      await expect(inputs.nth(3)).toHaveValue('4');
      await expect(inputs.nth(4)).toHaveValue('5');
      await expect(inputs.nth(5)).toHaveValue('6');
    });
  });

  test.describe('Form Submission', () => {
    test('should require complete 6-digit code for submission', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      const submitButton = page.locator('[data-testid="button"]');
      
      // Enter only 5 digits
      for (let i = 0; i < 5; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }
      
      await submitButton.click();
      
      // Should show error message
      await expect(page.locator('text=Please enter the complete 6-digit code')).toBeVisible();
    });

    test('should submit with complete 6-digit code', async ({ page }) => {
      const testEmail = 'test@example.com';
      await helpers.goToEmailVerification(testEmail);

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Enter complete code
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }
      
      // Monitor API call
      const confirmPromise = helpers.waitForApiCall('/api/auth/confirm');
      await helpers.clickButton('button');
      
      // Should make confirmation API call
      const response = await confirmPromise;
      expect(response.status()).toBe(200);
    });

    test('should redirect to login on successful verification', async ({ page }) => {
      const testEmail = 'test@example.com';
      
      // Mock successful confirmation
      await helpers.mockApiResponse(/\/api\/auth\/confirm/, {
        success: true
      });
      
      await helpers.goToEmailVerification(testEmail);

      const inputs = page.locator('[data-testid^="input-verification"]');
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }
      
      await helpers.clickButton('button');
      
      // Should redirect to login page with success parameter
      await expect(page).toHaveURL(/.*\/login\?verified=true/);
      await expect(page.locator('text=Email verified successfully')).toBeVisible();
    });

    test('should handle verification failure', async ({ page }) => {
      // Mock verification failure
      await helpers.mockApiResponse(/\/api\/auth\/confirm/, {
        success: false,
        error: 'Invalid verification code'
      }, 400);
      
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }
      
      await helpers.clickButton('button');
      
      // Should show error message
      await expect(page.locator('text=Invalid verification code')).toBeVisible();
      
      // Should stay on verification page
      await expect(page).toHaveURL(/.*\/verify-email/);
    });

    test('should handle expired code error', async ({ page }) => {
      // Mock expired code error
      await helpers.mockApiResponse(/\/api\/auth\/confirm/, {
        success: false,
        error: 'Confirmation code has expired'
      }, 400);
      
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill('1');
      }
      
      await helpers.clickButton('button');
      
      await expect(page.locator('text=Confirmation code has expired')).toBeVisible();
    });

    test('should show loading state during verification', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }

      // Mock delayed response
      await page.route('**/api/auth/confirm', route => {
        setTimeout(() => {
          route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ success: true }),
          });
        }, 1000);
      });

      await helpers.clickButton('button');
      
      // Should show loading state
      await expect(page.locator('[data-testid="button"]')).toBeDisabled();
      await expect(page.locator('text=Verifying...')).toBeVisible();
      await expect(page.locator('[data-testid="loader-icon"]')).toBeVisible();
    });
  });

  test.describe('Resend Code Functionality', () => {
    test('should resend verification code', async ({ page }) => {
      const testEmail = 'test@example.com';
      await helpers.goToEmailVerification(testEmail);

      // Monitor resend API call
      const resendPromise = helpers.waitForApiCall('/api/auth/resend');
      await page.locator('[data-testid="outline-button"]').click();
      
      // Should make resend API call
      const response = await resendPromise;
      expect(response.status()).toBe(200);
    });

    test('should show success message after resending', async ({ page }) => {
      // Mock successful resend
      await helpers.mockApiResponse(/\/api\/auth\/resend/, {
        success: true
      });
      
      await helpers.goToEmailVerification('test@example.com');
      
      await page.locator('[data-testid="outline-button"]').click();
      
      // Should show success message
      await expect(page.locator('text=Verification code sent! Please check your email.')).toBeVisible();
    });

    test('should clear input fields after resending', async ({ page }) => {
      // Mock successful resend
      await helpers.mockApiResponse(/\/api\/auth\/resend/, {
        success: true
      });
      
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Fill some inputs
      await inputs.nth(0).fill('1');
      await inputs.nth(1).fill('2');
      
      await page.locator('[data-testid="outline-button"]').click();
      
      // Inputs should be cleared
      await expect(inputs.nth(0)).toHaveValue('');
      await expect(inputs.nth(1)).toHaveValue('');
    });

    test('should handle resend failure', async ({ page }) => {
      // Mock resend failure
      await helpers.mockApiResponse(/\/api\/auth\/resend/, {
        success: false,
        error: 'Failed to send email'
      }, 500);
      
      await helpers.goToEmailVerification('test@example.com');
      
      await page.locator('[data-testid="outline-button"]').click();
      
      // Should show error message
      await expect(page.locator('text=Failed to send email')).toBeVisible();
    });

    test('should implement cooldown after resending', async ({ page }) => {
      // Mock successful resend
      await helpers.mockApiResponse(/\/api\/auth\/resend/, {
        success: true
      });
      
      await helpers.goToEmailVerification('test@example.com');
      
      const resendButton = page.locator('[data-testid="outline-button"]');
      
      await resendButton.click();
      
      // Should show cooldown state
      await expect(resendButton).toBeDisabled();
      await expect(page.locator('text=Resend code in 60s')).toBeVisible();
    });

    test('should countdown and re-enable button', async ({ page }) => {
      // Mock successful resend
      await helpers.mockApiResponse(/\/api\/auth\/resend/, {
        success: true
      });
      
      await helpers.goToEmailVerification('test@example.com');
      
      const resendButton = page.locator('[data-testid="outline-button"]');
      
      await resendButton.click();
      
      // Should show initial cooldown
      await expect(page.locator('text=Resend code in 60s')).toBeVisible();
      
      // Wait a bit and check countdown updates
      await page.waitForTimeout(2000);
      await expect(page.locator('text=Resend code in 58s')).toBeVisible();
    });

    test('should not allow resend during cooldown', async ({ page }) => {
      // Mock successful resend
      await helpers.mockApiResponse(/\/api\/auth\/resend/, {
        success: true
      });
      
      await helpers.goToEmailVerification('test@example.com');
      
      const resendButton = page.locator('[data-testid="outline-button"]');
      
      // First resend
      await resendButton.click();
      
      // Button should be disabled
      await expect(resendButton).toBeDisabled();
      
      // Try to click again (should not work)
      await resendButton.click({ force: true });
      
      // Should still show cooldown
      await expect(page.locator('text=Resend code in')).toBeVisible();
    });
  });

  test.describe('Error Display and Recovery', () => {
    test('should show error alert for verification failure', async ({ page }) => {
      // Mock verification failure
      await helpers.mockApiResponse(/\/api\/auth\/confirm/, {
        success: false,
        error: 'Verification failed'
      }, 400);
      
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }
      
      await helpers.clickButton('button');
      
      // Should show error alert
      await expect(page.locator('[data-testid="alert-error"]')).toBeVisible();
      await expect(page.locator('[data-testid="alert-circle-icon"]')).toBeVisible();
    });

    test('should show success alert after resending code', async ({ page }) => {
      // Mock successful resend
      await helpers.mockApiResponse(/\/api\/auth\/resend/, {
        success: true
      });
      
      await helpers.goToEmailVerification('test@example.com');
      
      await page.locator('[data-testid="outline-button"]').click();
      
      // Should show success alert
      await expect(page.locator('[data-testid="alert-success"]')).toBeVisible();
      await expect(page.locator('[data-testid="check-circle-icon"]')).toBeVisible();
    });

    test('should clear previous errors on new submission', async ({ page }) => {
      // Mock first failure then success
      await page.route('**/api/auth/confirm', (route, request) => {
        // First request fails
        if (!route.request().url().includes('retry')) {
          route.fulfill({
            status: 400,
            contentType: 'application/json',
            body: JSON.stringify({ success: false, error: 'First error' }),
          });
        } else {
          // Second request succeeds
          route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ success: true }),
          });
        }
      });
      
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // First submission
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill((i + 1).toString());
      }
      await helpers.clickButton('button');
      
      // Should show error
      await expect(page.locator('text=First error')).toBeVisible();
      
      // Clear and retry
      for (let i = 0; i < 6; i++) {
        await inputs.nth(i).fill('');
        await inputs.nth(i).fill((i + 1).toString());
      }
      
      // Add retry parameter to URL
      await page.evaluate(() => {
        window.history.replaceState({}, '', window.location.href + '&retry=true');
      });
      
      await helpers.clickButton('button');
      
      // Error should be cleared
      await expect(page.locator('text=First error')).not.toBeVisible();
    });
  });

  test.describe('Navigation and Integration', () => {
    test('should navigate back to signup page', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');
      
      const signupLink = page.locator('text=Go back to signup');
      await signupLink.click();
      
      await expect(page).toHaveURL(/.*\/signup/);
      await expect(page.locator('[data-testid="card-title"]')).toContainText('Create your account');
    });

    test('should integrate with signup flow', async ({ page }) => {
      const testEmail = helpers.generateTestEmail();
      const testPassword = 'TestPassword123!';
      
      // Start from signup
      await helpers.goToSignup();
      
      // Fill signup form
      await helpers.fillField('input-name', 'John Doe');
      await helpers.fillField('input-email', testEmail);
      await helpers.fillField('input-password', testPassword);
      await helpers.fillField('input-confirmPassword', testPassword);
      
      // Mock signup success with confirmation required
      await helpers.mockApiResponse(/\/api\/auth\/signup/, {
        success: true,
        requiresConfirmation: true
      });
      
      await helpers.clickButton('button');
      
      // Should redirect to email verification
      await expect(page).toHaveURL(`/verify-email?email=${encodeURIComponent(testEmail)}`);
      await expect(page.locator(`text=${testEmail}`)).toBeVisible();
    });

    test('should handle direct URL access with proper email', async ({ page }) => {
      const testEmail = 'direct@example.com';
      
      // Direct navigation to verification page
      await page.goto(`/verify-email?email=${encodeURIComponent(testEmail)}`);
      
      // Should render properly
      await expect(page.locator('text=Verify your email')).toBeVisible();
      await expect(page.locator(`text=${testEmail}`)).toBeVisible();
    });
  });

  test.describe('Accessibility', () => {
    test('should have proper form structure', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');
      
      // Check form exists
      await expect(page.locator('form')).toBeVisible();
    });

    test('should have proper input attributes', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Check each input has proper accessibility attributes
      for (let i = 0; i < 6; i++) {
        const input = inputs.nth(i);
        await expect(input).toHaveAttribute('type', 'text');
        await expect(input).toHaveAttribute('inputMode', 'numeric');
        await expect(input).toHaveAttribute('autoComplete', 'off');
      }
    });

    test('should support keyboard navigation', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');

      const inputs = page.locator('[data-testid^="input-verification"]');
      
      // Tab through inputs
      await inputs.nth(0).focus();
      await expect(inputs.nth(0)).toBeFocused();
      
      await page.keyboard.press('Tab');
      await expect(inputs.nth(1)).toBeFocused();
    });

    test('should have submit button with proper type', async ({ page }) => {
      await helpers.goToEmailVerification('test@example.com');
      
      const submitButton = page.locator('[data-testid="button"]');
      await expect(submitButton).toHaveAttribute('type', 'submit');
    });
  });

  test.describe('Mobile Responsiveness', () => {
    test('should display properly on mobile devices', async ({ page, isMobile }) => {
      if (!isMobile) {
        test.skip();
        return;
      }

      await helpers.goToEmailVerification('test@example.com');
      
      // Check that form is visible and properly sized
      await expect(page.locator('[data-testid="card"]')).toBeVisible();
      
      // Check that all form elements are accessible
      const inputs = page.locator('[data-testid^="input-verification"]');
      await expect(inputs).toHaveCount(6);
      
      await expect(page.locator('[data-testid="button"]')).toBeVisible();
      await expect(page.locator('[data-testid="outline-button"]')).toBeVisible();
    });

    test('should handle numeric keyboard on mobile', async ({ page, isMobile }) => {
      if (!isMobile) {
        test.skip();
        return;
      }

      await helpers.goToEmailVerification('test@example.com');
      
      const firstInput = page.locator('[data-testid^="input-verification"]').first();
      
      // Focus should trigger numeric keyboard
      await firstInput.focus();
      await expect(firstInput).toBeFocused();
      await expect(firstInput).toHaveAttribute('inputMode', 'numeric');
    });
  });
});