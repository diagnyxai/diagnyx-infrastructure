import { Page, expect } from '@playwright/test';

export class TestHelpers {
  constructor(private page: Page) {}

  /**
   * Wait for page to be fully loaded
   */
  async waitForPageLoad() {
    await this.page.waitForLoadState('networkidle');
  }

  /**
   * Fill form field by test ID
   */
  async fillField(testId: string, value: string) {
    const field = this.page.locator(`[data-testid="${testId}"]`);
    await expect(field).toBeVisible();
    await field.fill(value);
  }

  /**
   * Click button by test ID
   */
  async clickButton(testId: string) {
    const button = this.page.locator(`[data-testid="${testId}"]`);
    await expect(button).toBeVisible();
    await button.click();
  }

  /**
   * Wait for and check error message
   */
  async expectError(message: string) {
    const errorElement = this.page.locator('[data-testid="alert-error"], .text-red-600, .error');
    await expect(errorElement).toContainText(message);
  }

  /**
   * Wait for and check success message
   */
  async expectSuccess(message: string) {
    const successElement = this.page.locator('[data-testid="alert-success"], .text-green-600, .success');
    await expect(successElement).toContainText(message);
  }

  /**
   * Generate random email for testing
   */
  generateTestEmail(): string {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 8);
    return `e2e-test-${timestamp}-${random}@diagnyx.com`;
  }

  /**
   * Generate random name for testing
   */
  generateTestName(): string {
    const firstNames = ['John', 'Jane', 'Alice', 'Bob', 'Charlie', 'Diana'];
    const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Davis'];
    const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
    const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
    return `${firstName} ${lastName}`;
  }

  /**
   * Wait for loading to complete
   */
  async waitForLoadingToComplete() {
    // Wait for any loading spinners to disappear
    const loadingSpinner = this.page.locator('[data-testid="loader-icon"], .loading, .spinner');
    await loadingSpinner.waitFor({ state: 'hidden', timeout: 30000 });
  }

  /**
   * Check if user is authenticated (on dashboard)
   */
  async expectAuthenticated() {
    await expect(this.page).toHaveURL(/.*\/dashboard/);
    await expect(this.page.locator('nav')).toBeVisible();
  }

  /**
   * Check if user is not authenticated (on login page)
   */
  async expectNotAuthenticated() {
    await expect(this.page).toHaveURL(/.*\/login/);
    await expect(this.page.locator('[data-testid="card-title"]')).toContainText('Welcome back');
  }

  /**
   * Navigate to login page
   */
  async goToLogin() {
    await this.page.goto('/login');
    await this.waitForPageLoad();
  }

  /**
   * Navigate to signup page
   */
  async goToSignup() {
    await this.page.goto('/signup');
    await this.waitForPageLoad();
  }

  /**
   * Navigate to email verification page
   */
  async goToEmailVerification(email: string) {
    await this.page.goto(`/verify-email?email=${encodeURIComponent(email)}`);
    await this.waitForPageLoad();
  }

  /**
   * Logout user
   */
  async logout() {
    // Look for logout button or user menu
    const userMenu = this.page.locator('[data-testid="user-menu"], .user-menu');
    if (await userMenu.isVisible()) {
      await userMenu.click();
      const logoutButton = this.page.locator('[data-testid="logout"], .logout');
      await logoutButton.click();
    }
    
    // Wait for redirect to login page
    await this.expectNotAuthenticated();
  }

  /**
   * Take screenshot with custom name
   */
  async takeScreenshot(name: string) {
    await this.page.screenshot({ 
      path: `screenshots/${name}-${Date.now()}.png`,
      fullPage: true 
    });
  }

  /**
   * Clear all form fields
   */
  async clearForm() {
    const inputs = this.page.locator('input[type="text"], input[type="email"], input[type="password"]');
    const count = await inputs.count();
    
    for (let i = 0; i < count; i++) {
      await inputs.nth(i).clear();
    }
  }

  /**
   * Wait for API call to complete
   */
  async waitForApiCall(urlPattern: string | RegExp, timeout: number = 10000) {
    return this.page.waitForResponse(
      response => {
        const url = response.url();
        return typeof urlPattern === 'string' 
          ? url.includes(urlPattern)
          : urlPattern.test(url);
      },
      { timeout }
    );
  }

  /**
   * Mock API response
   */
  async mockApiResponse(urlPattern: string | RegExp, responseData: any, status: number = 200) {
    await this.page.route(urlPattern, route => {
      route.fulfill({
        status,
        contentType: 'application/json',
        body: JSON.stringify(responseData),
      });
    });
  }

  /**
   * Wait for element to be visible and stable
   */
  async waitForElement(selector: string, timeout: number = 10000) {
    const element = this.page.locator(selector);
    await element.waitFor({ state: 'visible', timeout });
    await element.waitFor({ state: 'attached', timeout });
    return element;
  }

  /**
   * Scroll element into view
   */
  async scrollIntoView(selector: string) {
    await this.page.locator(selector).scrollIntoViewIfNeeded();
  }

  /**
   * Check browser console for errors
   */
  async checkConsoleErrors(): Promise<string[]> {
    const errors: string[] = [];
    
    this.page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    
    return errors;
  }

  /**
   * Wait for network to be idle
   */
  async waitForNetworkIdle(timeout: number = 30000) {
    await this.page.waitForLoadState('networkidle', { timeout });
  }
}