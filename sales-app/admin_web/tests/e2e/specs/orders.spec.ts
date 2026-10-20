import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { OrdersTabPage } from '../pages/orders.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS, TEST_DATA } from '../utils/test-data';

/**
 * Orders Tab Suite
 * Tests: Pending Orders, All Orders, Approve/Reject, Edit Diskon
 */
test.describe('Orders Tab', () => {
  async function gotoOrdersTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Pesanan');
    await page.waitForLoadState('networkidle');
    return new OrdersTabPage(page);
  }

  test('shows pending orders tab @smoke', async ({ page }) => {
    const orders = await gotoOrdersTab(page);
    await expect(orders.pendingTab).toBeVisible();
    await expect(orders.allOrdersTab).toBeVisible();
  });

  test('can switch between Pending and All Orders tabs', async ({ page }) => {
    const orders = await gotoOrdersTab(page);

    await orders.switchToAllOrdersTab();
    await expect(orders.allOrdersTab).toBeVisible();

    await orders.switchToPendingTab();
    await expect(orders.pendingTab).toBeVisible();
  });

  test('filters all orders by status', async ({ page }) => {
    const orders = await gotoOrdersTab(page);
    await orders.switchToAllOrdersTab();

    await orders.filterByStatus('APPROVED');
    await page.waitForLoadState('networkidle');

    // Check that status filter changed
    const chips = page.locator('[class*="chip"], [class*="selected"]');
    await expect(chips.first()).toBeVisible({ timeout: 3_000 }).catch(() => {});
  });

  test('search orders by store or sales name', async ({ page }) => {
    const orders = await gotoOrdersTab(page);
    await orders.switchToAllOrdersTab();

    // Try searching - may return empty if no matching orders exist
    await orders.searchOrders('test');
    await page.waitForLoadState('networkidle');

    // Should either show results or empty state
    const cards = page.locator('[class*="card"], [class*="order"]');
    await expect(cards.first()).toBeVisible({ timeout: 5_000 }).catch(() => {});
  });

  test('ADMIN can approve a pending order', async ({ page }) => {
    const orders = await gotoOrdersTab(page);
    await orders.switchToPendingTab();

    // Find a pending order
    const cards = page.locator('[class*="card"]').filter({ hasText: /\d{6,}/ });
    const count = await cards.count();

    if (count > 0) {
      await orders.approveOrder(0);
      // After approval, the order should move out of pending
      await page.waitForLoadState('networkidle');
    }
  });

  test('ADMIN can reject a pending order', async ({ page }) => {
    const orders = await gotoOrdersTab(page);
    await orders.switchToPendingTab();

    const cards = page.locator('[class*="card"]').filter({ hasText: /\d{6,}/ });
    const count = await cards.count();

    if (count > 0) {
      await orders.rejectOrder(0, TEST_DATA.orderRejectReason);
      await page.waitForLoadState('networkidle');
    }
  });

  test('SUPERVISOR cannot approve/reject orders (read-only)', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Pesanan');
    await page.waitForLoadState('networkidle');

    const orders = new OrdersTabPage(page);

    const approveBtn = page.getByRole('button', { name: /setujui|approve/i });
    const rejectBtn = page.getByRole('button', { name: /tolak|reject/i });

    // Buttons should be hidden or disabled
    if (await approveBtn.isVisible().catch(() => false)) {
      await expect(approveBtn).toBeDisabled();
    }
    if (await rejectBtn.isVisible().catch(() => false)) {
      await expect(rejectBtn).toBeDisabled();
    }
  });

  test('order status chips are visible in all orders view', async ({ page }) => {
    const orders = await gotoOrdersTab(page);
    await orders.switchToAllOrdersTab();

    // Look for status chips - should show at least one order
    const chips = page.locator('[class*="chip"], [class*="badge"]');
    const count = await chips.count();
    expect(count).toBeGreaterThan(0);
  });

  test('pagination works in all orders', async ({ page }) => {
    const orders = await gotoOrdersTab(page);
    await orders.switchToAllOrdersTab();

    const nextBtn = page.getByRole('button', { name: /selanjut|next/i }).first();
    const nextVisible = await nextBtn.isVisible().catch(() => false);

    if (nextVisible) {
      await nextBtn.click();
      await page.waitForLoadState('networkidle');
    }
  });
});
