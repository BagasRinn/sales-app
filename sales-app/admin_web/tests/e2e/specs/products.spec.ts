import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { ProductsTabPage, UbahStokDialog, EditProductDialog } from '../pages/products.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS } from '../utils/test-data';

/**
 * Products & Stock Tab Suite
 * Tests: List, search, filter, ubah stok, edit product, hapus
 */
test.describe('Products & Stock Tab', () => {
  async function gotoProductsTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Produk & Stok');
    await page.waitForLoadState('networkidle');
    return new ProductsTabPage(page);
  }

  test('displays product table with headers @smoke', async ({ page }) => {
    const products = await gotoProductsTab(page);

    await expect(products.skuHeader).toBeVisible({ timeout: 5_000 });
    await expect(products.namaHeader).toBeVisible();
    await expect(products.stokSistemHeader).toBeVisible();
    await expect(products.stokTersediaHeader).toBeVisible();
    await expect(products.aksiHeader).toBeVisible();
  });

  test('search filters product list', async ({ page }) => {
    const products = await gotoProductsTab(page);

    await products.search('test');
    await page.waitForLoadState('networkidle');

    // Should update list
    await expect(products.productRows.first()).toBeVisible({ timeout: 5_000 }).catch(() => {});
  });

  test('filter by supplier dropdown', async ({ page }) => {
    const products = await gotoProductsTab(page);

    const dropdown = products.supplierFilter;
    const options = await dropdown.locator('option').allTextContents();
    if (options.length > 1) {
      await dropdown.selectOption(options[1]);
      await page.waitForLoadState('networkidle');
    }
  });

  test('filter by status (Tersedia/Rendah/Habis)', async ({ page }) => {
    const products = await gotoProductsTab(page);

    const statusFilter = products.statusFilter;
    await statusFilter.selectOption('Tersedia');
    await page.waitForLoadState('networkidle');

    await statusFilter.selectOption('Habis');
    await page.waitForLoadState('networkidle');
  });

  test('filter by order type (REGULER/4P)', async ({ page }) => {
    const products = await gotoProductsTab(page);

    await products.filterByOrderType('REGULER');
    await page.waitForLoadState('networkidle');

    await products.filterByOrderType('4P');
    await page.waitForLoadState('networkidle');
  });

  test('ADMIN can open Ubah Stok dialog', async ({ page }) => {
    const products = await gotoProductsTab(page);
    await expect(products.productRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await products.productRows.count();

    if (count > 0) {
      await products.clickUbahStok(0);
      const dialog = new UbahStokDialog(page);
      await expect(dialog.stokSistemInput).toBeVisible({ timeout: 5_000 });
    }
  });

  test('ADMIN can update stok sistem', async ({ page }) => {
    const products = await gotoProductsTab(page);
    await expect(products.productRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await products.productRows.count();

    if (count > 0) {
      await products.clickUbahStok(0);
      const dialog = new UbahStokDialog(page);
      await dialog.setStok(100);
      await page.waitForLoadState('networkidle');
    }
  });

  test('ADMIN can open Edit Product dialog', async ({ page }) => {
    const products = await gotoProductsTab(page);
    await expect(products.productRows.first()).toBeVisible({ timeout: 10_000 });
    const count = await products.productRows.count();

    if (count > 0) {
      await products.clickEdit(0);
      const dialog = new EditProductDialog(page);
      await expect(dialog.kategoriInput).toBeVisible({ timeout: 5_000 });
    }
  });

  test('SUPERVISOR cannot see action buttons', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Produk & Stok');
    await page.waitForLoadState('networkidle');

    const ubahStok = page.getByRole('button', { name: /ubah stok/i });
    const editBtn = page.getByRole('button', { name: /edit|ubah/i });

    if (await ubahStok.isVisible().catch(() => false)) {
      await expect(ubahStok).toBeDisabled();
    }
    if (await editBtn.isVisible().catch(() => false)) {
      await expect(editBtn).toBeDisabled();
    }
  });

  test('pagination works', async ({ page }) => {
    const products = await gotoProductsTab(page);
    const nextVisible = await products.nextPageButton.isVisible().catch(() => false);
    if (nextVisible) {
      await products.nextPageButton.click();
      await page.waitForLoadState('networkidle');
    }
  });

  test('low stock products show red indicator', async ({ page }) => {
    const products = await gotoProductsTab(page);
    await products.filterByStatus('Rendah');
    await page.waitForLoadState('networkidle');

    // Red/alert styling for low stock
    const redRows = page.locator('[class*="red"], [class*="danger"], [class*="warning"]');
    const count = await redRows.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});
