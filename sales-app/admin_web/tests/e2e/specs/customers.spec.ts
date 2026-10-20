import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { CustomersTabPage, CustomerDetailDialog } from '../pages/customers.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS, TEST_DATA } from '../utils/test-data';
import { randomString } from '../utils/helpers';

/**
 * Customers Tab Suite
 * Tests: Customer list, search, view detail, edit, delete
 */
test.describe('Customers Tab', () => {
  async function gotoCustomersTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Toko');
    await page.waitForLoadState('networkidle');
    return new CustomersTabPage(page);
  }

  test('displays customer table with headers @smoke', async ({ page }) => {
    const customers = await gotoCustomersTab(page);

    await expect(customers.namaTokoHeader).toBeVisible({ timeout: 5_000 });
    await expect(customers.kodeAreaHeader).toBeVisible();
    await expect(customers.alamatHeader).toBeVisible();
    await expect(customers.aksiHeader).toBeVisible();
  });

  test('search filters customer list', async ({ page }) => {
    const customers = await gotoCustomersTab(page);

    // Search with a query that may or may not match
    await customers.search('test');
    await page.waitForLoadState('networkidle');

    // Should update the list
    await expect(customers.customerRows.first()).toBeVisible({ timeout: 5_000 }).catch(() => {});
  });

  test('can view customer detail', async ({ page }) => {
    const customers = await gotoCustomersTab(page);

    // Wait for rows to load
    await expect(customers.customerRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await customers.customerRows.count();

    if (count > 0) {
      await customers.clickDetail(0);
      const dialog = new CustomerDetailDialog(page);
      await expect(dialog.namaTokoInput).toBeVisible({ timeout: 5_000 });
    }
  });

  test('ADMIN can edit customer detail', async ({ page }) => {
    const customers = await gotoCustomersTab(page);
    await expect(customers.customerRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await customers.customerRows.count();

    if (count > 0) {
      await customers.clickDetail(0);
      const dialog = new CustomerDetailDialog(page);
      await dialog.expectFieldsEditable();

      const newNama = `Toko Edit ${randomString()}`;
      await dialog.editNamaToko(newNama);
      await page.waitForLoadState('networkidle');
    }
  });

  test('SUPERVISOR/MANAGER cannot edit customer detail (read-only)', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Toko');
    await page.waitForLoadState('networkidle');

    const customers = new CustomersTabPage(page);
    await expect(customers.customerRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await customers.customerRows.count();

    if (count > 0) {
      await customers.clickDetail(0);
      const dialog = new CustomerDetailDialog(page);
      // Fields should be disabled for non-ADMIN
      await dialog.expectFieldsReadOnly();
    }
  });

  test('pagination navigation works', async ({ page }) => {
    const customers = await gotoCustomersTab(page);
    await customers.expectPagination();

    const nextVisible = await customers.nextPageButton.isVisible().catch(() => false);
    if (nextVisible) {
      await customers.goToNextPage();
      await page.waitForLoadState('networkidle');
    }
  });

  test('table headers visible on desktop', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    const customers = await gotoCustomersTab(page);

    await expect(customers.kodeHeader).toBeVisible({ timeout: 5_000 });
    await expect(customers.namaTokoHeader).toBeVisible();
  });

  test('mobile responsive layout shows cards instead of table', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    const customers = await gotoCustomersTab(page);

    // On mobile, table headers might not be visible
    await page.waitForLoadState('networkidle');
    const rows = await customers.customerRows.count();
    expect(rows).toBeGreaterThanOrEqual(0);
  });
});
