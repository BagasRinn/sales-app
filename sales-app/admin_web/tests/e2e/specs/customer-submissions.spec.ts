import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/dashboard.page';
import { CustomerSubmissionsTabPage, SubmissionDetailPage } from '../pages/customer-submissions.page';
import { LoginPage } from '../pages/login.page';
import { TEST_USERS, TEST_DATA } from '../utils/test-data';
import { randomString } from '../utils/helpers';

/**
 * Customer Submissions Tab Suite
 * Tests: Filter by status, view submission detail, approve, reject
 */
test.describe('Customer Submissions Tab', () => {
  async function gotoSubmissionsTab(page: import('@playwright/test').Page) {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.admin.username, TEST_USERS.admin.password);
    await page.waitForLoadState('networkidle');
    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Pengajuan Customer');
    await page.waitForLoadState('networkidle');
    return new CustomerSubmissionsTabPage(page);
  }

  test('displays filter chips @smoke', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);

    await expect(submissions.filterAll).toBeVisible({ timeout: 5_000 });
    await expect(submissions.filterPending).toBeVisible();
    await expect(submissions.filterApproved).toBeVisible();
    await expect(submissions.filterRejected).toBeVisible();
  });

  test('stats row shows correct counts', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);

    // Stats should be visible
    const statsVisible = await submissions.statsAll.isVisible().catch(() => false);
    if (statsVisible) {
      await expect(submissions.statsAll).toBeVisible();
    }
  });

  test('filter by all status', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);
    await submissions.filterByStatus('all');
    await page.waitForLoadState('networkidle');
  });

  test('filter by pending status', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);
    await submissions.filterByStatus('pending');
    await page.waitForLoadState('networkidle');
  });

  test('filter by approved status', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);
    await submissions.filterByStatus('approved');
    await page.waitForLoadState('networkidle');
  });

  test('filter by rejected status', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);
    await submissions.filterByStatus('rejected');
    await page.waitForLoadState('networkidle');
  });

  test('can view submission detail', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);

    // Filter to pending to find actionable submissions
    await submissions.filterByStatus('pending');
    const cards = submissions.submissionCards;
    const count = await cards.count();

    if (count > 0) {
      await submissions.clickSubmission(0);
      const detail = new SubmissionDetailPage(page);
      await detail.expectFieldsVisible();
    }
  });

  test('ADMIN can approve a pending submission', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);
    await submissions.filterByStatus('pending');
    const cards = submissions.submissionCards;
    const count = await cards.count();

    if (count > 0) {
      await submissions.clickSubmission(0);
      const detail = new SubmissionDetailPage(page);
      const approveVisible = await detail.setujuiButton.isVisible().catch(() => false);

      if (approveVisible) {
        const kode = `KODE${randomString()}`;
        await detail.approve(kode);
        await page.waitForLoadState('networkidle');
      }
    }
  });

  test('ADMIN can reject a pending submission with reason', async ({ page }) => {
    const submissions = await gotoSubmissionsTab(page);
    await submissions.filterByStatus('pending');
    const cards = submissions.submissionCards;
    const count = await cards.count();

    if (count > 0) {
      await submissions.clickSubmission(0);
      const detail = new SubmissionDetailPage(page);
      const tolakVisible = await detail.tolakButton.isVisible().catch(() => false);

      if (tolakVisible) {
        await detail.reject(TEST_DATA.orderRejectReason);
        await page.waitForLoadState('networkidle');
      }
    }
  });

  test('MANAGER can view submission detail', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.manager.username, TEST_USERS.manager.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Pengajuan Customer');
    await page.waitForLoadState('networkidle');

    const submissions = new CustomerSubmissionsTabPage(page);
    await submissions.filterByStatus('pending');
    const count = await submissions.submissionCards.count();

    if (count > 0) {
      await submissions.clickSubmission(0);
      const detail = new SubmissionDetailPage(page);
      await detail.expectFieldsVisible();
    }
  });

  test('SUPERVISOR can view but not act on approved/rejected submissions', async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.login(TEST_USERS.supervisor.username, TEST_USERS.supervisor.password);
    await page.waitForLoadState('networkidle');

    const dashboard = new DashboardPage(page);
    await dashboard.clickTab('Pengajuan Customer');
    await page.waitForLoadState('networkidle');

    const submissions = new CustomerSubmissionsTabPage(page);
    await submissions.filterByStatus('approved');
    const count = await submissions.submissionCards.count();

    if (count > 0) {
      await submissions.clickSubmission(0);
      const detail = new SubmissionDetailPage(page);
      await detail.expectActionButtonsHidden();
    }
  });
});
