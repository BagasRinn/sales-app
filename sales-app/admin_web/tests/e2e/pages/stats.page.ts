import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Dashboard Stats Tab - Tab 0
 * Contains: Ringkasan Sistem, Performa Sales, Ambil Laporan, Pesanan Perlu Tindakan
 */
export class StatsTabPage extends BasePage {
  // Ringkasan Sistem stat cards
  readonly totalPesananCard: Locator;
  readonly menungguPersetujuanCard: Locator;
  readonly disetujuiCard: Locator;
  readonly ditolakCard: Locator;
  readonly dibatalkanCard: Locator;
  readonly totalProdukCard: Locator;
  readonly totalTokoCard: Locator;
  readonly produkPerluTinjauCard: Locator;

  // Ambil Laporan section
  readonly laporanHarianSection: Locator;
  readonly laporanPeriodeSection: Locator;
  readonly downloadHarianButton: Locator;
  readonly downloadPeriodeButton: Locator;

  // Performa Sales (SUPERVISOR/MANAGER)
  readonly performaSalesSection: Locator;

  // Pesanan Perlu Tindakan (ADMIN only)
  readonly pesananPerluTindakanSection: Locator;
  readonly approveBadge: Locator;

  constructor(readonly page: Page) {
    super(page);
    // Stat cards - using text patterns
    this.totalPesananCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /total pesanan/i }).first();
    this.menungguPersetujuanCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /menunggu persetujuan/i }).first();
    this.disetujuiCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /disetujui/i }).first();
    this.ditolakCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /ditolak/i }).first();
    this.dibatalkanCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /dibatalkan/i }).first();
    this.totalProdukCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /total produk/i }).first();
    this.totalTokoCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /total toko/i }).first();
    this.produkPerluTinjauCard = page.locator('[class*="card"], [class*="stat"]').filter({ hasText: /perlu tinjau/i }).first();

    this.laporanHarianSection = page.getByText(/laporan harian/i).first();
    this.laporanPeriodeSection = page.getByText(/laporan periode/i).first();
    this.downloadHarianButton = page.getByRole('button', { name: /download harian/i });
    this.downloadPeriodeButton = page.getByRole('button', { name: /download periode/i });
    this.performaSalesSection = page.getByText(/performa sales/i).first();
    this.pesananPerluTindakanSection = page.getByText(/perlu tindakan/i).first();
    this.approveBadge = page.locator('[class*="badge"]').filter({ hasText: /\d+/ });
  }

  async expectStatsCardsVisible(): Promise<void> {
    await expect(this.totalPesananCard).toBeVisible({ timeout: 10_000 });
    await expect(this.menungguPersetujuanCard).toBeVisible();
    await expect(this.disetujuiCard).toBeVisible();
  }

  async expectLaporanSectionVisible(): Promise<void> {
    await expect(this.laporanHarianSection).toBeVisible({ timeout: 5_000 });
  }

  async downloadDailyReport(date: string): Promise<void> {
    // Find date input and fill it
    const dateInput = this.page.locator('input[type="date"], input').filter({ hasText: '' }).first();
    await dateInput.fill(date);
    await this.downloadHarianButton.click();
  }

  async downloadPeriodReport(startDate: string, endDate: string): Promise<void> {
    const inputs = this.page.locator('input[type="date"], input');
    await inputs.nth(0).fill(startDate);
    await inputs.nth(1).fill(endDate);
    await this.downloadPeriodeButton.click();
  }

  async expectPendingOrderCount(count: number): Promise<void> {
    const badge = this.page.locator('[class*="badge"]').filter({ hasText: String(count) }).first();
    if (count > 0) {
      await expect(badge).toBeVisible();
    }
  }
}
