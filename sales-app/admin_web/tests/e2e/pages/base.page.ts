import { Page, Locator } from '@playwright/test';

export abstract class BasePage {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async navigate(path?: string): Promise<void> {
    if (path) {
      await this.page.goto(path);
    }
  }

  async goto(url: string): Promise<void> {
    await this.page.goto(url);
  }

  async waitForLoadState(state: 'load' | 'domcontentloaded' | 'networkidle' = 'networkidle'): Promise<void> {
    await this.page.waitForLoadState(state);
  }

  async getTitle(): Promise<string> {
    return this.page.title();
  }

  async takeScreenshot(name: string): Promise<void> {
    await this.page.screenshot({
      path: `screenshots/${name}-${Date.now()}.png`,
      fullPage: true,
    });
  }

  async isVisible(selector: string): Promise<boolean> {
    return this.page.locator(selector).isVisible().catch(() => false);
  }

  async click(selector: string): Promise<void> {
    await this.page.locator(selector).click();
  }

  async fill(selector: string, value: string): Promise<void> {
    await this.page.locator(selector).fill(value);
  }

  async getText(selector: string): Promise<string> {
    const text = await this.page.locator(selector).textContent();
    return text ?? '';
  }

  async waitForSelector(selector: string, options?: { state?: 'visible' | 'hidden' | 'attached'; timeout?: number }): Promise<void> {
    const opts = { state: 'visible' as const, timeout: 15_000, ...options };
    await this.page.locator(selector).waitFor(opts);
  }

  async waitForResponse(urlPattern: RegExp | string): Promise<import('@playwright/test').Response> {
    return this.page.waitForResponse(urlPattern);
  }

  async selectOption(selector: string, value: string | string[]): Promise<void> {
    await this.page.locator(selector).selectOption(value);
  }

  async check(selector: string): Promise<void> {
    await this.page.locator(selector).check();
  }

  async uncheck(selector: string): Promise<void> {
    await this.page.locator(selector).uncheck();
  }

  getByRole(role: 'button' | 'link' | 'heading' | 'textbox' | 'checkbox' | 'dialog', options?: { name?: string | RegExp; exact?: boolean }): Locator {
    return this.page.getByRole(role, options);
  }

  getByLabel(label: string | RegExp): Locator {
    return this.page.getByLabel(label);
  }

  getByPlaceholder(placeholder: string | RegExp): Locator {
    return this.page.getByPlaceholder(placeholder);
  }

  getByText(text: string | RegExp, options?: { exact?: boolean }): Locator {
    return this.page.getByText(text, options);
  }

  getByTestId(testId: string): Locator {
    return this.page.getByTestId(testId);
  }

  locator(selector: string): Locator {
    return this.page.locator(selector);
  }
}
