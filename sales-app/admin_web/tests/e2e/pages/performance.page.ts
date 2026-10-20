import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Performa Sales Tab - Tab 8 (SUPERVISOR/MANAGER only)
 * Three sections: KPI per Supplier, Leaderboard, Target & Incentive
 */
export class PerformanceTabPage extends BasePage {
  // Section tabs
  readonly kpiSupplierTab: Locator;
  readonly leaderboardTab: Locator;
  readonly targetIncentiveTab: Locator;

  // KPI per Supplier
  readonly supplierTable: Locator;
  readonly targetEditInputs: Locator;
  readonly targetSaveButton: Locator;

  // Leaderboard
  readonly revenueSortButton: Locator;
  readonly orderCountSortButton: Locator;
  readonly leaderboardRows: Locator;

  // Target & Incentive
  readonly targetTable: Locator;
  readonly periodPicker: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.kpiSupplierTab = page.getByRole('button', { name: /kpi supplier/i }).first();
    this.leaderboardTab = page.getByRole('button', { name: /leaderboard/i }).first();
    this.targetIncentiveTab = page.getByRole('button', { name: /target.*incentive|insentif/i }).first();

    this.supplierTable = page.locator('table').filter({ hasText: /supplier|target|nilai/i }).first();
    this.targetEditInputs = page.getByLabel(/target/i);
    this.targetSaveButton = page.getByRole('button', { name: /simpan|save/i });

    this.revenueSortButton = page.getByRole('button', { name: /revenue/i }).first();
    this.orderCountSortButton = page.getByRole('button', { name: /jumlah pesanan/i }).first();
    this.leaderboardRows = page.locator('[class*="leaderboard"], tbody tr');

    this.targetTable = page.locator('table').filter({ hasText: /sales|target/i }).first();
    this.periodPicker = page.locator('input[type="month"], input[type="date"]').first();
  }

  async switchToKpiSupplier(): Promise<void> {
    await this.kpiSupplierTab.click();
    await this.page.waitForLoadState('networkidle');
  }

  async switchToLeaderboard(): Promise<void> {
    await this.leaderboardTab.click();
    await this.page.waitForLoadState('networkidle');
  }

  async switchToTargetIncentive(): Promise<void> {
    await this.targetIncentiveTab.click();
    await this.page.waitForLoadState('networkidle');
  }

  async expectSupplierInList(supplierName: string): Promise<void> {
    const row = this.supplierTable.locator('tr').filter({ hasText: supplierName }).first();
    await expect(row).toBeVisible({ timeout: 5_000 });
  }

  async expectLeaderboardRanked(): Promise<void> {
    await expect(this.leaderboardRows.first()).toBeVisible({ timeout: 5_000 });
  }

  async sortByRevenue(): Promise<void> {
    await this.revenueSortButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async sortByOrderCount(): Promise<void> {
    await this.orderCountSortButton.click();
    await this.page.waitForLoadState('networkidle');
  }
}
