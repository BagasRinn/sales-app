import { Page } from '@playwright/test';

/**
 * Wait for a network request to a specific URL pattern.
 */
export async function waitForApiResponse(
  page: Page,
  urlPattern: RegExp | string
): Promise<import('@playwright/test').Response> {
  return page.waitForResponse(urlPattern);
}

/**
 * Wait for download and return file path.
 */
export async function waitForDownload(
  page: Page,
  trigger: () => Promise<void>
): Promise<string | null> {
  const [download] = await Promise.all([
    page.waitForEvent('download', { timeout: 30_000 }).catch(() => null),
    trigger(),
  ]);
  return download?.path() ?? null;
}

/**
 * Clear and fill an input field.
 */
export async function clearAndFill(
  page: Page,
  locator: string,
  value: string
): Promise<void> {
  await page.locator(locator).clear();
  await page.locator(locator).fill(value);
}

/**
 * Dismiss a dialog (alert/confirm).
 */
export async function dismissDialog(
  page: Page,
  accept = true
): Promise<void> {
  page.on('dialog', async (dialog) => {
    if (accept) await dialog.accept();
    else await dialog.dismiss();
  });
}

/**
 * Get a random string for unique test data.
 */
export function randomString(prefix = 'TEST'): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
}

/**
 * Format date for API calls.
 */
export function formatDate(date: Date): string {
  return date.toISOString().split('T')[0];
}

/**
 * Format date for display (Indonesian locale).
 */
export function formatDisplayDate(date: Date): string {
  return date.toLocaleDateString('id-ID', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

/**
 * Retry a function until it returns true or timeout.
 */
export async function retryUntil(
  fn: () => Promise<boolean>,
  options: { timeout?: number; interval?: number } = {}
): Promise<boolean> {
  const { timeout = 10_000, interval = 500 } = options;
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await fn()) return true;
    await new Promise((r) => setTimeout(r, interval));
  }
  return false;
}
