import { test as setup, expect } from '@playwright/test';

const authFile = 'tests/setup/.auth/user.json';

setup('authenticate', async ({ page }) => {
  console.log('🔐 Setting up authentication for E2E tests...');

  // Go to login page
  await page.goto('/login');

  // Wait for page to load
  await expect(page.locator('[data-testid="card-title"]')).toContainText('Welcome back');

  // Fill in login credentials
  await page.fill('[data-testid="input-email"]', process.env.TEST_USER_EMAIL!);
  await page.fill('[data-testid="input-password"]', process.env.TEST_USER_PASSWORD!);

  // Click login button
  await page.click('[data-testid="button"]');

  // Wait for successful login - should redirect to dashboard
  await expect(page).toHaveURL(/.*\/dashboard/);
  
  // Verify user is logged in by checking for user menu or dashboard content
  await expect(page.locator('nav')).toBeVisible();

  // Save authentication state
  await page.context().storageState({ path: authFile });

  console.log('✅ Authentication setup completed');
});