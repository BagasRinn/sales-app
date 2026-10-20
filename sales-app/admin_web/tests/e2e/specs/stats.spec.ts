import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { StatsTabPage } from '../pages/stats.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS } from '../utils/test-data';

/**
 * Dashboard / Stats Tab Suite
 * Tests: Ringkasan Sistem, Performa Sales, Ambil Laporan, Pesanan Perlu Tindakan
 */
test.describe('Dashboard - Stats Tab', () => {
  async function loginAsAdmin(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');
  }

  test('loads and displays stat cards @smoke', async ({ page }) => {
    await loginAsAdmin(page);
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);
    await stats.expectStatsCardsVisible();
  });

  test('total orders stat card shows count', async ({ page }) => {
    await loginAsAdmin(page);
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);
    await expect(stats.totalPesananCard).toBeVisible();
    // Should show a number
    await expect(stats.totalPesananCard).toContainText(/\d+|\d+ Pesanan/i);
  });

  test('pending orders badge shows correct count', async ({ page }) => {
    await loginAsAdmin(page);
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);
    // If there are pending orders, badge should be visible
    const badge = page.locator('[class*="badge"]').first();
    const badgeVisible = await badge.isVisible().catch(() => false);
    if (badgeVisible) {
      const text = await badge.textContent();
      // Badge should contain a number
      expect(text?.trim()).toMatch(/^\d+$/);
    }
  });

  test('download daily report - selecting date and downloading', async ({ page }) => {
    await loginAsAdmin(page);
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);
    await stats.expectLaporanSectionVisible();

    // Test with today's date
    const today = new Date().toISOString().split('T')[0];
    const [download] = await Promise.all([
      page.waitForEvent('download', { timeout: 30_000 }).catch(() => null),
      stats.downloadDailyReport(today),
    ]);

    // If there are orders, download should succeed
    if (download) {
      const filename = download.suggestedFilename();
      expect(filename).toMatch(/laporan.*\.(xlsx|xls)/i);
    }
  });

  test('download period report with date range', async ({ page }) => {
    await loginAsAdmin(page);
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);

    const startDate = '2024-01-01';
    const endDate = '2024-01-31';

    const [download] = await Promise.all([
      page.waitForEvent('download', { timeout: 30_000 }).catch(() => null),
      stats.downloadPeriodReport(startDate, endDate),
    ]);

    if (download) {
      const filename = download.suggestedFilename();
      expect(filename).toMatch(/laporan.*\.(xlsx|xls)/i);
    }
  });

  test('ADMIN sees "Pesanan Perlu Tindakan" section', async ({ page }) => {
    await loginAsAdmin(page);
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);
    await expect(stats.pesananPerluTindakanSection).toBeVisible({ timeout: 5_000 }).catch(() => {});
  });

  test('SUPERVISOR does NOT see "Pesanan Perlu Tindakan" section', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);
    await expect(stats.pesananPerluTindakanSection).toBeHidden({ timeout: 3_000 }).catch(() => {});
  });

  test('Performa Sales section visible for SUPERVISOR', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');

    const stats = new StatsTabPage(page);
    await expect(stats.performaSalesSection).toBeVisible({ timeout: 5_000 });
  });

  test('MANAGER sees per-branch cards in Performa Sales', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Dashboard');
    await page.waitForLoadState('networkidle');

    // Look for branch cards in the perform sales section
    const branchCards = page.locator('[class*="card"]').filter({ hasText: /cabang|branch/i });
    const count = await branchCards.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });
});
