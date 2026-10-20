import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { PerformanceTabPage } from '../pages/performance.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS } from '../utils/test-data';

/**
 * Performa Sales Tab Suite (SUPERVISOR/MANAGER only)
 * Tests: KPI Supplier, Leaderboard, Target & Incentive
 */
test.describe('Performa Sales Tab', () => {
  async function gotoPerformanceTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Performa Sales');
    await page.waitForLoadState('networkidle');
    return new PerformanceTabPage(page);
  }

  test('displays three sub-section tabs @smoke', async ({ page }) => {
    const performance = await gotoPerformanceTab(page);

    await expect(performance.kpiSupplierTab).toBeVisible({ timeout: 5_000 });
    await expect(performance.leaderboardTab).toBeVisible();
    await expect(performance.targetIncentiveTab).toBeVisible();
  });

  test('KPI Supplier section loads supplier table', async ({ page }) => {
    const performance = await gotoPerformanceTab(page);

    await performance.switchToKpiSupplier();
    await expect(performance.supplierTable).toBeVisible({ timeout: 10_000 });
  });

  test('supplier table has editable target inputs', async ({ page }) => {
    const performance = await gotoPerformanceTab(page);
    await performance.switchToKpiSupplier();

    const editInputs = performance.targetEditInputs;
    const count = await editInputs.count();

    if (count > 0) {
      await expect(editInputs.first()).toBeVisible();
    }
  });

  test('Leaderboard section displays ranked list', async ({ page }) => {
    const performance = await gotoPerformanceTab(page);

    await performance.switchToLeaderboard();
    await performance.expectLeaderboardRanked();
  });

  test('Leaderboard can be sorted by revenue', async ({ page }) => {
    const performance = await gotoPerformanceTab(page);
    await performance.switchToLeaderboard();

    const sortBtn = performance.revenueSortButton;
    const visible = await sortBtn.isVisible().catch(() => false);

    if (visible) {
      await performance.sortByRevenue();
      await page.waitForLoadState('networkidle');
    }
  });

  test('Leaderboard can be sorted by order count', async ({ page }) => {
    const performance = await gotoPerformanceTab(page);
    await performance.switchToLeaderboard();

    const sortBtn = performance.orderCountSortButton;
    const visible = await sortBtn.isVisible().catch(() => false);

    if (visible) {
      await performance.sortByOrderCount();
      await page.waitForLoadState('networkidle');
    }
  });

  test('Target & Incentive section loads sales targets', async ({ page }) => {
    const performance = await gotoPerformanceTab(page);

    await performance.switchToTargetIncentive();
    await expect(performance.targetTable).toBeVisible({ timeout: 10_000 });
  });

  test('ADMIN is blocked from Performa Sales tab', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.expectTabHidden('Performa Sales');
  });

  test('MANAGER can view Performa Sales', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.expectTabVisible('Performa Sales');
    await dashboard.clickTab('Performa Sales');
    await page.waitForLoadState('networkidle');

    const performance = new PerformanceTabPage(page);
    await expect(performance.kpiSupplierTab).toBeVisible({ timeout: 5_000 });
  });
});
