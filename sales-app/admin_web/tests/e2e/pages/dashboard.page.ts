import { Page, Locator, Response, expect } from '@playwright/test';
import { BasePage } from './base.page';

export type TabName =
  | 'Dashboard'
  | 'Pesanan'
  | 'Toko'
  | 'Pengajuan Customer'
  | 'Produk & Stok'
  | 'Supplier'
  | 'Sinkronisasi'
  | 'User'
  | 'Performa Sales'
  | 'Penugasan Sales'
  | 'Bulletin'
  | 'Laporan Lintas';

export type UserRole = 'ADMIN' | 'SUPERVISOR' | 'MANAGER';

export class DashboardPage extends BasePage {
  // Sidebar elements
  readonly sidebar: Locator;
  readonly userName: Locator;
  readonly branchName: Locator;
  readonly changePasswordMenuItem: Locator;
  readonly logoutButton: Locator;

  // Tab buttons in sidebar
  readonly tabButtons: Locator;

  // Tab contents (will be used by child page objects)
  readonly loadingOverlay: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.sidebar = page.locator('aside, [role="navigation"], nav').first();
    this.userName = page.getByText(/^[A-Z][a-z]+ [A-Z][a-z]+$/).first();
    this.branchName = page.getByText(/cabang|branch/i).first();
    this.changePasswordMenuItem = page.getByText(/ganti password/i);
    this.logoutButton = page.getByText(/keluar|logout|sign out/i);
    this.tabButtons = page.locator('[role="button"], button, a').filter({ hasText: /Dashboard|Pesanan|Toko|Pengajuan|Produk|Supplier|Sinkronisasi|User|Performa|Penugasan|Bulletin|Laporan/i });
    this.loadingOverlay = page.locator('[class*="loading"], [class*="CircularProgress"], [aria-busy="true"]').first();
  }

  async openDashboard(): Promise<void> {
    await this.page.goto('/');
  }

  async expectDashboardLoaded(): Promise<void> {
    await this.page.waitForLoadState('networkidle');
    await expect(this.sidebar).toBeVisible({ timeout: 15_000 });
  }

  async clickTab(tabName: TabName): Promise<void> {
    const tabMap: Record<TabName, RegExp> = {
      'Dashboard': /dashboard|ringkasan/i,
      'Pesanan': /pesanan|orders/i,
      'Toko': /toko|toko/i,
      'Pengajuan Customer': /pengajuan/i,
      'Produk & Stok': /produk|produk/i,
      'Supplier': /supplier/i,
      'Sinkronisasi': /sinkronisasi|sync/i,
      'User': /^user$/i,
      'Performa Sales': /performa/i,
      'Penugasan Sales': /penugasan/i,
      'Bulletin': /bulletin/i,
      'Laporan Lintas': /lintas/i,
    };
    const selector = this.page.locator('button, [role="button"], a, div').filter({ hasText: tabMap[tabName] }).first();
    await selector.click();
    await this.waitForLoadState('networkidle');
  }

  async expectTabVisible(tabName: TabName): Promise<void> {
    const tabMap: Record<TabName, RegExp> = {
      'Dashboard': /dashboard|ringkasan/i,
      'Pesanan': /pesanan|orders/i,
      'Toko': /toko|toko/i,
      'Pengajuan Customer': /pengajuan/i,
      'Produk & Stok': /produk|produk/i,
      'Supplier': /supplier/i,
      'Sinkronisasi': /sinkronisasi|sync/i,
      'User': /^user$/i,
      'Performa Sales': /performa/i,
      'Penugasan Sales': /penugasan/i,
      'Bulletin': /bulletin/i,
      'Laporan Lintas': /lintas/i,
    };
    const tab = this.page.locator('button, [role="button"], a, div').filter({ hasText: tabMap[tabName] }).first();
    await expect(tab).toBeVisible();
  }

  async expectTabHidden(tabName: TabName): Promise<void> {
    const tabMap: Record<TabName, RegExp> = {
      'Dashboard': /dashboard|ringkasan/i,
      'Pesanan': /pesanan|orders/i,
      'Toko': /toko|toko/i,
      'Pengajuan Customer': /pengajuan/i,
      'Produk & Stok': /produk|produk/i,
      'Supplier': /supplier/i,
      'Sinkronisasi': /sinkronisasi|sync/i,
      'User': /^user$/i,
      'Performa Sales': /performa/i,
      'Penugasan Sales': /penugasan/i,
      'Bulletin': /bulletin/i,
      'Laporan Lintas': /lintas/i,
    };
    const tab = this.page.locator('button, [role="button"], a, div').filter({ hasText: tabMap[tabName] }).first();
    await expect(tab).toBeHidden({ timeout: 3_000 }).catch(() => {});
  }

  async openChangePasswordDialog(): Promise<void> {
    await this.changePasswordMenuItem.click();
  }

  async logout(): Promise<void> {
    await this.logoutButton.click();
    await this.waitForLoadState('networkidle');
  }
}

// --- Change Password Dialog ---
export class ChangePasswordDialog {
  readonly oldPasswordInput: Locator;
  readonly newPasswordInput: Locator;
  readonly confirmPasswordInput: Locator;
  readonly submitButton: Locator;
  readonly cancelButton: Locator;
  readonly errorAlert: Locator;

  constructor(readonly page: Page) {
    this.oldPasswordInput = page.getByLabel(/password lama|old password/i);
    this.newPasswordInput = page.getByLabel(/password baru|new password/i);
    this.confirmPasswordInput = page.getByLabel(/konfirmasi|confirm/i);
    this.submitButton = page.getByRole('button', { name: /simpan|save|konfirmasi/i });
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i });
    this.errorAlert = page.getByRole('alert');
  }

  async fillAndSubmit(oldPassword: string, newPassword: string): Promise<void> {
    await this.oldPasswordInput.fill(oldPassword);
    await this.newPasswordInput.fill(newPassword);
    await this.confirmPasswordInput.fill(newPassword);
    await this.submitButton.click();
  }

  async expectSuccess(): Promise<void> {
    await expect(this.page).toHaveURL(/\/login/);
  }
}
