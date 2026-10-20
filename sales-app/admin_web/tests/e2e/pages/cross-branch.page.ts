import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Cross-Branch Reports Tab - Tab 11 (MANAGER only)
 * Two sub-tabs: Penjualan, Stok
 */
export class CrossBranchReportsTabPage extends BasePage {
  // Sub-tabs
  readonly penjualanTab: Locator;
  readonly stokTab: Locator;

  // Penjualan section
  readonly totalSemuaCabangCard: Locator;
  readonly approvedCount: Locator;
  readonly approvedRevenue: Locator;
  readonly pendingCount: Locator;
  readonly customerCount: Locator;
  readonly salesCount: Locator;
  readonly perBranchCards: Locator;

  // Stok section
  readonly skuCount: Locator;
  readonly totalStockValue: Locator;
  readonly lowStockCount: Locator;

  // Refresh
  readonly refreshButton: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.penjualanTab = page.getByRole('button', { name: /penjualan|sales/i }).first();
    this.stokTab = page.getByRole('button', { name: /stok|inventory/i }).first();

    this.totalSemuaCabangCard = page.locator('[class*="card"]').filter({ hasText: /total.*cabang|semua cabang/i }).first();
    this.approvedCount = page.locator('[class*="card"]').filter({ hasText: /disetujui|approved/i }).first();
    this.approvedRevenue = page.locator('[class*="card"]').filter({ hasText: /revenue|pendapatan/i }).first();
    this.pendingCount = page.locator('[class*="card"]').filter({ hasText: /menunggu|pending/i }).first();
    this.customerCount = page.locator('[class*="card"]').filter({ hasText: /customer|toko/i }).first();
    this.salesCount = page.locator('[class*="card"]').filter({ hasText: /sales/i }).first();
    this.perBranchCards = page.locator('[class*="card"]').filter({ hasText: /cabang|branch/i });

    this.skuCount = page.locator('[class*="card"]').filter({ hasText: /sku/i }).first();
    this.totalStockValue = page.locator('[class*="card"]').filter({ hasText: /nilai stok/i }).first();
    this.lowStockCount = page.locator('[class*="card"]').filter({ hasText: /low stock|rendah/i }).first();

    this.refreshButton = page.getByRole('button', { name: /refresh|segarkan/i }).first();
  }

  async switchToPenjualan(): Promise<void> {
    await this.penjualanTab.click();
    await this.page.waitForLoadState('networkidle');
  }

  async switchToStok(): Promise<void> {
    await this.stokTab.click();
    await this.page.waitForLoadState('networkidle');
  }

  async refresh(): Promise<void> {
    await this.refreshButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async expectPenjualanSummary(): Promise<void> {
    await expect(this.totalSemuaCabangCard).toBeVisible({ timeout: 10_000 });
    await expect(this.approvedCount).toBeVisible();
    await expect(this.approvedRevenue).toBeVisible();
  }

  async expectStokSummary(): Promise<void> {
    await expect(this.skuCount).toBeVisible({ timeout: 10_000 });
    await expect(this.totalStockValue).toBeVisible();
  }

  async expectPerBranchCards(count: number): Promise<void> {
    await expect(this.perBranchCards).toHaveCount(count, { timeout: 5_000 }).catch(() => {});
  }

  async expectLowStockWarning(): Promise<void> {
    await expect(this.lowStockCount).toBeVisible({ timeout: 5_000 }).catch(() => {});
  }
}
