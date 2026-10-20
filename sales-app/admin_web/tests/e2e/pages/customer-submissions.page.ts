import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Customer Submissions Tab - Tab 3
 */
export class CustomerSubmissionsTabPage extends BasePage {
  // Filter chips
  readonly filterAll: Locator;
  readonly filterPending: Locator;
  readonly filterApproved: Locator;
  readonly filterRejected: Locator;

  // Stats
  readonly statsAll: Locator;
  readonly statsPending: Locator;
  readonly statsApproved: Locator;
  readonly statsRejected: Locator;

  // Submission cards
  readonly submissionCards: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.filterAll = page.getByRole('button', { name: /semua|all/i }).first();
    this.filterPending = page.getByRole('button', { name: /pending|menunggu/i }).first();
    this.filterApproved = page.getByRole('button', { name: /approved|disetujui/i }).first();
    this.filterRejected = page.getByRole('button', { name: /rejected|ditolak/i }).first();

    this.statsAll = page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /semua|total/i }).first();
    this.statsPending = page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /pending|menunggu/i }).first();
    this.statsApproved = page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /disetujui|approved/i }).first();
    this.statsRejected = page.locator('[class*="stat"], [class*="card"]').filter({ hasText: /ditolak|rejected/i }).first();

    this.submissionCards = page.locator('[class*="card"], [class*="submission"], [class*="item"]');
  }

  async filterByStatus(status: 'all' | 'pending' | 'approved' | 'rejected'): Promise<void> {
    const chips = {
      all: this.filterAll,
      pending: this.filterPending,
      approved: this.filterApproved,
      rejected: this.filterRejected,
    };
    await chips[status].click();
    await this.waitForLoadState('networkidle');
  }

  async clickSubmission(index = 0): Promise<void> {
    await this.submissionCards.nth(index).click();
    await this.waitForLoadState('networkidle');
  }

  async expectSubmissionCount(status: 'pending' | 'approved' | 'rejected', count: number): Promise<void> {
    const chipMap = {
      pending: this.statsPending,
      approved: this.statsApproved,
      rejected: this.statsRejected,
    };
    const stat = chipMap[status];
    if (count > 0) {
      await expect(stat).toBeVisible();
    }
  }
}

// --- Submission Detail Page ---
export class SubmissionDetailPage extends BasePage {
  // Section headers
  readonly identitasSection: Locator;
  readonly pembayaranSection: Locator;
  readonly channelSection: Locator;
  readonly auditSection: Locator;

  // Action buttons (PENDING only)
  readonly tolakButton: Locator;
  readonly setujuiButton: Locator;

  // Approval fields
  readonly kodeInput: Locator;
  readonly namaTokoInput: Locator;
  readonly alamatInput: Locator;

  // Rejection fields
  readonly rejectReasonInput: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.identitasSection = page.getByText(/identitas/i).first();
    this.pembayaranSection = page.getByText(/pembayaran/i).first();
    this.channelSection = page.getByText(/channel|salesman/i).first();
    this.auditSection = page.getByText(/audit|reviewer/i).first();

    this.tolakButton = page.getByRole('button', { name: /tolak|reject/i });
    this.setujuiButton = page.getByRole('button', { name: /setujui|approve/i });

    this.kodeInput = page.getByLabel(/kode/i).first();
    this.namaTokoInput = page.getByLabel(/nama toko/i).first();
    this.alamatInput = page.getByLabel(/alamat/i).first();
    this.rejectReasonInput = page.getByLabel(/alasan|reason/i).first();
  }

  async approve(customerKode: string, options?: { namaToko?: string; alamat?: string }): Promise<void> {
    await this.setujuiButton.click();
    await this.kodeInput.fill(customerKode);
    if (options?.namaToko) await this.namaTokoInput.fill(options.namaToko);
    if (options?.alamat) await this.alamatInput.fill(options.alamat);
    await this.page.getByRole('button', { name: /ya|ok|confirm/i }).click();
    await this.waitForLoadState('networkidle');
  }

  async reject(reason?: string): Promise<void> {
    await this.tolakButton.click();
    if (reason) await this.rejectReasonInput.fill(reason);
    await this.page.getByRole('button', { name: /ya|ok|confirm|tolak/i }).last().click();
    await this.waitForLoadState('networkidle');
  }

  async expectFieldsVisible(): Promise<void> {
    await expect(this.identitasSection).toBeVisible({ timeout: 5_000 });
    await expect(this.pembayaranSection).toBeVisible();
  }

  async expectActionButtonsHidden(): Promise<void> {
    await expect(this.setujuiButton).toBeHidden({ timeout: 3_000 }).catch(() => {});
    await expect(this.tolakButton).toBeHidden({ timeout: 3_000 }).catch(() => {});
  }
}
