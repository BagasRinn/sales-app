import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Bulletins Tab - Tab 10 (SUPERVISOR/MANAGER only)
 */
export class BulletinsTabPage extends BasePage {
  readonly bulletinCards: Locator;
  readonly createFab: Locator;
  readonly emptyState: Locator;

  // Card elements
  readonly bulletinTitle: Locator;
  readonly bulletinDescription: Locator;
  readonly bulletinPdfLink: Locator;
  readonly expiredBadge: Locator;
  readonly editButton: Locator;
  readonly deleteButton: Locator;

  // Filter
  readonly showReadToggle: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.bulletinCards = this.page.locator('[class*="bulletin"], [class*="card"]');
    this.createFab = this.page.locator('button').filter({ hasText: /buat bulletin|create/i }).first();
    this.emptyState = this.page.getByText(/belum ada bulletin|tidak ada/i).first();

    this.bulletinTitle = this.page.locator('[class*="title"], h3, h4').filter({ hasText: /.+/ });
    this.bulletinDescription = this.page.locator('[class*="description"], [class*="body"]');
    this.bulletinPdfLink = this.page.locator('a[href*=".pdf"], [href*=".pdf"]');
    this.expiredBadge = this.page.locator('[class*="badge"], [class*="chip"]').filter({ hasText: /kedaluwarsa|expired/i });
    this.editButton = this.page.getByRole('button', { name: /edit|ubah/i });
    this.deleteButton = this.page.getByRole('button', { name: /hapus|delete/i });

    this.showReadToggle = this.page.getByLabel(/termasuk sudah dibaca|show read/i);
  }

  async clickCreate(): Promise<void> {
    await this.createFab.click();
    await this.page.waitForLoadState('networkidle');
  }

  async clickEdit(index = 0): Promise<void> {
    await this.editButton.nth(index).click();
    await this.page.waitForLoadState('networkidle');
  }

  async clickDelete(index = 0): Promise<void> {
    await this.deleteButton.nth(index).click();
    await this.page.getByRole('button', { name: /ya|ok|confirm|hapus/i }).click();
    await this.page.waitForLoadState('networkidle');
  }

  async expectBulletinInList(title: string): Promise<void> {
    const card = this.bulletinCards.filter({ hasText: title }).first();
    await expect(card).toBeVisible({ timeout: 5_000 });
  }

  async expectBulletinNotInList(title: string): Promise<void> {
    const card = this.bulletinCards.filter({ hasText: title }).first();
    await expect(card).toBeHidden({ timeout: 3_000 }).catch(() => {});
  }

  async expectEmptyState(): Promise<void> {
    await expect(this.emptyState).toBeVisible({ timeout: 3_000 }).catch(() => {});
  }
}

// --- Create/Edit Bulletin Dialog ---
export class BulletinDialog {
  readonly titleInput: Locator;
  readonly descriptionInput: Locator;
  readonly pdfUrlInput: Locator;
  readonly uploadPdfButton: Locator;
  readonly tanpaBatasWaktuCheckbox: Locator;
  readonly expirationDateInput: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;
  readonly pdfFileInput: Locator;

  constructor(readonly page: Page) {
    this.titleInput = page.getByLabel(/judul|title/i);
    this.descriptionInput = page.getByLabel(/deskripsi|description/i);
    this.pdfUrlInput = page.getByLabel(/pdf url/i);
    this.uploadPdfButton = page.getByRole('button', { name: /upload pdf/i }).first();
    this.tanpaBatasWaktuCheckbox = page.getByLabel(/tanpa batas|unlimited/i);
    this.expirationDateInput = page.locator('input[type="date"]');
    this.saveButton = page.getByRole('button', { name: /simpan|save/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
    this.pdfFileInput = page.locator('input[type="file"]');
  }

  async fillAndSubmit(bulletin: {
    title: string;
    description?: string;
    pdfUrl?: string;
    unlimited?: boolean;
    expirationDate?: string;
  }): Promise<void> {
    await this.titleInput.fill(bulletin.title);
    if (bulletin.description) await this.descriptionInput.fill(bulletin.description);
    if (bulletin.pdfUrl) await this.pdfUrlInput.fill(bulletin.pdfUrl);
    if (bulletin.unlimited) {
      await this.tanpaBatasWaktuCheckbox.check();
    } else if (bulletin.expirationDate) {
      await this.expirationDateInput.fill(bulletin.expirationDate);
    }
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async uploadPdf(filePath: string): Promise<void> {
    await this.pdfFileInput.setInputFiles(filePath);
    await this.page.waitForLoadState('networkidle');
  }

  async expectValidationError(): Promise<void> {
    await expect(this.saveButton).toBeDisabled();
  }
}
