import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Orders Tab - Tab 1
 * Sub-tabs: Menunggu Persetujuan, Semua Pesanan
 */
export class OrdersTabPage extends BasePage {
  // Sub-tabs
  readonly pendingTab: Locator;
  readonly allOrdersTab: Locator;

  // Filters
  readonly statusDropdown: Locator;
  readonly searchInput: Locator;
  readonly dateFilterChips: Locator;

  // Order cards
  readonly orderCards: Locator;
  readonly expandButtons: Locator;

  // Action buttons (ADMIN only on pending orders)
  readonly approveButton: Locator;
  readonly rejectButton: Locator;
  readonly cancelItemButton: Locator;
  readonly editDiskonButton: Locator;
  readonly editUpPriceButton: Locator;

  // Status chips
  readonly pendingChip: Locator;
  readonly approvedChip: Locator;
  readonly rejectedChip: Locator;
  readonly cancelledChip: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.pendingTab = page.getByRole('button', { name: /menunggu persetujuan/i });
    this.allOrdersTab = page.getByRole('button', { name: /semua pesanan/i });
    this.statusDropdown = page.locator('select, [role="combobox"]').first();
    this.searchInput = page.getByPlaceholder(/cari|search/i);
    this.dateFilterChips = page.locator('[class*="chip"], button').filter({ hasText: /all|today|week|month/i });
    this.orderCards = page.locator('[class*="card"], [class*="order"]').filter({ hasText: /\d{6,}/ });
    this.expandButtons = page.getByRole('button', { name: /detail|expand|buka/i });

    this.approveButton = page.getByRole('button', { name: /setujui|approve/i });
    this.rejectButton = page.getByRole('button', { name: /tolak|reject/i });
    this.cancelItemButton = page.getByRole('button', { name: /batalkan item/i });
    this.editDiskonButton = page.getByRole('button', { name: /edit diskon/i });
    this.editUpPriceButton = page.getByRole('button', { name: /edit up.?price/i });

    this.pendingChip = page.locator('[class*="chip"], span').filter({ hasText: /pending|menunggu/i }).first();
    this.approvedChip = page.locator('[class*="chip"], span').filter({ hasText: /approved|disetujui/i }).first();
    this.rejectedChip = page.locator('[class*="chip"], span').filter({ hasText: /rejected|ditolak/i }).first();
    this.cancelledChip = page.locator('[class*="chip"], span').filter({ hasText: /cancelled|dibatalkan/i }).first();
  }

  async switchToPendingTab(): Promise<void> {
    await this.pendingTab.click();
    await this.waitForLoadState('networkidle');
  }

  async switchToAllOrdersTab(): Promise<void> {
    await this.allOrdersTab.click();
    await this.waitForLoadState('networkidle');
  }

  async expandOrder(index = 0): Promise<void> {
    await this.orderCards.nth(index).locator('..').getByRole('button').first().click().catch(
      async () => await this.orderCards.nth(index).click()
    );
    await this.waitForLoadState('networkidle');
  }

  async approveOrder(index = 0): Promise<void> {
    await this.expandOrder(index);
    await this.approveButton.click();
    // Confirm dialog
    await this.page.getByRole('button', { name: /ya|confirm|ok/i }).click();
    await this.waitForLoadState('networkidle');
  }

  async rejectOrder(index = 0, reason?: string): Promise<void> {
    await this.expandOrder(index);
    await this.rejectButton.click();
    if (reason) {
      await this.page.locator('textarea, input[type="text"]').last().fill(reason);
    }
    await this.page.getByRole('button', { name: /ya|confirm|ok|tolak/i }).last().click();
    await this.waitForLoadState('networkidle');
  }

  async expectOrderStatus(status: 'pending' | 'approved' | 'rejected' | 'cancelled'): Promise<void> {
    const chipMap = {
      pending: this.pendingChip,
      approved: this.approvedChip,
      rejected: this.rejectedChip,
      cancelled: this.cancelledChip,
    };
    await expect(chipMap[status]).toBeVisible();
  }

  async filterByStatus(status: string): Promise<void> {
    await this.statusDropdown.selectOption(status);
    await this.waitForLoadState('networkidle');
  }

  async searchOrders(query: string): Promise<void> {
    await this.searchInput.fill(query);
    await this.waitForLoadState('networkidle');
  }

  async expectOrderInList(orderIdOrStore: string): Promise<void> {
    const order = this.page.locator('[class*="card"], [class*="order"]').filter({ hasText: orderIdOrStore }).first();
    await expect(order).toBeVisible({ timeout: 5_000 });
  }
}
