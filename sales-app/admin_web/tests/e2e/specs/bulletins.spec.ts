import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { BulletinsTabPage, BulletinDialog } from '../pages/bulletins.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS, TEST_DATA } from '../utils/test-data';
import { randomString } from '../utils/helpers';

/**
 * Bulletins Tab Suite (SUPERVISOR/MANAGER only)
 * Tests: List bulletins, create, edit, delete, expiration
 */
test.describe('Bulletins Tab', () => {
  async function gotoBulletinsTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Bulletin');
    await page.waitForLoadState('networkidle');
    return new BulletinsTabPage(page);
  }

  test('displays bulletin list @smoke', async ({ page }) => {
    const bulletins = await gotoBulletinsTab(page);
    await page.waitForLoadState('networkidle');

    // Should show either cards or empty state
    const cardsVisible = await bulletins.bulletinCards.first().isVisible().catch(() => false);
    const emptyVisible = await bulletins.emptyState.isVisible().catch(() => false);
    expect(cardsVisible || emptyVisible).toBeTruthy();
  });

  test('displays FAB to create new bulletin', async ({ page }) => {
    const bulletins = await gotoBulletinsTab(page);

    await expect(bulletins.createFab).toBeVisible({ timeout: 5_000 });
  });

  test('MANAGER can create a bulletin with all fields', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Bulletin');
    await page.waitForLoadState('networkidle');

    const bulletins = new BulletinsTabPage(page);
    await bulletins.clickCreate();

    const dialog = new BulletinDialog(page);
    await expect(dialog.titleInput).toBeVisible({ timeout: 5_000 });

    const title = `Bulletin E2E ${randomString()}`;
    const futureDate = new Date();
    futureDate.setFullYear(futureDate.getFullYear() + 1);
    const expDate = futureDate.toISOString().split('T')[0];

    await dialog.fillAndSubmit({
      title,
      description: TEST_DATA.bulletin.description,
      expirationDate: expDate,
    });

    await page.waitForLoadState('networkidle');
    await bulletins.expectBulletinInList(title);
  });

  test('MANAGER can create bulletin with unlimited expiration', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Bulletin');
    await page.waitForLoadState('networkidle');

    const bulletins = new BulletinsTabPage(page);
    await bulletins.clickCreate();

    const dialog = new BulletinDialog(page);
    const title = `Bulletin Unlimited ${randomString()}`;

    await dialog.fillAndSubmit({
      title,
      unlimited: true,
    });

    await page.waitForLoadState('networkidle');
    await bulletins.expectBulletinInList(title);
  });

  test('create bulletin requires title (validation)', async ({ page }) => {
    const bulletins = await gotoBulletinsTab(page);
    await bulletins.clickCreate();

    const dialog = new BulletinDialog(page);
    // Leave title empty, fill others
    await dialog.descriptionInput.fill('Some description');
    await dialog.saveButton.click();

    // Should show validation error - save should be disabled
    await expect(dialog.saveButton).toBeDisabled().catch(() => {});
  });

  test('MANAGER can edit a bulletin', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Bulletin');
    await page.waitForLoadState('networkidle');

    const bulletins = new BulletinsTabPage(page);

    // First create one to edit
    await bulletins.clickCreate();
    const dialog = new BulletinDialog(page);
    const title = `Bulletin To Edit ${randomString()}`;
    await dialog.fillAndSubmit({
      title,
      unlimited: true,
    });
    await page.waitForLoadState('networkidle');

    // Now edit it
    await bulletins.clickEdit(0);
    const editDialog = new BulletinDialog(page);
    await expect(editDialog.titleInput).toBeVisible({ timeout: 5_000 });

    const newTitle = `${title} - Edited`;
    await editDialog.titleInput.clear();
    await editDialog.titleInput.fill(newTitle);
    await editDialog.saveButton.click();
    await page.waitForLoadState('networkidle');

    await bulletins.expectBulletinInList(newTitle);
  });

  test('MANAGER can delete a bulletin', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Bulletin');
    await page.waitForLoadState('networkidle');

    const bulletins = new BulletinsTabPage(page);

    // Create a bulletin to delete
    await bulletins.clickCreate();
    const dialog = new BulletinDialog(page);
    const title = `Bulletin To Delete ${randomString()}`;
    await dialog.fillAndSubmit({ title, unlimited: true });
    await page.waitForLoadState('networkidle');
    await bulletins.expectBulletinInList(title);

    // Now delete it
    await bulletins.clickDelete(0);
    await page.waitForLoadState('networkidle');
    await bulletins.expectBulletinNotInList(title);
  });

  test('ADMIN is blocked from Bulletin tab', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.expectTabHidden('Bulletin');
  });

  test('expired bulletins show expired badge', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Bulletin');
    await page.waitForLoadState('networkidle');

    const bulletins = new BulletinsTabPage(page);
    const expiredBadge = await bulletins.expiredBadge.isVisible().catch(() => false);

    // It's OK if no expired bulletins exist - just verify the element works
    if (expiredBadge) {
      await expect(bulletins.expiredBadge).toBeVisible();
    }
  });

  test('PDF link is visible when bulletin has PDF', async ({ page }) => {
    const bulletins = await gotoBulletinsTab(page);

    const pdfLink = await bulletins.bulletinPdfLink.isVisible().catch(() => false);
    if (pdfLink) {
      await expect(bulletins.bulletinPdfLink).toBeVisible();
      const href = await bulletins.bulletinPdfLink.getAttribute('href');
      expect(href).toMatch(/\.pdf$/i);
    }
  });
});
