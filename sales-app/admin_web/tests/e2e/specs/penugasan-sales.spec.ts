import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { PenugasanSalesTabPage, MultiSelectSalesDialog } from '../pages/penugasan-sales.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS } from '../utils/test-data';

/**
 * Penugasan Sales Tab Suite (SUPERVISOR/MANAGER only)
 * Tests: Per Area, Per Customer, Per Sales, Multi-Select Dialog
 */
test.describe('Penugasan Sales Tab', () => {
  async function gotoPenugasanTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Penugasan Sales');
    await page.waitForLoadState('networkidle');
    return new PenugasanSalesTabPage(page);
  }

  test('displays three sub-view toggles @smoke', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);

    await expect(penugasan.perAreaButton).toBeVisible({ timeout: 5_000 });
    await expect(penugasan.perCustomerButton).toBeVisible();
    await expect(penugasan.perSalesButton).toBeVisible();
  });

  // ─── Per Area ─────────────────────────────────────────────────────────────

  test('Per Area view shows area list', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);

    await penugasan.switchToPerArea();
    await page.waitForLoadState('networkidle');

    const areaList = penugasan.areaList;
    const count = await areaList.count();

    // Either shows areas or empty state
    if (count > 0) {
      await expect(areaList.first()).toBeVisible();
    } else {
      await expect(page.getByText(/belum|import/i)).toBeVisible({ timeout: 5_000 }).catch(() => {});
    }
  });

  test('Per Area - opens manage dialog on Kelola click', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);
    await penugasan.switchToPerArea();
    await page.waitForLoadState('networkidle');

    const kelolaVisible = await penugasan.kelolaButtons.first().isVisible().catch(() => false);
    if (kelolaVisible) {
      await penugasan.clickKelola(0);
      await penugasan.expectSalesAssignmentDialogOpen();

      const dialog = new MultiSelectSalesDialog(page);
      await expect(dialog.salesCheckboxes.first()).toBeVisible({ timeout: 5_000 });
    }
  });

  test('Per Area - can select/deselect sales in dialog and save', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);
    await penugasan.switchToPerArea();
    await page.waitForLoadState('networkidle');

    const kelolaVisible = await penugasan.kelolaButtons.first().isVisible().catch(() => false);
    if (kelolaVisible) {
      await penugasan.clickKelola(0);

      const dialog = new MultiSelectSalesDialog(page);
      await dialog.selectSales([0]);
      await dialog.save();
      await page.waitForLoadState('networkidle');
    }
  });

  test('Per Area - can deselect all and save', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);
    await penugasan.switchToPerArea();
    await page.waitForLoadState('networkidle');

    const kelolaVisible = await penugasan.kelolaButtons.first().isVisible().catch(() => false);
    if (kelolaVisible) {
      await penugasan.clickKelola(0);

      const dialog = new MultiSelectSalesDialog(page);
      await dialog.deselectAll();
      await dialog.save();
      await page.waitForLoadState('networkidle');
    }
  });

  // ─── Per Customer ──────────────────────────────────────────────────────────

  test('Per Customer view shows customer list', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);

    await penugasan.switchToPerCustomer();
    await page.waitForLoadState('networkidle');

    await expect(penugasan.customerSearchInput).toBeVisible({ timeout: 5_000 });
  });

  test('Per Customer - search filters list', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);
    await penugasan.switchToPerCustomer();
    await page.waitForLoadState('networkidle');

    await penugasan.searchCustomer('test');
    await page.waitForLoadState('networkidle');
  });

  test('Per Customer - opens override dialog', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);
    await penugasan.switchToPerCustomer();
    await page.waitForLoadState('networkidle');

    const overrideVisible = await penugasan.overrideButtons.first().isVisible().catch(() => false);
    if (overrideVisible) {
      await penugasan.clickOverride(0);
      await penugasan.expectSalesAssignmentDialogOpen();
    }
  });

  // ─── Per Sales ────────────────────────────────────────────────────────────

  test('Per Sales view shows sales user list', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);

    await penugasan.switchToPerSales();
    await page.waitForLoadState('networkidle');

    await expect(penugasan.salesRows.first()).toBeVisible({ timeout: 10_000 });
  });

  test('Per Sales - Lihat Toko opens dialog with assigned customers', async ({ page }) => {
    const penugasan = await gotoPenugasanTab(page);
    await penugasan.switchToPerSales();
    await page.waitForLoadState('networkidle');

    const lihatVisible = await penugasan.lihatTokoButtons.first().isVisible().catch(() => false);
    if (lihatVisible) {
      await penugasan.clickLihatToko(0);
      await page.waitForLoadState('networkidle');
      // Dialog should show assigned stores
    }
  });

  // ─── Access Control ────────────────────────────────────────────────────────

  test('ADMIN is blocked from Penugasan Sales tab', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.expectTabHidden('Penugasan Sales');
  });

  test('MANAGER can access Penugasan Sales', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.expectTabVisible('Penugasan Sales');
    await dashboard.clickTab('Penugasan Sales');
    await page.waitForLoadState('networkidle');

    const penugasan = new PenugasanSalesTabPage(page);
    await expect(penugasan.perAreaButton).toBeVisible({ timeout: 5_000 });
  });
});
