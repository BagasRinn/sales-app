import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

export class LoginPage extends BasePage {
  readonly usernameInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorAlert: Locator;
  readonly appLogo: Locator;

  constructor(page: Page) {
    super(page);
    this.usernameInput = page.getByLabel(/username|pengguna/i);
    this.passwordInput = page.getByLabel(/password|sandi/i);
    this.submitButton = page.getByRole('button', { name: /masuk|login|sign in/i });
    this.errorAlert = page.getByRole('alert');
    this.appLogo = page.getByText(/admin|dashboard|penjualan/i).first();
  }

  async goto(): Promise<void> {
    await this.page.goto('');
  }

  async login(username: string, password: string): Promise<void> {
    await this.usernameInput.fill(username);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectErrorMessage(message: string | RegExp): Promise<void> {
    await expect(this.errorAlert).toBeVisible();
    await expect(this.errorAlert).toContainText(message);
  }

  async expectToBeOnLoginPage(): Promise<void> {
    await expect(this.usernameInput).toBeVisible();
    await expect(this.passwordInput).toBeVisible();
    await expect(this.submitButton).toBeVisible();
  }

  async expectSalesUserBlocked(): Promise<void> {
    await expect(this.errorAlert).toBeVisible();
    await expect(this.errorAlert).toContainText(/hanya admin|supervisor|manager|dashboard/i);
    await expect(this.usernameInput).toBeVisible();
  }
}
