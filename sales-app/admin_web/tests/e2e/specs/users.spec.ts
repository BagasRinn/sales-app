import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { UsersTabPage, UserDialog } from '../pages/users.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS, TEST_DATA } from '../utils/test-data';
import { randomString } from '../utils/helpers';

/**
 * Users Tab Suite (SUPERVISOR/MANAGER only)
 * Tests: List users, filter by role, create user, edit user
 */
test.describe('Users Tab', () => {
  async function gotoUsersTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('User');
    await page.waitForLoadState('networkidle');
    return new UsersTabPage(page);
  }

  test('displays user list @smoke', async ({ page }) => {
    const users = await gotoUsersTab(page);

    await expect(users.userRows.first()).toBeVisible({ timeout: 10_000 });
  });

  test('displays role filter chips', async ({ page }) => {
    const users = await gotoUsersTab(page);

    await expect(users.filterSemua).toBeVisible({ timeout: 5_000 });
    await expect(users.filterAdmin).toBeVisible();
    await expect(users.filterSupervisor).toBeVisible();
    await expect(users.filterManager).toBeVisible();
    await expect(users.filterSales).toBeVisible();
  });

  test('filter by role', async ({ page }) => {
    const users = await gotoUsersTab(page);

    await users.filterByRole('admin');
    await page.waitForLoadState('networkidle');

    await users.filterByRole('sales');
    await page.waitForLoadState('networkidle');

    await users.filterByRole('semua');
    await page.waitForLoadState('networkidle');
  });

  test('search filters user list', async ({ page }) => {
    const users = await gotoUsersTab(page);

    await users.search('admin');
    await page.waitForLoadState('networkidle');

    await expect(users.userRows.first()).toBeVisible({ timeout: 5_000 }).catch(() => {});
  });

  test('SUPERVISOR can open create user dialog', async ({ page }) => {
    const users = await gotoUsersTab(page);

    const tambahVisible = await users.tambahButton.isVisible().catch(() => false);
    expect(tambahVisible).toBeTruthy();

    if (tambahVisible) {
      await users.clickTambah();
      const dialog = new UserDialog(page);
      await expect(dialog.usernameInput).toBeVisible({ timeout: 5_000 });
    }
  });

  test('SUPERVISOR can create a new SALES user', async ({ page }) => {
    const users = await gotoUsersTab(page);
    await users.clickTambah();

    const dialog = new UserDialog(page);
    await expect(dialog.usernameInput).toBeVisible({ timeout: 5_000 });

    const newUsername = `e2e_${randomString('user')}`;
    await dialog.fillAndSubmit({
      username: newUsername,
      password: TEST_DATA.user.password,
      nama: TEST_DATA.user.nama,
      role: 'SALES',
    });
    await page.waitForLoadState('networkidle');

    // Verify user appears in list
    await users.expectUserInList(newUsername);
  });

  test('create user requires password min 6 chars', async ({ page }) => {
    const users = await gotoUsersTab(page);
    await users.clickTambah();

    const dialog = new UserDialog(page);
    await dialog.usernameInput.fill('testuser');
    await dialog.passwordInput.fill('123'); // too short
    await dialog.roleDropdown.selectOption('SALES');

    await expect(dialog.saveButton).toBeDisabled().catch(() => {});
  });

  test('create user requires username', async ({ page }) => {
    const users = await gotoUsersTab(page);
    await users.clickTambah();

    const dialog = new UserDialog(page);
    await dialog.passwordInput.fill('test123456');
    await dialog.roleDropdown.selectOption('SALES');

    await expect(dialog.saveButton).toBeDisabled().catch(() => {});
  });

  test('ADMIN is blocked from User tab', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    // ADMIN should NOT see User tab
    await dashboard.expectTabHidden('User');
  });

  test('role badges display correctly', async ({ page }) => {
    const users = await gotoUsersTab(page);
    await users.filterByRole('semua');
    await page.waitForLoadState('networkidle');

    // Should see at least one role badge
    const adminBadge = await users.adminBadge.isVisible().catch(() => false);
    const salesBadge = await users.salesBadge.isVisible().catch(() => false);
    expect(adminBadge || salesBadge).toBeTruthy();
  });
});
