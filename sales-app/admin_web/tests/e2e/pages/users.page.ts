import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Users Tab - Tab 7 (SUPERVISOR/MANAGER only)
 */
export class UsersTabPage extends BasePage {
  readonly searchInput: Locator;
  readonly filterChips: Locator;
  readonly tambahButton: Locator;
  readonly userRows: Locator;

  // Role filter chips
  readonly filterSemua: Locator;
  readonly filterAdmin: Locator;
  readonly filterSupervisor: Locator;
  readonly filterManager: Locator;
  readonly filterSales: Locator;

  // Role badges
  readonly adminBadge: Locator;
  readonly supervisorBadge: Locator;
  readonly managerBadge: Locator;
  readonly salesBadge: Locator;

  constructor(readonly page: Page) {
    super(page);
    this.searchInput = page.getByPlaceholder(/cari|search/i);
    this.filterChips = page.locator('[class*="chip"], button').filter({ hasText: /admin|supervisor|manager|sales/i });
    this.tambahButton = page.getByRole('button', { name: /tambah|new user/i }).first();
    this.userRows = page.locator('tbody tr, [class*="user"], [class*="item"]');

    this.filterSemua = page.getByRole('button', { name: /semua/i }).first();
    this.filterAdmin = page.getByRole('button', { name: /admin/i }).first();
    this.filterSupervisor = page.getByRole('button', { name: /supervisor/i }).first();
    this.filterManager = page.getByRole('button', { name: /manager/i }).first();
    this.filterSales = page.getByRole('button', { name: /sales/i }).first();

    this.adminBadge = page.locator('[class*="badge"], [class*="chip"]').filter({ hasText: /admin/i }).first();
    this.supervisorBadge = page.locator('[class*="badge"], [class*="chip"]').filter({ hasText: /supervisor/i }).first();
    this.managerBadge = page.locator('[class*="badge"], [class*="chip"]').filter({ hasText: /manager/i }).first();
    this.salesBadge = page.locator('[class*="badge"], [class*="chip"]').filter({ hasText: /sales/i }).first();
  }

  async search(query: string): Promise<void> {
    await this.searchInput.fill(query);
    await this.page.waitForLoadState('networkidle');
  }

  async filterByRole(role: 'semua' | 'admin' | 'supervisor' | 'manager' | 'sales'): Promise<void> {
    const chips = {
      semua: this.filterSemua,
      admin: this.filterAdmin,
      supervisor: this.filterSupervisor,
      manager: this.filterManager,
      sales: this.filterSales,
    };
    await chips[role].click();
    await this.page.waitForLoadState('networkidle');
  }

  async clickTambah(): Promise<void> {
    await this.tambahButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async expectUserInList(username: string): Promise<void> {
    const row = this.userRows.filter({ hasText: username }).first();
    await expect(row).toBeVisible({ timeout: 5_000 });
  }

  async expectRoleBadge(role: 'ADMIN' | 'SUPERVISOR' | 'MANAGER' | 'SALES'): Promise<void> {
    const badgeMap = {
      ADMIN: this.adminBadge,
      SUPERVISOR: this.supervisorBadge,
      MANAGER: this.managerBadge,
      SALES: this.salesBadge,
    };
    await expect(badgeMap[role]).toBeVisible();
  }
}

// --- Create/Edit User Dialog ---
export class UserDialog {
  readonly usernameInput: Locator;
  readonly passwordInput: Locator;
  readonly namaInput: Locator;
  readonly roleDropdown: Locator;
  readonly branchDropdown: Locator;
  readonly isActiveToggle: Locator;
  readonly saveButton: Locator;
  readonly cancelButton: Locator;

  constructor(readonly page: Page) {
    this.usernameInput = page.getByLabel(/username/i);
    this.passwordInput = page.getByLabel(/password/i);
    this.namaInput = page.getByLabel(/nama/i);
    this.roleDropdown = page.locator('select, [role="combobox"]').filter({ hasText: /role/i }).first();
    this.branchDropdown = page.locator('select, [role="combobox"]').filter({ hasText: /cabang|branch/i }).first();
    this.isActiveToggle = page.locator('[class*="switch"], [role="switch"], input[type="checkbox"]');
    this.saveButton = page.getByRole('button', { name: /simpan|save/i }).first();
    this.cancelButton = page.getByRole('button', { name: /batal|cancel/i }).first();
  }

  async fillAndSubmit(user: {
    username: string;
    password?: string;
    nama?: string;
    role: 'ADMIN' | 'SUPERVISOR' | 'MANAGER' | 'SALES';
    branch?: string;
    isActive?: boolean;
  }): Promise<void> {
    if (user.username) await this.usernameInput.fill(user.username);
    if (user.password) await this.passwordInput.fill(user.password);
    if (user.nama) await this.namaInput.fill(user.nama);
    await this.roleDropdown.selectOption(user.role);
    if (user.branch) await this.branchDropdown.selectOption(user.branch);
    if (user.isActive !== undefined) {
      if (user.isActive) await this.isActiveToggle.check();
      else await this.isActiveToggle.uncheck();
    }
    await this.saveButton.click();
    await this.page.waitForLoadState('networkidle');
  }

  async expectValidationError(): Promise<void> {
    await expect(this.saveButton).toBeDisabled();
  }
}
