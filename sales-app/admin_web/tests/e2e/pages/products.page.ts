import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Products & Stock Tab - Tab 4
 */
export class ProductsTabPage extends BasePage {
  readonly searchInput: Locator;
  readonly supplierFilter: Locator;
  readonly statusFilter: Locator;
  readonly orderTypeFilter: Locator;
  readonly addButton: Locator;
  readonly productRows: Locator;
  readonly activeFilters: Locator;

  // Table headers
  readonly skuHeader: Locator;
  readonly namaHeader: Locator;
  readonly stokSistemHeader: Locator;
  readonly stokTersediaHeader: Locator;
  readonly aksiHeader: Locator;

  // Action buttons (ADMIN only)
  readonly ubahStokButton: Locator;
  readonly editButton: Locator;
  readonly hapusButton: Locator;

  // Pagination
  readonly paginationInfo: Locator;
  readonly nextPageButton: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.searchInput = page.getByPlaceholder(/cari|search/i);
    this.supplierFilter = page.locator('select, [role="combobox"]').nth(0);
    this.statusFilter = page.locator('select, [role="combobox"]').nth(1);
    this.orderTypeFilter = page.locator('select, [role="combobox"]').nth(2);
    this.addButton = page.getByRole('button', { name: /tambah produk/i }).first();
    this.productRows = page.locator('tbody tr, [class*="product"], [class*="item"]');
    this.activeFilters = page.locator('[class*="chip"], [class*="tag"]').filter({ hasText: /supplier|status|tipe/i });

    this.skuHeader = page.locator('th').filter({ hasText: /sku/i }).first();
    this.namaHeader = page.locator('th').filter({ hasText: /nama/i }).first();
    this.stokSistemHeader = page.locator('th').filter({ hasText: /stok sistem/i }).first();
    this.stokTersediaHeader = page.locator('th').filter({ hasText: /stok tersedia/i }).first();
    this.aksiHeader = page.locator('th').filter({ hasText: /aksi/i }).first();

    this.ubahStokButton = page.getByRole('button', { name: /ubah stok/i });
    this.editButton = page.getByRole('button', { name: /edit|ubah/i }).nth(1);
    this.hapusButton = page.getByRole('button', { name: /hapus|delete/i });

    this.paginationInfo = page.locator('text=/hal|page/i').first();
    this.nextPageButton = page.getByRole('button', { name: /selanjut|next/i }).first();
  }

  async search(query: string): Promise<void> {
    await this.searchInput.fill(query);
    await this.waitForLoadState('networkidle');
  }

  async filterBySupplier(supplier: string): Promise<void> {
    await this.supplierFilter.selectOption(supplier);
    await this.waitForLoadState('networkidle');
  }

  async filterByStatus(status: 'Tersedia' | 'Rendah' | 'Habis'): Promise<void> {
    await this.statusFilter.selectOption(status);
    await this.waitForLoadState('networkidle');
  }

  async filterByOrderType(type: 'REGULER' | '4P'): Promise<void> {
    await this.orderTypeFilter.selectOption(type);
    await this.waitForLoadState('networkidle');
  }

  async clearFilters(): Promise<void> {
    const chips = this.page.locator('[class*="chip"]').filter({ hasText: /×|X|hapus|hapus filter/i });
    const count = await chips.count();
    for (let i = 0; i < count; i++) {
      await chips.first().click();
    }
  }

  async expectProductInList(skuOrNama: string): Promise<void> {
    const row = this.productRows.filter({ hasText: skuOrNama }).first();
    await expect(row).toBeVisible({ timeout: 5_000 });
  }

  async clickUbahStok(index = 0): Promise<void> {
    await this.ubahStokButton.nth(index).click();
    await this.waitForLoadState('networkidle');
  }

  async clickEdit(index = 0): Promise<void> {
    await this.editButton.nth(index).click();
    await this.waitForLoadState('networkidle');
  }

  async clickHapus(index = 0): Promise<void> {
    await this.hapusButton.nth(index).click();
    await this.page.getByRole('button', { name: /ya|ok|hapus|confirm/i }).click();
    await this.waitForLoadState('networkidle');
  }
}

// --- Ubah Stok Dialog ---
export class UbahStokDialog {
  readonly stokSistemInput: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;

  constructor(readonly page: Page) {
    this.stokSistemInput = page.getByLabel(/stok sistem/i);
    this.saveButton = page.getByRole('button', { name: /simpan|save/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
  }

  async setStok(value: number): Promise<void> {
    await this.stokSistemInput.clear();
    await this.stokSistemInput.fill(String(value));
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }
}

// --- Edit Product Dialog ---
export class EditProductDialog {
  readonly kategoriInput: Locator;
  readonly satuanInput: Locator;
  readonly supplierDropdown: Locator;
  readonly orderTypeDropdown: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;

  constructor(readonly page: Page) {
    this.kategoriInput = page.getByLabel(/kategori/i);
    this.satuanInput = page.getByLabel(/satuan/i);
    this.supplierDropdown = page.locator('select, [role="combobox"]').filter({ hasText: /supplier/i }).first();
    this.orderTypeDropdown = page.locator('select, [role="combobox"]').filter({ hasText: /tipe order/i }).first();
    this.saveButton = page.getByRole('button', { name: /simpan|save/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
  }

  async setKategori(kategori: string): Promise<void> {
    await this.kategoriInput.clear();
    await this.kategoriInput.fill(kategori);
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async setOrderType(type: 'REGULER' | '4P'): Promise<void> {
    await this.orderTypeDropdown.selectOption(type);
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }
}
