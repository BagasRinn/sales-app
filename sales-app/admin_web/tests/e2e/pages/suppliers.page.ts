import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Suppliers Tab - Tab 5
 */
export class SuppliersTabPage extends BasePage {
  // Filter chips
  readonly filterSemua: Locator;
  readonly filterAktif: Locator;
  readonly filterNonAktif: Locator;

  readonly searchInput: Locator;
  readonly buatSupplierButton: Locator;
  readonly supplierRows: Locator;

  // Table headers
  readonly namaHeader: Locator;
  readonly statusHeader: Locator;
  readonly tipeOrderHeader: Locator;
  readonly jumlahProdukHeader: Locator;
  readonly aksiHeader: Locator;

  // Action buttons (MANAGER only)
  readonly ubahTipeOrderButton: Locator;
  readonly nonaktifkanButton: Locator;
  readonly aktifkanButton: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.filterSemua = page.getByRole('button', { name: /semua/i }).first();
    this.filterAktif = page.getByRole('button', { name: /aktif/i }).first();
    this.filterNonAktif = page.getByRole('button', { name: /non.?aktif/i }).first();

    this.searchInput = page.getByPlaceholder(/cari|search/i);
    this.buatSupplierButton = page.getByRole('button', { name: /buat supplier|new supplier/i }).first();
    this.supplierRows = page.locator('tbody tr, [class*="supplier"], [class*="item"]');

    this.namaHeader = page.locator('th').filter({ hasText: /nama/i }).first();
    this.statusHeader = page.locator('th').filter({ hasText: /status/i }).first();
    this.tipeOrderHeader = page.locator('th').filter({ hasText: /tipe order/i }).first();
    this.jumlahProdukHeader = page.locator('th').filter({ hasText: /jumlah produk/i }).first();
    this.aksiHeader = page.locator('th').filter({ hasText: /aksi/i }).first();

    this.ubahTipeOrderButton = page.getByRole('button', { name: /ubah tipe order/i });
    this.nonaktifkanButton = page.getByRole('button', { name: /nonaktifkan/i });
    this.aktifkanButton = page.getByRole('button', { name: /aktifkan/i });
  }

  async filterByStatus(status: 'semua' | 'aktif' | 'non-aktif'): Promise<void> {
    const chips = { semua: this.filterSemua, aktif: this.filterAktif, 'non-aktif': this.filterNonAktif };
    await chips[status].click();
    await this.waitForLoadState('networkidle');
  }

  async search(query: string): Promise<void> {
    await this.searchInput.fill(query);
    await this.waitForLoadState('networkidle');
  }

  async clickBuatSupplier(): Promise<void> {
    await this.buatSupplierButton.click();
    await this.waitForLoadState('networkidle');
  }

  async expectSupplierInList(name: string): Promise<void> {
    const row = this.supplierRows.filter({ hasText: name }).first();
    await expect(row).toBeVisible({ timeout: 5_000 });
  }

  async clickUbahTipeOrder(index = 0): Promise<void> {
    await this.ubahTipeOrderButton.nth(index).click();
    await this.waitForLoadState('networkidle');
  }

  async toggleStatus(index = 0, activate = true): Promise<void> {
    if (activate) {
      await this.aktifkanButton.nth(index).click();
    } else {
      await this.nonaktifkanButton.nth(index).click();
    }
    await this.page.getByRole('button', { name: /ya|ok|confirm/i }).click();
    await this.waitForLoadState('networkidle');
  }

  async expectStatusBadge(status: 'Aktif' | 'Non-Aktif'): Promise<void> {
    const badge = this.page.locator('[class*="chip"], [class*="badge"], span').filter({ hasText: status }).first();
    await expect(badge).toBeVisible();
  }
}

// --- Buat/Edit Supplier Dialog ---
export class SupplierDialog {
  readonly namaInput: Locator;
  readonly orderTypeDropdown: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;

  constructor(readonly page: Page) {
    this.namaInput = page.getByLabel(/nama/i);
    this.orderTypeDropdown = page.locator('select, [role="combobox"]').filter({ hasText: /tipe order/i }).first();
    this.saveButton = page.getByRole('button', { name: /simpan|save/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
  }

  async fillAndSubmit(nama: string, orderType: 'REGULER' | '4P'): Promise<void> {
    await this.namaInput.fill(nama);
    await this.orderTypeDropdown.selectOption(orderType);
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }
}

// --- Ubah Tipe Order Dialog ---
export class UbahTipeOrderDialog {
  readonly regulerRadio: Locator;
  readonly empatPRadio: Locator;
  readonly affectedProductsInfo: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;

  constructor(readonly page: Page) {
    this.regulerRadio = page.getByLabel(/reguler/i);
    this.empatPRadio = page.getByLabel(/4p/i);
    this.affectedProductsInfo = page.getByText(/produk/i);
    this.saveButton = page.getByRole('button', { name: /simpan|save/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
  }

  async selectAndSave(type: 'REGULER' | '4P'): Promise<void> {
    if (type === 'REGULER') await this.regulerRadio.check();
    else await this.empatPRadio.check();
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }
}
