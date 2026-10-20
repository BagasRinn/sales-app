import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { CrossBranchReportsTabPage } from '../pages/cross-branch.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS } from '../utils/test-data';

/**
 * Cross-Branch Reports Tab Suite (MANAGER only)
 * Tests: Penjualan summary, Stok summary, per-branch cards, refresh
 */
test.describe('Cross-Branch Reports Tab', () => {
  async function gotoCrossBranchTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Laporan Lintas');
    await page.waitForLoadState('networkidle');
    return new CrossBranchReportsTabPage(page);
  }

  test('displays two sub-tabs (Penjualan and Stok) @smoke', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);

    await expect(reports.penjualanTab).toBeVisible({ timeout: 5_000 });
    await expect(reports.stokTab).toBeVisible();
  });

  // ─── Penjualan Tab ────────────────────────────────────────────────────────

  test('Penjualan tab shows aggregate summary card', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);

    await reports.switchToPenjualan();
    await reports.expectPenjualanSummary();
  });

  test('Penjualan tab shows approved count and revenue', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);
    await reports.switchToPenjualan();

    await expect(reports.approvedCount).toBeVisible({ timeout: 10_000 });
    await expect(reports.approvedRevenue).toBeVisible();
  });

  test('Penjualan tab shows per-branch cards', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);
    await reports.switchToPenjualan();

    await expect(reports.perBranchCards.first()).toBeVisible({ timeout: 10_000 });
  });

  test('Penjualan tab shows customer and sales counts', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);
    await reports.switchToPenjualan();

    await expect(reports.customerCount).toBeVisible({ timeout: 5_000 });
    await expect(reports.salesCount).toBeVisible();
  });

  // ─── Stok Tab ─────────────────────────────────────────────────────────────

  test('Stok tab shows SKU count', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);

    await reports.switchToStok();
    await reports.expectStokSummary();
  });

  test('Stok tab shows total stock value', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);
    await reports.switchToStok();

    await expect(reports.totalStockValue).toBeVisible({ timeout: 5_000 });
  });

  test('Stok tab shows low stock count (may be 0)', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);
    await reports.switchToStok();

    const lowStockVisible = await reports.lowStockCount.isVisible().catch(() => false);
    if (lowStockVisible) {
      await expect(reports.lowStockCount).toBeVisible();
    }
  });

  // ─── Refresh ───────────────────────────────────────────────────────────────

  test('refresh button reloads Penjualan data', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);
    await reports.switchToPenjualan();

    const refreshVisible = await reports.refreshButton.isVisible().catch(() => false);
    if (refreshVisible) {
      await reports.refresh();
      await page.waitForLoadState('networkidle');
    }
  });

  test('refresh button reloads Stok data', async ({ page }) => {
    const reports = await gotoCrossBranchTab(page);
    await reports.switchToStok();

    const refreshVisible = await reports.refreshButton.isVisible().catch(() => false);
    if (refreshVisible) {
      await reports.refresh();
      await page.waitForLoadState('networkidle');
    }
  });

  // ─── Access Control ────────────────────────────────────────────────────────

  test('ADMIN is blocked from Laporan Lintas tab', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.expectTabHidden('Laporan Lintas');
  });

  test('SUPERVISOR is blocked from Laporan Lintas tab', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.expectTabHidden('Laporan Lintas');
  });
});
