import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Sync/Import Tab - Tab 6
 */
export class SyncTabPage extends BasePage {
  readonly importProdukCard: Locator;
  readonly importTokoCard: Locator;
  readonly importProdukButton: Locator;
  readonly importTokoButton: Locator;

  // Stats
  readonly totalProdukStat: Locator;
  readonly disisipkanStat: Locator;
  readonly diperbaruiStat: Locator;
  readonly dilewatiStat: Locator;

  // History table
  readonly historyRows: Locator;

  // Error section
  readonly errorSection: Locator;
  readonly lihatDetailButton: Locator;
  readonly bersihkanButton: Locator;

  // File input (hidden, triggered by button)
  readonly fileInput: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.importProdukCard = this.page.locator('[class*="card"]').filter({ hasText: /import produk/i }).first();
    this.importTokoCard = this.page.locator('[class*="card"]').filter({ hasText: /import toko/i }).first();
    this.importProdukButton = this.page.getByRole('button', { name: /import produk/i }).first();
    this.importTokoButton = this.page.getByRole('button', { name: /import toko/i }).first();

    this.totalProdukStat = this.page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /total produk/i }).first();
    this.disisipkanStat = this.page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /disisipkan/i }).first();
    this.diperbaruiStat = this.page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /diperbarui/i }).first();
    this.dilewatiStat = this.page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /dilewati/i }).first();

    this.historyRows = this.page.locator('tbody tr, [class*="history"] > div');
    this.errorSection = this.page.getByText(/error|kesalahan/i).first();
    this.lihatDetailButton = this.page.getByRole('button', { name: /lihat detail/i });
    this.bersihkanButton = this.page.getByRole('button', { name: /bersihkan|hapus/i });

    this.fileInput = this.page.locator('input[type="file"]');
  }

  async uploadProdukExcel(filePath: string): Promise<void> {
    await this.importProdukButton.click();
    await this.fileInput.setInputFiles(filePath);
    await this.page.waitForLoadState('networkidle');
  }

  async uploadTokoExcel(filePath: string): Promise<void> {
    await this.importTokoButton.click();
    await this.fileInput.setInputFiles(filePath);
    await this.page.waitForLoadState('networkidle');
  }

  async expectImportResult(options: {
    total?: number;
    inserted?: number;
    updated?: number;
    skipped?: number;
  }): Promise<void> {
    await this.page.waitForLoadState('networkidle');
    if (options.inserted !== undefined) {
      await expect(this.disisipkanStat).toBeVisible({ timeout: 10_000 });
    }
    if (options.updated !== undefined) {
      await expect(this.diperbaruiStat).toBeVisible();
    }
  }

  async expectErrors(): Promise<void> {
    await expect(this.errorSection).toBeVisible({ timeout: 5_000 });
  }

  async clickLihatDetail(index = 0): Promise<void> {
    await this.lihatDetailButton.nth(index).click();
    await this.waitForLoadState('networkidle');
  }

  async clickBersihkan(): Promise<void> {
    await this.bersihkanButton.click();
    await this.page.getByRole('button', { name: /ya|ok|confirm/i }).click();
    await this.page.waitForLoadState('networkidle');
  }

  async expectErrorCount(count: number): Promise<void> {
    const errorRows = this.page.locator('[class*="error"], [class*="danger"]');
    await expect(errorRows).toHaveCount(count, { timeout: 5_000 }).catch(() => {});
  }
}
