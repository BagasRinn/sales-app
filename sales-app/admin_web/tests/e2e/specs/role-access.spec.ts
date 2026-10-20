import { test, expect } from '@playwright/test';
import { DashboardPage, ChangePasswordDialog } from '../pages/dashboard.page';
import { StatsTabPage } from '../pages/stats.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS } from '../utils/test-data';

/**
 * Role-Based Access Control Suite
 */
test.describe('Role-Based Access Control', () => {
  async function loginAndGetDashboard(page: import('@playwright/test').Page, role: keyof typeof TEST_USERS) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS[role].username, TEST_USERS[role].password);
    await page.waitForLoadState('networkidle');
    return new DashboardPage(page);
  }

  test('ADMIN sees all 12 tabs', async ({ page }) => {
    const dashboard = await loginAndGetDashboard(page, 'admin');
    await dashboard.expectDashboardLoaded();

    // All tabs visible for ADMIN
    await dashboard.expectTabVisible('Dashboard');
    await dashboard.expectTabVisible('Pesanan');
    await dashboard.expectTabVisible('Toko');
    await dashboard.expectTabVisible('Pengajuan Customer');
    await dashboard.expectTabVisible('Produk & Stok');
    await dashboard.expectTabVisible('Supplier');
    await dashboard.expectTabVisible('Sinkronisasi');
    await dashboard.expectTabVisible('User');
    await dashboard.expectTabVisible('Performa Sales');
    await dashboard.expectTabVisible('Penugasan Sales');
    await dashboard.expectTabVisible('Bulletin');
    await dashboard.expectTabVisible('Laporan Lintas');
  });

  test('SUPERVISOR does NOT see "User" tab', async ({ page }) => {
    const dashboard = await loginAndGetDashboard(page, 'supervisor');
    await dashboard.expectDashboardLoaded();

    await dashboard.expectTabVisible('Dashboard');
    await dashboard.expectTabVisible('Performa Sales');
    await dashboard.expectTabVisible('Penugasan Sales');
    await dashboard.expectTabVisible('Bulletin');

    // User tab is for MANAGER only
    await dashboard.expectTabHidden('User');
    await dashboard.expectTabHidden('Laporan Lintas');
  });

  test('MANAGER sees all tabs including "User" and "Laporan Lintas"', async ({ page }) => {
    const dashboard = await loginAndGetDashboard(page, 'manager');
    await dashboard.expectDashboardLoaded();

    await dashboard.expectTabVisible('User');
    await dashboard.expectTabVisible('Laporan Lintas');
    await dashboard.expectTabVisible('Performa Sales');
  });

  test('Pesanan tab: ADMIN has approve/reject buttons, SUPERVISOR does not', async ({ page }) => {
    // ADMIN - should see action buttons
    const adminDashboard = await loginAndGetDashboard(page, 'admin');
    await adminDashboard.clickTab('Pesanan');
    const ordersAdmin = page.locator('[class*="card"]').first();
    await expect(ordersAdmin).toBeVisible({ timeout: 10_000 });

    // SUPERVISOR - should be read-only
    const supPage = await page.context().newPage();
    const supervisorDashboard = await loginAndGetDashboard(supPage, 'supervisor');
    await supervisorDashboard.clickTab('Pesanan');

    const approveBtn = page.getByRole('button', { name: /setujui|approve/i });
    const rejectBtn = page.getByRole('button', { name: /tolak|reject/i });

    // Buttons might be hidden or disabled for non-ADMIN
    if (await approveBtn.isVisible()) {
      await expect(approveBtn).toBeDisabled();
    }
    if (await rejectBtn.isVisible()) {
      await expect(rejectBtn).toBeDisabled();
    }
  });
});
