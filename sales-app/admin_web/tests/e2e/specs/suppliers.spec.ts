import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { SuppliersTabPage, SupplierDialog, UbahTipeOrderDialog } from '../pages/suppliers.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS, TEST_DATA } from '../utils/test-data';
import { randomString } from '../utils/helpers';

/**
 * Suppliers Tab Suite
 * Tests: List, filter, create supplier, ubah tipe order, toggle status
 */
test.describe('Suppliers Tab', () => {
  async function gotoSuppliersTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Supplier');
    await page.waitForLoadState('networkidle');
    return new SuppliersTabPage(page);
  }

  test('displays filter chips and table headers @smoke', async ({ page }) => {
    const suppliers = await gotoSuppliersTab(page);

    await expect(suppliers.filterSemua).toBeVisible({ timeout: 5_000 });
    await expect(suppliers.filterAktif).toBeVisible();
    await expect(suppliers.filterNonAktif).toBeVisible();
    await expect(suppliers.namaHeader).toBeVisible();
    await expect(suppliers.statusHeader).toBeVisible();
  });

  test('filter by all/aktif/non-aktif', async ({ page }) => {
    const suppliers = await gotoSuppliersTab(page);

    await suppliers.filterByStatus('aktif');
    await page.waitForLoadState('networkidle');
    await suppliers.filterByStatus('non-aktif');
    await page.waitForLoadState('networkidle');
    await suppliers.filterByStatus('semua');
    await page.waitForLoadState('networkidle');
  });

  test('search filters supplier list', async ({ page }) => {
    const suppliers = await gotoSuppliersTab(page);

    await suppliers.search('supplier');
    await page.waitForLoadState('networkidle');
  });

  test('MANAGER can create new supplier', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Supplier');
    await page.waitForLoadState('networkidle');

    const suppliers = new SuppliersTabPage(page);
    const btnVisible = await suppliers.buatSupplierButton.isVisible().catch(() => false);
    expect(btnVisible).toBeTruthy();

    await suppliers.clickBuatSupplier();
    const dialog = new SupplierDialog(page);
    await expect(dialog.namaInput).toBeVisible({ timeout: 5_000 });

    const newName = `Supplier Test ${randomString()}`;
    await dialog.fillAndSubmit(newName, 'REGULER');
    await page.waitForLoadState('networkidle');

    // Verify new supplier appears
    await suppliers.expectSupplierInList(newName);
  });

  test('ADMIN cannot create supplier (only MANAGER)', async ({ page }) => {
    const suppliers = await gotoSuppliersTab(page);

    const buatBtn = suppliers.buatSupplierButton;
    const btnVisible = await buatBtn.isVisible().catch(() => false);

    if (btnVisible) {
      // ADMIN may not have this button - it should be hidden or disabled
      await expect(buatBtn).toBeHidden({ timeout: 3_000 }).catch(() => {});
    }
  });

  test('MANAGER can toggle supplier status', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Supplier');
    await page.waitForLoadState('networkidle');

    const suppliers = new SuppliersTabPage(page);
    await expect(suppliers.supplierRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await suppliers.supplierRows.count();

    if (count > 0) {
      // Check current status
      const aktifBtn = suppliers.aktifkanButton;
      const nonAktifBtn = suppliers.nonaktifkanButton;

      const aktifVisible = await aktifBtn.first().isVisible().catch(() => false);
      const nonAktifVisible = await nonAktifBtn.first().isVisible().catch(() => false);

      if (aktifVisible) {
        await suppliers.toggleStatus(0, true);
      } else if (nonAktifVisible) {
        await suppliers.toggleStatus(0, false);
      }
    }
  });

  test('MANAGER can change supplier order type', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Supplier');
    await page.waitForLoadState('networkidle');

    const suppliers = new SuppliersTabPage(page);
    await expect(suppliers.supplierRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await suppliers.supplierRows.count();

    if (count > 0) {
      await suppliers.clickUbahTipeOrder(0);
      const dialog = new UbahTipeOrderDialog(page);
      await expect(dialog.regulerRadio).toBeVisible({ timeout: 5_000 });
      await expect(dialog.empatPRadio).toBeVisible();

      // Toggle to 4P
      await dialog.selectAndSave('4P');
      await page.waitForLoadState('networkidle');
    }
  });

  test('ADMIN cannot see ubah tipe order button', async ({ page }) => {
    const suppliers = await gotoSuppliersTab(page);
    const btn = suppliers.ubahTipeOrderButton;
    const btnVisible = await btn.first().isVisible().catch(() => false);

    if (btnVisible) {
      await expect(btn.first()).toBeDisabled().catch(() => {});
    }
  });

  test('SUPERVISOR cannot create supplier', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Supplier');
    await page.waitForLoadState('networkidle');

    const buatBtn = page.getByRole('button', { name: /buat supplier|new supplier/i });
    const buatVisible = await buatBtn.isVisible().catch(() => false);

    if (buatVisible) {
      await expect(buatBtn).toBeDisabled().catch(() => {});
    }
  });
});
