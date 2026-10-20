import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Penugasan Sales Tab - Tab 9 (SUPERVISOR/MANAGER only)
 * Three sub-views: Per Area, Per Customer, Per Sales
 */
export class PenugasanSalesTabPage extends BasePage {
  // Sub-view toggle
  readonly perAreaButton: Locator;
  readonly perCustomerButton: Locator;
  readonly perSalesButton: Locator;

  // Per Area
  readonly areaList: Locator;
  readonly kelolaButtons: Locator;

  // Per Customer
  readonly customerSearchInput: Locator;
  readonly customerRows: Locator;
  readonly overrideButtons: Locator;

  // Per Sales
  readonly salesRows: Locator;
  readonly lihatTokoButtons: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.perAreaButton = page.getByRole('button', { name: /per area/i }).first();
    this.perCustomerButton = page.getByRole('button', { name: /per customer|toko/i }).first();
    this.perSalesButton = page.getByRole('button', { name: /per sales/i }).first();

    this.areaList = page.locator('[class*="area"]');
    this.kelolaButtons = page.getByRole('button', { name: /kelola/i });

    this.customerSearchInput = page.getByPlaceholder(/cari|search/i);
    this.customerRows = page.locator('tbody tr, [class*="customer"]');
    this.overrideButtons = page.getByRole('button', { name: /override/i });

    this.salesRows = page.locator('tbody tr, [class*="sales"]');
    this.lihatTokoButtons = page.getByRole('button', { name: /lihat toko/i });
  }

  async switchToPerArea(): Promise<void> {
    await this.perAreaButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async switchToPerCustomer(): Promise<void> {
    await this.perCustomerButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async switchToPerSales(): Promise<void> {
    await this.perSalesButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async clickKelola(index = 0): Promise<void> {
    await this.kelolaButtons.nth(index).click();
    await this.page.waitForLoadState('networkidle');
  }

  async clickOverride(index = 0): Promise<void> {
    await this.overrideButtons.nth(index).click();
    await this.page.waitForLoadState('networkidle');
  }

  async clickLihatToko(index = 0): Promise<void> {
    await this.lihatTokoButtons.nth(index).click();
    await this.page.waitForLoadState('networkidle');
  }

  async expectAreaInList(kodeArea: string): Promise<void> {
    const area = this.areaList.filter({ hasText: kodeArea }).first();
    await expect(area).toBeVisible({ timeout: 5_000 });
  }

  async searchCustomer(query: string): Promise<void> {
    await this.customerSearchInput.fill(query);
    await this.page.waitForLoadState('networkidle');
  }

  async expectSalesAssignmentDialogOpen(): Promise<void> {
    await expect(this.page.locator('[role="dialog"], [class*="dialog"]').last()).toBeVisible({ timeout: 5_000 });
  }
}

// --- Multi-Select Sales Dialog ---
export class MultiSelectSalesDialog {
  readonly salesCheckboxes: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;
  readonly emptySelectionInfo: Locator;

  constructor(readonly page: Page) {
    this.salesCheckboxes = page.locator('input[type="checkbox"], [role="checkbox"]');
    this.saveButton = page.getByRole('button', { name: /simpan|save|kelola/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
    this.emptySelectionInfo = page.getByText(/tidak ada|belum di-assign/i).first();
  }

  async selectSales(indexes: number[]): Promise<void> {
    for (const idx of indexes) {
      await this.salesCheckboxes.nth(idx).check();
    }
  }

  async deselectAll(): Promise<void> {
    const checked = this.page.locator('input[type="checkbox"]:checked');
    const count = await checked.count();
    for (let i = 0; i < count; i++) {
      await checked.first().uncheck();
    }
  }

  async save(): Promise<void> {
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async cancel(): Promise<void> {
    await this.cancelButton.click();
  }
}
