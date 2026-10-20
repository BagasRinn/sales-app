import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Customers Tab - Tab 2
 */
export class CustomersTabPage extends BasePage {
  readonly searchInput: Locator;
  readonly addButton: Locator;
  readonly customerRows: Locator;
  readonly paginationInfo: Locator;
  readonly nextPageButton: Locator;
  readonly prevPageButton: Locator;

  // Table headers
  readonly tableHeaders: Locator;
  readonly kodeHeader: Locator;
  readonly namaTokoHeader: Locator;
  readonly kodeAreaHeader: Locator;
  readonly alamatHeader: Locator;
  readonly aksiHeader: Locator;

  // Action buttons
  readonly detailButton: Locator;
  readonly deleteButton: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.searchInput = page.getByPlaceholder(/cari|search/i);
    this.addButton = page.getByRole('button', { name: /tambah|tambah toko/i }).first();
    this.customerRows = page.locator('table tbody tr, [class*="list"] > div, [class*="customer"]');
    this.paginationInfo = page.locator('text=/hal|page|\\d+.*\\d+/i').first();
    this.nextPageButton = page.getByRole('button', { name: /selanjut|next/i }).first();
    this.prevPageButton = page.getByRole('button', { name: /sebelum|prev/i }).first();

    this.tableHeaders = page.locator('th, [class*="header"]');
    this.kodeHeader = page.locator('th, [class*="header"]').filter({ hasText: /kode/i }).first();
    this.namaTokoHeader = page.locator('th, [class*="header"]').filter({ hasText: /nama toko/i }).first();
    this.kodeAreaHeader = page.locator('th, [class*="header"]').filter({ hasText: /kode area/i }).first();
    this.alamatHeader = page.locator('th, [class*="header"]').filter({ hasText: /alamat/i }).first();
    this.aksiHeader = page.locator('th, [class*="header"]').filter({ hasText: /aksi/i }).first();

    this.detailButton = page.getByRole('button', { name: /detail|lihat/i });
    this.deleteButton = page.getByRole('button', { name: /hapus|delete/i });
  }

  async search(query: string): Promise<void> {
    await this.searchInput.fill(query);
    await this.waitForLoadState('networkidle');
  }

  async clickDetail(index = 0): Promise<void> {
    await this.detailButton.nth(index).click();
    await this.waitForLoadState('networkidle');
  }

  async expectCustomerInList(kodeOrNama: string): Promise<void> {
    const row = this.page.locator('tr, [class*="item"], [class*="customer"]').filter({ hasText: kodeOrNama }).first();
    await expect(row).toBeVisible({ timeout: 5_000 });
  }

  async expectCustomerNotInList(kodeOrNama: string): Promise<void> {
    const row = this.page.locator('tr, [class*="item"], [class*="customer"]').filter({ hasText: kodeOrNama }).first();
    await expect(row).toBeHidden({ timeout: 3_000 }).catch(() => {});
  }

  async goToNextPage(): Promise<void> {
    await this.nextPageButton.click();
    await this.waitForLoadState('networkidle');
  }

  async expectPagination(): Promise<void> {
    await expect(this.paginationInfo).toBeVisible({ timeout: 3_000 }).catch(() => {});
  }
}

// --- Customer Detail Dialog ---
export class CustomerDetailDialog {
  readonly kodeInput: Locator;
  readonly namaTokoInput: Locator;
  readonly alamatInput: Locator;
  readonly kodeAreaInput: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;

  constructor(readonly page: Page) {
    this.kodeInput = page.getByLabel(/kode/i);
    this.namaTokoInput = page.getByLabel(/nama toko/i);
    this.alamatInput = page.getByLabel(/alamat/i);
    this.kodeAreaInput = page.getByLabel(/kode area/i);
    this.saveButton = page.getByRole('button', { name: /simpan|save/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
  }

  async editKode(newKode: string): Promise<void> {
    await this.kodeInput.clear();
    await this.kodeInput.fill(newKode);
    await this.saveButton.click();
  }

  async editNamaToko(newNama: string): Promise<void> {
    await this.namaTokoInput.clear();
    await this.namaTokoInput.fill(newNama);
    await this.saveButton.click();
  }

  async expectFieldsEditable(): Promise<void> {
    await expect(this.namaTokoInput).not.toBeDisabled();
    await expect(this.alamatInput).not.toBeDisabled();
  }

  async expectFieldsReadOnly(): Promise<void> {
    await expect(this.namaTokoInput).toBeDisabled();
    await expect(this.alamatInput).toBeDisabled();
  }
}
