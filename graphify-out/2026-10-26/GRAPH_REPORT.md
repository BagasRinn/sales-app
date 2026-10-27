# Graph Report - Project-magang  (2026-10-26)

## Corpus Check
- 323 files · ~209,055 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 54 file(s) not represented in the graph (top: (none) 17, .xml 7, .ttf 5)

## Summary
- 5678 nodes · 9351 edges · 233 communities (181 shown, 52 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 353 edges (avg confidence: 0.93)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `291758b6`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- AdminProvider State Hub
- Sales App Home Screens
- Admin Stats Tab
- Backend Auth Endpoints
- customers.py
- Admin API Repositories
- Sales Web Order Flow UI
- reports.py
- Admin Orders Tab
- OrderProvider
- Backend Customer Endpoints
- Order Flow Review Step
- Customer Registration Form
- app_feedback.dart
- Sales Web Order Models
- Shared UI Widget Classes
- Draft Order Provider
- Mobile Design System
- Mobile Order Flow
- customer_submission
- widgets/app_shell.dart
- draft_order_provider
- customer_submission
- customer_submission
- dashboard_screen
- order
- uuid
- design_system
- customer_registration_screen
- package:flutter/material.dart
- penugasan_sales_tab
- users_tab
- order
- security.py
- sales-app/lib/presentation/screens/bulletin/bulletin_screen.dart
- web_auth_storage.dart
- List
- storage.py
- products.py
- package:provider/provider.dart
- suppliers_tab_test.dart
- sheets_sync.py
- performance_tab
- reports.py
- responsive
- ../../../core/design_system.dart
- products_tab
- test_reports_detail_param.py
- action_button_row
- product_provider
- Admin Bulletins Tab
- step_pick_customer.dart
- ============================================================
- State
- Sales App Order Repository
- Mobile Order Detail
- @playwright/test
- Data Repositories
- my_submissions_screen
- ApiService
- 4. Per-Screen Responsive Adaptations
- admin_web/lib/core/branch.dart
- bulletin_provider
- Cross-Branch Reports Tab
- Sales Performance Model
- customer_submission_detail_screen
- AuthProvider
- User
- home_stats_provider
- test_reports_summary.py
- Supplier
- package:flutter/material.dart
- DashboardPage
- BasePage
- imported_sales_tab.dart
- test_egress_optimizations.py
- customer_repository
- auth_repository
- supplier_target_edit_dialog
- Supabase Egress Reduction Plan
- AdminProvider
- flutter_window
- ProductProvider
- loading_state.dart
- order_provider
- product_provider
- sync_result
- product
- BasePage
- product
- User
- api_service
- check_bulk_upsert_mixed_supplier.py
- sales-app/lib/data/repositories/customer_repository.dart
- main
- e2e/package.json
- auth_storage
- branch
- branch
- storage.py
- web_auth_storage.dart
- OrdersTabPage
- change_password_dialog
- supplier_target_edit_dialog.dart
- branch_report
- customer
- branch
- utils
- order_repository
- sales_targets
- test_egress_optimizations.py
- config
- 5. Spesifikasi Reusable Widgets (Kode Siap Pakai)
- sales-app/lib/presentation/screens/customers/my_submissions_screen.dart
- customer
- jwt_utils
- flutter_window
- admin_web/lib/core/datetime_utils.dart
- win32_window
- import_sales_excel
- manifest
- config
- sales_web/lib/presentation/screens/customers/my_submissions_screen.dart
- app_card.dart
- responsive_dialog.dart
- supplier_performance
- package:flutter_test/flutter_test.dart
- supplier
- supplier_target
- confirm_dialog.dart
- app_adaptive_table.dart
- railway
- State
- generated_plugin_registrant
- app_responsive.dart
- sales_web/lib/core/branch.dart
- list_sales_customers
- api_exception
- test_products_supplier_filter.py
- config
- sales_web/lib/core/config.dart
- sales_web/lib/data/models/customer.dart
- test_suppliers_create.py
- package:admin_web/core/design_system.dart
- test_sheets
- sales_web/lib/presentation/screens/auth/change_password_dialog.dart
- sales_web/lib/data/repositories/order_repository.dart
- responsive_action_menu.dart
- migrate_supabase.py
- web_download_web.dart
- stat_tile.dart
- responsive_dialog.dart
- CustomerRepository
- sales_web/lib/presentation/screens/auth/login_screen.dart
- DashboardScreen
- test_reports_detail_param.py
- create_access_token
- Cluster 157
- Cluster 158
- test_suppliers_toggle.py
- Cluster 160
- customer_submissions.py
- Cluster 162
- Cluster 163
- screens/change_password_dialog.dart
- build.gradle
- settings.gradle
- CustomerSubmissionCreate
- __init__
- local_day_utc_bounds
- __init__
- CustomersTabPage
- CustomerDetailDialog
- bool get
- BulletinDialog
- Sales Order App
- UsersTabPage
- PenugasanSalesTabPage
- package:flutter/foundation.dart
- CustomerSubmissionsTabPage
- Point
- bool get
- EditProductDialog
- PerformanceTabPage
- SyncTabPage
- test_suppliers_create.py
- SubmissionDetailPage
- UserDialog
- UbahStokDialog
- MultiSelectSalesDialog
- stat_tile.dart
- test_suppliers_toggle.py
- SupplierDialog
- LaunchImage.imageset/README.md
- test_migration_idempotent_preserves_toggle.py
- admin_web/lib/main.dart
- FlutterActivity
- CLAUDE.md
- UbahTipeOrderDialog
- _SalesDetailDialogBody
- action_button_row.dart
- LaunchImage.imageset/README.md
- AuthProvider
- dart:typed_data
- upsert_supplier_target
- _TZFormatter
- sales-app/lib/presentation/screens/auth/login_screen.dart
- VoidCallback
- String? get
- web_download_web.dart
- customer_provider.dart
- design_system_test.dart
- cleanup.py
- _StatsTabState

## God Nodes (most connected - your core abstractions)
1. `============================================================` - 163 edges
2. `AdminProvider` - 102 edges
3. `BaseSchema` - 69 edges
4. `BasePage` - 51 edges
5. `Product` - 49 edges
6. `apply_branch_filter()` - 45 edges
7. `User` - 43 edges
8. `Customer` - 41 edges
9. `_` - 38 edges
10. `DashboardPage` - 37 edges

## Surprising Connections (you probably didn't know these)
- `Task 3.1 — Batched `Product` lookup di `POST /orders`` --references--> `Product`  [INFERRED]
  plans/2026-10-17-reduce-supabase-egress.md → sales-app/backend/app/models/models.py
- `Task 3.2 — Batched `Product` lookup di `PUT /orders/{id}`` --references--> `Product`  [INFERRED]
  plans/2026-10-17-reduce-supabase-egress.md → sales-app/backend/app/models/models.py
- `Task 2.3 — Stop `loadAll()` di `approveOrder/rejectOrder/cancelOrderItem`` --references--> `Order`  [INFERRED]
  plans/2026-10-17-reduce-supabase-egress.md → sales-app/backend/app/models/models.py
- `approve_orders_before_20()` --uses--> `Order`  [INFERRED]
  sales-app/backend/approve_orders_before_20.py → sales-app/backend/app/models/models.py
- `initState` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart

## Import Cycles
- None detected.

## Communities (233 total, 52 thin omitted)

### Community 0 - "AdminProvider State Hub"
Cohesion: 0.01
Nodes (210): _activeTabIndex, adminRepository, AdminState, _allOrders, approveCustomerSubmission, approveOrder, _branchOptions, _branchOptionsLoading (+202 more)

### Community 1 - "Sales App Home Screens"
Cohesion: 0.01
Nodes (162): ============================================================, ----------------------------------------, ----------------------------------------, ----------------------------------------, ============================================================, ============================================================, ----------------------------------------, ---------------------------------------- (+154 more)

### Community 2 - "Admin Stats Tab"
Cohesion: 0.04
Nodes (69): AreaAssignmentListItem, AreaAssignmentsPut, BaseSchema, BranchBase, BranchCreate, BranchResponse, Config, BranchSalesSummary (+61 more)

### Community 3 - "Backend Auth Endpoints"
Cohesion: 0.02
Nodes (111): aggregateDashboardPerformance, _applyFilters, approvedMtdCount, approvedMtdRevenue, approvedTodayCount, approvedTodayRevenue, branch, _branchFilter (+103 more)

### Community 4 - "customers.py"
Cohesion: 0.08
Nodes (27): create_customer(), _customer_to_response(), delete_customer(), _exclude_deleted(), get_customer(), get_customer_count(), import_excel(), _list_assignments() (+19 more)

### Community 5 - "Admin API Repositories"
Cohesion: 0.02
Nodes (87): _applyFilters, _buildAllOrders, _buildDraftOrders, _buildPendingOrders, _buildPriceSummary, _CancelItemDialog, _CancelItemDialogState, _CancelItemResult (+79 more)

### Community 6 - "Sales Web Order Flow UI"
Cohesion: 0.02
Nodes (72): _api, approveCustomerSubmission, approveOrder, cancelOrderItems, changePassword, clearImportErrors, clearTokens, createBulletin (+64 more)

### Community 7 - "reports.py"
Cohesion: 0.05
Nodes (30): _build_period_xlsx(), _build_report(), cross_branch_sales_summary(), cross_branch_stock_summary(), daily_report(), get_supplier_performance(), _layer_cut_value(), period_report() (+22 more)

### Community 8 - "Admin Orders Tab"
Cohesion: 0.02
Nodes (85): _activeLayersSummary, _bsDetailRow, _buildBottomBar, _buildStepContent, _calcPreview, _chip, color, _commit (+77 more)

### Community 9 - "OrderProvider"
Cohesion: 0.03
Nodes (68): build, _maybeShowBulletinPopup, build, didChangeAppLifecycleState, _HomeScreenState, _openOrderFlow, _RecentOrdersSection, _RecentOrderTile (+60 more)

### Community 10 - "Backend Customer Endpoints"
Cohesion: 0.03
Nodes (64): _actionIconBtn, _activeLayersSummary, _AddLineSheet, _AddLineSheetState, _buildDiscount, _calcPreview, _chip, color (+56 more)

### Community 11 - "Order Flow Review Step"
Cohesion: 0.10
Nodes (32): _apply_3_layers(), approve_order(), _book_items(), _build_order_response(), cancel_order(), cancel_order_items(), create_order(), delete_draft_order() (+24 more)

### Community 12 - "Customer Registration Form"
Cohesion: 0.04
Nodes (49): _animation, _BerandaTab, _BerandaTabState, build, color, _controller, createState, currency (+41 more)

### Community 13 - "app_feedback.dart"
Cohesion: 0.14
Nodes (12): AppConfirmDialog, AppSnack, build, cancelLabel, confirmLabel, error, info, isDanger (+4 more)

### Community 14 - "Sales Web Order Models"
Cohesion: 0.03
Nodes (62): addLine, applyDiscountToAll, _applyItemLayers, buildItemsPayload, copyWith, customerAddress, customerId, customerName (+54 more)

### Community 15 - "Shared UI Widget Classes"
Cohesion: 0.03
Nodes (62): CancelledItem, cancelledItems, canDelete, canEdit, createdAt, customerId, customerName, cutFrom (+54 more)

### Community 16 - "Draft Order Provider"
Cohesion: 0.05
Nodes (45): AppShell, _BadgedIcon, _BadgeDot, _RailPanel, _SidebarPanel, _SidebarTile, _TopBar, _UserFooter (+37 more)

### Community 17 - "Mobile Design System"
Cohesion: 0.05
Nodes (40): active, _changeFilter, color, count, createState, CustomerSubmissionsTab, _CustomerSubmissionsTabState, _displayLimit (+32 more)

### Community 18 - "Mobile Order Flow"
Cohesion: 0.03
Nodes (57): AppColors, AppTextStyles, AppTheme, available, background, bodyLarge, bodyMedium, bodySmall (+49 more)

### Community 19 - "customer_submission"
Cohesion: 0.03
Nodes (64): _alamatKirimCtl, _alamatKtpCtl, _areaCtl, _barengOrder, _batasKreditCtl, _buildPayload, _channelKategori, _channelOptions (+56 more)

### Community 20 - "widgets/app_shell.dart"
Cohesion: 0.06
Nodes (32): actions, AppShellNavItem, body, brandIcon, brandSubtitle, brandTitle, build, _buildNavList (+24 more)

### Community 21 - "draft_order_provider"
Cohesion: 0.04
Nodes (53): addItem, addLine, buildItemsPayload, _customerAddress, _customerId, _customerName, cutFrom, discount (+45 more)

### Community 22 - "customer_submission"
Cohesion: 0.04
Nodes (55): alamatKirim, alamatKtp, approvedCustomerId, areaRoute, batasKreditRupiah, branch, branchNama, channelKategori (+47 more)

### Community 23 - "customer_submission"
Cohesion: 0.04
Nodes (53): alamatKirim, alamatKtp, approvedCustomerId, areaRoute, barengCustomerId, batasKreditRupiah, channelKategori, clusterLangganan (+45 more)

### Community 24 - "dashboard_screen"
Cohesion: 0.04
Nodes (53): alamatKirim, alamatKtp, approvedCustomerId, areaRoute, barengCustomerId, batasKreditRupiah, channelKategori, clusterLangganan (+45 more)

### Community 25 - "order"
Cohesion: 0.04
Nodes (52): branch, branchNama, CancelledItem, cancelledItems, copyWith, createdAt, customerId, customerKode (+44 more)

### Community 26 - "uuid"
Cohesion: 0.15
Nodes (13): _best_ms(), _cleanup(), _seed_customer(), _seed_dataset(), _seed_product(), _seed_user(), test_cross_branch_endpoints_under_500ms_with_1000_orders(), _cleanup_orders() (+5 more)

### Community 27 - "design_system"
Cohesion: 0.04
Nodes (50): _allCustomers, _allSalesUsers, _allUsers, area, _AreaAssignmentRow, _AreaAssignmentRowState, _areaAssignments, _AreaRow (+42 more)

### Community 28 - "customer_registration_screen"
Cohesion: 0.04
Nodes (48): _alamatKirimCtl, _alamatKtpCtl, _areaCtl, _barengOrder, _batasKreditCtl, build, _buildPayload, _channelKategori (+40 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.04
Nodes (46): AppColors, AppTextStyles, AppTheme, available, background, _bg, bodyLarge, bodyMedium (+38 more)

### Community 30 - "penugasan_sales_tab"
Cohesion: 0.04
Nodes (34): accessToken, _adminProvider, _apiService, branch, branchNama, build, _buildBody, _checkIdle (+26 more)

### Community 31 - "users_tab"
Cohesion: 0.05
Nodes (43): align, build, _buildDesktopTable, _buildErrorTile, _buildMobileList, _clearErrors, color, createState (+35 more)

### Community 32 - "order"
Cohesion: 0.04
Nodes (44): AppColors, background, border, borderLight, danger, dangerSoft, dangerText, error (+36 more)

### Community 33 - "security.py"
Cohesion: 0.05
Nodes (21): load_branches_cache(), create_access_token(), create_refresh_token(), decode_token(), get_current_user(), require_admin(), require_admin_or_supervisor(), require_auth() (+13 more)

### Community 34 - "sales-app/lib/presentation/screens/bulletin/bulletin_screen.dart"
Cohesion: 0.09
Nodes (24): build, bulletin, _BulletinCard, BulletinScreen, _BulletinScreenState, createState, initState, onTap (+16 more)

### Community 35 - "web_auth_storage.dart"
Cohesion: 0.05
Nodes (42): active, _branch, _BranchChip, build, _buildCardList, _buildHeader, _buildRow, _buildTable (+34 more)

### Community 36 - "List"
Cohesion: 0.09
Nodes (18): actions, AppPageHeader, build, leading, subtitle, title, action, build (+10 more)

### Community 37 - "storage.py"
Cohesion: 0.06
Nodes (22): create_branch(), disable_branch(), enable_branch(), get_branch(), get_branch_stats(), list_branches(), _reload_cache(), update_branch() (+14 more)

### Community 38 - "products.py"
Cohesion: 0.11
Nodes (24): clear_import_errors(), delete_product(), _get_4p_suppliers(), get_admin_stats(), get_import_logs(), get_kategori_list(), get_product(), get_product_count() (+16 more)

### Community 39 - "package:provider/provider.dart"
Cohesion: 0.05
Nodes (42): CancelledItem, cancelledItems, canDelete, canEdit, createdAt, customerId, customerName, discount2Nominal (+34 more)

### Community 40 - "suppliers_tab_test.dart"
Cohesion: 0.20
Nodes (8): createSupplier, data, _harness, main, _setDesktop, _setMobile, _setTablet, updateSupplierActive

### Community 41 - "sheets_sync.py"
Cohesion: 0.06
Nodes (26): ImportedSale, ImportLog, SyncValidationError, _bulk_upsert_customers(), _normalize(), _read_excel(), _safe_reason(), _str_or_none() (+18 more)

### Community 42 - "performance_tab"
Cohesion: 0.05
Nodes (35): align, _badge, _branchFilter, _branchLabel, build, _buildLeaderboard, _buildPeriodFilterSection, _buildSectionTitle (+27 more)

### Community 43 - "reports.py"
Cohesion: 0.05
Nodes (40): _alamatC, build, _buildCardList, _buildError, _buildFooter, _buildForm, _buildHeader, _buildRow (+32 more)

### Community 44 - "responsive"
Cohesion: 0.17
Nodes (7): ChangePasswordDialog, TabName, UserRole, randomString(), TEST_DATA, TEST_FILES, TEST_USERS

### Community 45 - "../../../core/design_system.dart"
Cohesion: 0.08
Nodes (17): build, ErrorState, icon, message, onRetry, title, build, FilterBar (+9 more)

### Community 46 - "products_tab"
Cohesion: 0.05
Nodes (37): 0. Keputusan User (locked in), 1. Ringkasan & Tujuan, 2.1 Breakpoints, 2.2 Layout Strategy, 2.3 Dialog & Bottom Sheet Strategy, 2.4 Typography & Spacing, 2. Target Responsive Design System, 3. Reusable Component Library (+29 more)

### Community 47 - "test_reports_detail_param.py"
Cohesion: 0.33
Nodes (8): _cleanup(), _seed_one_order(), _seed_user(), test_daily_default_returns_summary_json(), test_daily_with_detail_returns_xlsx(), test_period_default_returns_summary_json(), test_period_with_detail_returns_xlsx(), _token()

### Community 48 - "action_button_row"
Cohesion: 0.06
Nodes (30): _authRepo, AuthState, changeOwnPassword, checkLoginStatus, _errorMessage, forceLogout, getToken, isAuthenticated (+22 more)

### Community 49 - "product_provider"
Cohesion: 0.07
Nodes (23): _apiService, _authRepo, AuthWrapper, _backgroundTimeout, _checking, createState, didChangeAppLifecycleState, dispose (+15 more)

### Community 50 - "Admin Bulletins Tab"
Cohesion: 0.11
Nodes (17): actions, badges, build, _buildActions, _buildField, _buildFields, _buildHeader, DataCard (+9 more)

### Community 51 - "step_pick_customer.dart"
Cohesion: 0.06
Nodes (17): available, build, OrderStatus, orderStatusBgColor, OrderStatusChip, orderStatusColor, orderStatusFromString, orderStatusLabel (+9 more)

### Community 52 - "============================================================"
Cohesion: 0.06
Nodes (32): _, Breakpoints, cardGap, cardPadding, columns, compactMax, contentPadding, device (+24 more)

### Community 53 - "State"
Cohesion: 0.04
Nodes (47): _back, _backFromProducts, build, _confirmCancel, _connector, _createRequestId, createState, currentStep (+39 more)

### Community 54 - "Sales App Order Repository"
Cohesion: 0.06
Nodes (31): build, _buildCardList, _buildFilterDropdowns, _buildProductCard, _buildTable, colW, _confirmDelete, createState (+23 more)

### Community 55 - "Mobile Order Detail"
Cohesion: 0.09
Nodes (18): BulletinProvider, _bulletins, dismissBulletin, _error, hasUnread, latestUnread, loadBulletins, _loading (+10 more)

### Community 56 - "@playwright/test"
Cohesion: 0.06
Nodes (30): _allProducts, _categoryFilter, clearFilters, clearSearch, countByStatus, countByStatusAll, dispose, _errorMessage (+22 more)

### Community 57 - "Data Repositories"
Cohesion: 0.06
Nodes (26): AppInput, autofocus, build, controller, enabled, focusNode, helperText, hint (+18 more)

### Community 58 - "my_submissions_screen"
Cohesion: 0.06
Nodes (30): AppRadius, AppSpacing, AppTextStyles, body, bodyLarge, bodyMedium, bodyMuted, bodySmall (+22 more)

### Community 59 - "ApiService"
Cohesion: 0.07
Nodes (23): _api, BulletinRepository, dismissBulletin, getBulletins, _api, get4pSuppliers, getProduct, getProducts (+15 more)

### Community 60 - "4. Per-Screen Responsive Adaptations"
Cohesion: 0.07
Nodes (28): _animation, _applyInput, available, _controller, createState, _detailRow, didUpdateWidget, disabled (+20 more)

### Community 61 - "admin_web/lib/core/branch.dart"
Cohesion: 0.07
Nodes (26): all, banjarmasin, barabai, batulicin, BranchCode, BranchLabel, display, isValid (+18 more)

### Community 62 - "bulletin_provider"
Cohesion: 0.17
Nodes (17): AuthFixtures, test, DashboardPage, LoginPage, gotoBulletinsTab(), gotoCrossBranchTab(), gotoSubmissionsTab(), gotoCustomersTab() (+9 more)

### Community 63 - "Cross-Branch Reports Tab"
Cohesion: 0.10
Nodes (12): load_names(), main(), main(), export_all(), export_table(), import_all(), import_table(), main() (+4 more)

### Community 64 - "Sales Performance Model"
Cohesion: 0.07
Nodes (22): completer, input, onChange, pickPdfFile, build, bulletin, _BulletinCard, BulletinsTab (+14 more)

### Community 65 - "customer_submission_detail_screen"
Cohesion: 0.06
Nodes (32): 0. Keputusan User (locked in), 10. Phase Execution Order & Verifikasi, 11. Catatan Teknis, 1. Ringkasan & Tujuan, 2. Phase 1 — Mobile Search Debounce (HIGH impact, 1 fase), 3. Phase 2 — Admin Web Debounce + Stop Refetch on Mutation (HIGH impact, 1 fase), 4. Phase 3 — Backend N+1 Elimination (MEDIUM impact, 1 fase), 5. Phase 4 — Backend Connection Pool (MEDIUM impact, 1 fase) (+24 more)

### Community 66 - "AuthProvider"
Cohesion: 0.09
Nodes (18): _handleLogout, icon, iconColor, label, _MenuTile, onTap, _showBantuanDialog, subtitle (+10 more)

### Community 67 - "User"
Cohesion: 0.10
Nodes (19): change_password(), login(), refresh_token(), register(), create_user(), delete_user(), _exclude_deleted(), list_sales_users() (+11 more)

### Community 68 - "home_stats_provider"
Cohesion: 0.07
Nodes (27): _api, cancelOrder, createOrder, deleteOrder, fromJson, getMyOrders, getMyStats, getMyTarget (+19 more)

### Community 69 - "test_reports_summary.py"
Cohesion: 0.18
Nodes (12): _cleanup(), _seed_customer(), _seed_order(), _seed_order_item(), _seed_product(), _seed_user(), test_summary_aggregates_correctly(), test_summary_branch_scoped_for_supervisor() (+4 more)

### Community 70 - "Supplier"
Cohesion: 0.14
Nodes (12): create_supplier(), list_suppliers(), update_supplier_active(), update_supplier_order_type(), Supplier, SupplierActiveUpdate, SupplierCreate, SupplierResponse (+4 more)

### Community 71 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (39): AppTheme, AppBadge, AppBadgeVariant, build, compact, icon, label, variant (+31 more)

### Community 72 - "DashboardPage"
Cohesion: 0.08
Nodes (25): _animation, build, _confirmAndCancel, _confirmAndDelete, _controller, createState, dispose, _error (+17 more)

### Community 73 - "BasePage"
Cohesion: 0.07
Nodes (3): @playwright/test, BasePage, CrossBranchReportsTabPage

### Community 74 - "imported_sales_tab.dart"
Cohesion: 0.06
Nodes (30): _asMapList, _BreakdownCard, build, controller, createState, _currentMonth, dispose, _ErrorCard (+22 more)

### Community 75 - "test_egress_optimizations.py"
Cohesion: 0.14
Nodes (13): _auth(), captured_statements(), _cleanup(), _count(), _seed_bulletin(), _seed_customer(), _seed_product(), _seed_user() (+5 more)

### Community 76 - "customer_repository"
Cohesion: 0.08
Nodes (22): build, _buildEmpty, _buildSalesCard, _buildSalesTab, _buildSkeleton, _buildStatChip, _buildStockCard, _buildStockTab (+14 more)

### Community 77 - "auth_repository"
Cohesion: 0.08
Nodes (22): _activeStatusFilter, cancelOrder, clearMessages, countByStatus, createOrder, deleteOrder, _errorMessage, getOrderDetail (+14 more)

### Community 78 - "supplier_target_edit_dialog"
Cohesion: 0.07
Nodes (23): all, dateToYmdString, formatDateForUi, formatForUi, formatTimeForUi, getDisplayName, IndonesiaTimezones, initTimezone (+15 more)

### Community 79 - "Supabase Egress Reduction Plan"
Cohesion: 0.08
Nodes (23): approvedMtdCount, approvedMtdRevenue, approvedTodayCount, approvedTodayRevenue, branch, displayName, fromJson, nama (+15 more)

### Community 80 - "AdminProvider"
Cohesion: 0.06
Nodes (38): AdminProvider, _approveOrder, build, _cancelItem, _goToPage, initState, _loadActiveTab, _onSearchChanged (+30 more)

### Community 81 - "flutter_window"
Cohesion: 0.09
Nodes (20): children, _color, createState, _currentRole, _currentUsername, CustomerSubmissionDetailScreen, _fmtNumber, _formatDate (+12 more)

### Community 82 - "ProductProvider"
Cohesion: 0.07
Nodes (26): build, build, initState, _ProductRow, build, build, initState, _onScroll (+18 more)

### Community 83 - "loading_state.dart"
Cohesion: 0.06
Nodes (25): fromJson, hasTarget, isActive, isMaster, orderType, pencapaian, supplierName, SupplierPerformanceRow (+17 more)

### Community 84 - "order_provider"
Cohesion: 0.09
Nodes (20): build, children, _color, createState, _currentUsername, CustomerSubmissionDetailScreen, _fmtNumber, _formatDate (+12 more)

### Community 85 - "product_provider"
Cohesion: 0.11
Nodes (18): _animation, build, _controller, createState, customer, _customers, _CustomerSkeletonTile, _CustomerSkeletonTileState (+10 more)

### Community 86 - "sync_result"
Cohesion: 0.11
Nodes (14): _errorMessage, isLoading, load, _loading, _orderRepository, refresh, _stats, _error (+6 more)

### Community 87 - "product"
Cohesion: 0.20
Nodes (17): _cleanup(), _make_user(), _put(), _rows(), _run(), _seed(), _seed_product(), test_inactive_and_legacy_suppliers_flagged() (+9 more)

### Community 88 - "BasePage"
Cohesion: 0.10
Nodes (20): cancelOrder, countByStatus, createOrder, _currentSearch, _currentStatus, deleteOrder, _error, getOrderDetail (+12 more)

### Community 89 - "product"
Cohesion: 0.07
Nodes (21): AuthInterceptor, onError, onResponse, accessToken, ApiService, _authInterceptor, clearTokens, delete (+13 more)

### Community 90 - "User"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 91 - "api_service"
Cohesion: 0.10
Nodes (18): _api, AuthRepository, _backgroundPausedAtKey, changePassword, getNama, getRefreshToken, getToken, getUsername (+10 more)

### Community 92 - "check_bulk_upsert_mixed_supplier.py"
Cohesion: 0.16
Nodes (4): FakeDB, main(), _Query, _row()

### Community 93 - "sales-app/lib/data/repositories/customer_repository.dart"
Cohesion: 0.11
Nodes (16): _api, cancelSubmission, checkDuplicateCustomer, CustomerRepository, getKodeAreas, getMyCustomers, getMyCustomerSubmissions, submitCustomerRegistration (+8 more)

### Community 94 - "main"
Cohesion: 0.10
Nodes (19): @types/node, typescript, description, devDependencies, @playwright/test, @types/node, typescript, name (+11 more)

### Community 96 - "auth_storage"
Cohesion: 0.22
Nodes (16): _cleanup(), _make_user(), _rows(), _run(), _seed(), _seed_product(), _seed_target(), test_manager_all_branches_rollover_then_sum() (+8 more)

### Community 97 - "branch"
Cohesion: 0.11
Nodes (17): accessToken, _api, AuthRepository, branch, branchNama, changePassword, isLoggedIn, login (+9 more)

### Community 98 - "branch"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 99 - "storage.py"
Cohesion: 0.19
Nodes (11): delete_file(), _delete_s3(), _delete_supabase(), _get_s3_client(), _is_s3_url(), _s3_key(), _s3_public_url(), upload_pdf() (+3 more)

### Community 100 - "web_auth_storage.dart"
Cohesion: 0.11
Nodes (18): _accessToken, clearAccessToken, clearAll, deleteRefreshToken, getAccessToken, getBranch, getBranchNama, getNama (+10 more)

### Community 101 - "OrdersTabPage"
Cohesion: 0.11
Nodes (15): assignedAt, fromJson, SalesAssignment, salesId, salesNama, salesUsername, createdAt, fromJson (+7 more)

### Community 103 - "supplier_target_edit_dialog.dart"
Cohesion: 0.12
Nodes (14): build, createState, _ctrl, dispose, _formKey, initialValue, initState, period (+6 more)

### Community 104 - "branch_report"
Cohesion: 0.12
Nodes (13): actions, AppFilterBar, AppSearchField, AppSectionHeader, build, children, controller, hint (+5 more)

### Community 105 - "customer"
Cohesion: 0.12
Nodes (13): _allProducts, countByStockStatus, _error, getStockStatus, _isLoading, loadProducts, loadSuppliers4p, _orderTypeFilter (+5 more)

### Community 106 - "branch"
Cohesion: 0.09
Nodes (18): AdminRepository, createSupplier, failWith, _FakeAdminRepository, main, suppliers, updateSupplierActive, _FakeRepo (+10 more)

### Community 107 - "utils"
Cohesion: 0.12
Nodes (16): approvedCount, approvedRevenue, branch, branchNama, BranchOption, BranchSalesSummary, BranchStockSummary, code (+8 more)

### Community 108 - "order_repository"
Cohesion: 0.12
Nodes (16): fileName, fromJson, importType, inserted, isStoreImport, message, needsReview, reason (+8 more)

### Community 110 - "test_egress_optimizations.py"
Cohesion: 0.12
Nodes (12): formatForUi, parseWitaIso, parseWitaIsoOrNull, witaDateStr, witaFormat, formatForUi, parseBackendDateTime, witaFormat (+4 more)

### Community 112 - "5. Spesifikasi Reusable Widgets (Kode Siap Pakai)"
Cohesion: 0.08
Nodes (25): 0.1 Buat Backup Otomatis, 0.2 Kontrak "Zero Functional Change" (Daftar yang HARAM Diubah), 0.3 Aturan Pemetaan Widget (Cara Mengganti UI Tanpa Merusak Fungsi), 0. PROTOKOL BACKUP & KEAMANAN KODE (WAJIB DIEKSEKUSI PERTAMA KALI), 1. Prinsip Visual (Anti-"AI Generative" Look), 2. Arsitektur Folder Komponen Baru (Aman & Non-Destruktif), 3.1 Palet Warna (`AppColors`), 3.2 Spacing, Radius, & Typography (`AppTokens`) (+17 more)

### Community 113 - "sales-app/lib/presentation/screens/customers/my_submissions_screen.dart"
Cohesion: 0.13
Nodes (13): build, _buildBody, createState, _error, _formatDate, initState, _loading, MySubmissionsScreen (+5 more)

### Community 114 - "customer"
Cohesion: 0.12
Nodes (15): branch, branchNama, fromJson, harga, id, kategori, namaBarang, namaSupplier (+7 more)

### Community 115 - "jwt_utils"
Cohesion: 0.30
Nodes (11): _cleanup(), _cleanup_suppliers(), _cleanup_users(), _make_user(), _seed(), _seed_other_branch(), test_manager_product_count_is_global(), test_supervisor_product_count_excludes_other_branches() (+3 more)

### Community 116 - "flutter_window"
Cohesion: 0.12
Nodes (15): fromJson, harga, id, kategori, namaBarang, namaSupplier, orderType, perluDitinjau (+7 more)

### Community 117 - "admin_web/lib/core/datetime_utils.dart"
Cohesion: 0.12
Nodes (15): build, _buildPasswordField, ChangePasswordDialog, _confirmController, createState, _currentController, dispose, _error (+7 more)

### Community 118 - "win32_window"
Cohesion: 0.13
Nodes (11): _accessToken, ApiService, _checkTokenExpiry, clearAccessToken, delete, _handleResponse, message, post (+3 more)

### Community 120 - "manifest"
Cohesion: 0.13
Nodes (11): build, createState, dispose, _error, _formKey, _isLoading, _login, LoginScreen (+3 more)

### Community 121 - "config"
Cohesion: 0.13
Nodes (11): _accessToken, ApiService, _checkTokenExpiry, clearAccessToken, delete, _handleResponse, message, post (+3 more)

### Community 122 - "sales_web/lib/presentation/screens/customers/my_submissions_screen.dart"
Cohesion: 0.12
Nodes (13): build, _buildBody, createState, _error, _formatDate, initState, _loading, MySubmissionsScreen (+5 more)

### Community 123 - "app_card.dart"
Cohesion: 0.13
Nodes (13): AppCard, borderColor, build, _buildHeader, child, color, elevation, margin (+5 more)

### Community 124 - "responsive_dialog.dart"
Cohesion: 0.14
Nodes (12): actions, build, child, content, contentMaxWidth, desktopWidthFraction, maxHeight, maxWidth (+4 more)

### Community 125 - "supplier_performance"
Cohesion: 0.13
Nodes (13): ApiException, ApiException, data, isConflict, isForbidden, isNotFound, isUnauthorized, message (+5 more)

### Community 126 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.10
Nodes (11): showSupplierEditOrderTypeDialog, message, showSupplierToggleDialog, willActivate, main, main, _harness, main (+3 more)

### Community 127 - "supplier"
Cohesion: 0.13
Nodes (12): _accessKey, AuthStorage, _branchKey, _branchNamaKey, clearTokens, getTokens, _namaKey, _refreshKey (+4 more)

### Community 128 - "supplier_target"
Cohesion: 0.13
Nodes (14): fromJson, harga, id, kategori, namaBarang, namaSupplier, orderType, perluDitinjau (+6 more)

### Community 129 - "confirm_dialog.dart"
Cohesion: 0.14
Nodes (12): build, _CancelButton, _ConfirmButton, ConfirmDialog, InfoDialog, isDestructive, label, onPressed (+4 more)

### Community 130 - "app_adaptive_table.dart"
Cohesion: 0.14
Nodes (12): AppAdaptiveDataView, AppTableColumn, build, _buildDefaultMobileCard, _buildMobile, columns, emptyText, label (+4 more)

### Community 131 - "railway"
Cohesion: 0.14
Nodes (12): authProvider, build, ChangePasswordDialog, _confirmC, createState, dispose, _errSnack, _newC (+4 more)

### Community 132 - "State"
Cohesion: 0.06
Nodes (39): _DesktopFrame, _DesktopFrameState, _ChangePasswordDialogState, _OrderCard, _ChangePasswordDialogState, CustomerRegistrationScreen, _CustomerRegistrationScreenState, _ProductSearchSheet (+31 more)

### Community 133 - "generated_plugin_registrant"
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 134 - "app_responsive.dart"
Cohesion: 0.12
Nodes (15): AppResponsive, AppResponsiveGrid, build, children, desktop, desktopCols, isDesktop, isMobile (+7 more)

### Community 135 - "sales_web/lib/core/branch.dart"
Cohesion: 0.14
Nodes (13): all, banjarmasin, barabai, batulicin, BranchCode, BranchLabel, display, isValid (+5 more)

### Community 136 - "list_sales_customers"
Cohesion: 0.14
Nodes (13): alamat, branch, branchNama, createdAt, Customer, deletedAt, fromJson, id (+5 more)

### Community 137 - "api_exception"
Cohesion: 0.14
Nodes (13): compilerOptions, esModuleInterop, module, moduleResolution, outDir, resolveJsonModule, rootDir, skipLibCheck (+5 more)

### Community 138 - "test_products_supplier_filter.py"
Cohesion: 0.42
Nodes (9): _cleanup(), _make_user(), _seed(), test_admin_sees_all_products_regardless_of_supplier(), test_manager_sees_all_products_regardless_of_supplier(), test_sales_sees_only_active_or_null_supplier(), test_supervisor_sees_all_products_regardless_of_supplier(), test_toggling_supplier_hides_product_from_sales_on_refetch() (+1 more)

### Community 139 - "config"
Cohesion: 0.15
Nodes (12): Architecting Flutter Applications, Architectural Layers, Contents, Data Layer, Data Layer: Service and Repository, Examples, Logic Layer (Domain - Optional), Project Structure (+4 more)

### Community 140 - "sales_web/lib/core/config.dart"
Cohesion: 0.07
Nodes (23): AppConfig, baseUrl, AppConfig, baseUrl, refreshTokenKey, requestTimeout, tokenKey, userIdKey (+15 more)

### Community 141 - "sales_web/lib/data/models/customer.dart"
Cohesion: 0.20
Nodes (9): alamat, createdAt, Customer, fromJson, id, kode, kodeArea, namaToko (+1 more)

### Community 142 - "test_suppliers_create.py"
Cohesion: 0.53
Nodes (8): _cleanup(), _cleanup_suppliers(), _cleanup_users(), _make_user(), test_post_suppliers_as_manager_creates_row(), test_post_suppliers_duplicate_returns_409(), test_post_suppliers_rejects_non_manager(), _token()

### Community 143 - "package:admin_web/core/design_system.dart"
Cohesion: 0.13
Nodes (6): _harness, main, _harness, main, _harness, main

### Community 144 - "test_sheets"
Cohesion: 0.15
Nodes (12): Admin Web, Arsitektur Singkat, Backend, Catatan Deployment, Endpoint API Utama, Mobile, Roles & Permission, Sales Order App (+4 more)

### Community 145 - "sales_web/lib/presentation/screens/auth/change_password_dialog.dart"
Cohesion: 0.15
Nodes (12): copyWith, fromJson, id, incentiveAmount, isOrderCount, isRevenue, period, SalesTarget (+4 more)

### Community 146 - "sales_web/lib/data/repositories/order_repository.dart"
Cohesion: 0.15
Nodes (11): _api, cancelOrder, createOrder, deleteOrder, getMyOrders, getMyStats, getOrderDetail, OrderRepository (+3 more)

### Community 147 - "responsive_action_menu.dart"
Cohesion: 0.12
Nodes (15): action, actions, build, compact, destructive, icon, _InlineActionButton, _kebab (+7 more)

### Community 148 - "migrate_supabase.py"
Cohesion: 0.17
Nodes (11): branch, branchNama, Bulletin, createdAt, description, expireAt, fromJson, id (+3 more)

### Community 149 - "web_download_web.dart"
Cohesion: 0.17
Nodes (11): alamat, createdAt, Customer, deletedAt, fromJson, id, kode, kodeArea (+3 more)

### Community 150 - "stat_tile.dart"
Cohesion: 0.18
Nodes (10): AuthProvider, DraftOrderProvider, HomeStatsProvider, OrderProvider, ProductProvider, AuthProvider, CustomerProvider, DraftOrderProvider (+2 more)

### Community 151 - "responsive_dialog.dart"
Cohesion: 0.12
Nodes (13): _base64UrlDecode, decodePayload, isExpired, JwtUtils, _base64UrlDecode, decodePayload, getExpiry, isExpired (+5 more)

### Community 152 - "CustomerRepository"
Cohesion: 0.15
Nodes (10): _confirmSubmit, initState, _submit, _CustomerSubmissionDetailScreenState, initState, _load, _MySubmissionsScreenState, _load (+2 more)

### Community 153 - "sales_web/lib/presentation/screens/auth/login_screen.dart"
Cohesion: 0.11
Nodes (16): formKey, name, nameController, orderType, showSupplierCreateDialog, SupplierCreateResult, build, createState (+8 more)

### Community 154 - "DashboardScreen"
Cohesion: 0.13
Nodes (7): FlutterWindow, flutter_controller_, project_, Win32Window, child_content_, quit_on_close_, window_handle_

### Community 155 - "test_reports_detail_param.py"
Cohesion: 0.18
Nodes (10): branch, branchNama, displayName, fromJson, id, isActive, nama, role (+2 more)

### Community 157 - "Cluster 157"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 158 - "Cluster 158"
Cohesion: 0.18
Nodes (5): get_my_target(), list_sales_targets(), upsert_sales_target(), SalesTarget, SalesTargetUpdate

### Community 159 - "test_suppliers_toggle.py"
Cohesion: 0.53
Nodes (8): _cleanup(), _cleanup_suppliers(), _cleanup_users(), _make_user(), test_patch_active_404_for_missing(), test_patch_active_as_manager_toggles(), test_patch_active_rejects_admin(), _token()

### Community 160 - "Cluster 160"
Cohesion: 0.20
Nodes (6): call, cancel, Debouncer, delay, dispose, _timer

### Community 161 - "customer_submissions.py"
Cohesion: 0.17
Nodes (9): approve_submission(), cancel_submission(), check_duplicate_customer(), get_submission(), list_my_submissions(), list_submissions(), reject_submission(), _serialize() (+1 more)

### Community 162 - "Cluster 162"
Cohesion: 0.20
Nodes (9): Bulletin, createdAt, description, expireAt, fromJson, id, isRead, pdfUrl (+1 more)

### Community 163 - "Cluster 163"
Cohesion: 0.20
Nodes (9): Bulletin, createdAt, description, expireAt, fromJson, id, isRead, pdfUrl (+1 more)

### Community 164 - "screens/change_password_dialog.dart"
Cohesion: 0.13
Nodes (12): adminRepository, build, ChangePasswordDialog, _confirmC, createState, dispose, _errSnack, _newC (+4 more)

### Community 165 - "build.gradle"
Cohesion: 0.20
Nodes (9): background_color, description, display, icons, name, orientation, short_name, start_url (+1 more)

### Community 168 - "__init__"
Cohesion: 0.22
Nodes (8): branch, fromJson, id, period, supplierName, SupplierTarget, targetValue, toJson

### Community 169 - "local_day_utc_bounds"
Cohesion: 0.33
Nodes (3): device_timezone_offset_minutes(), local_day_utc_bounds(), local_now_for_date()

### Community 173 - "bool get"
Cohesion: 0.22
Nodes (7): isForbidden, isNotFound, isServerError, isUnauthorized, message, statusCode, toString

### Community 176 - "Sales Order App"
Cohesion: 0.39
Nodes (4): copy_table(), get_columns(), get_conn(), main()

### Community 177 - "UsersTabPage"
Cohesion: 0.25
Nodes (7): build, dockerfilePath, deploy, numReplicas, restartPolicyLimit, restartPolicyType, $schema

### Community 181 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 187 - "SubmissionDetailPage"
Cohesion: 0.29
Nodes (6): Admin Web E2E Test Suite, Environment Variables, Running Tests, Setup, Test Structure, Writing New Tests

### Community 191 - "stat_tile.dart"
Cohesion: 0.14
Nodes (12): build, color, icon, label, onTap, StatTile, text, trend (+4 more)

### Community 192 - "test_suppliers_toggle.py"
Cohesion: 0.40
Nodes (3): message, statusCode, toString

### Community 194 - "LaunchImage.imageset/README.md"
Cohesion: 0.50
Nodes (3): devDependencies, supabase, supabase

### Community 195 - "test_migration_idempotent_preserves_toggle.py"
Cohesion: 0.50
Nodes (3): firebase, dependencies, firebase

### Community 196 - "admin_web/lib/main.dart"
Cohesion: 0.14
Nodes (8): AdminApp, build, initializeDateFormatting, initialTokens, main, null, storage, tokens

### Community 204 - "action_button_row.dart"
Cohesion: 0.14
Nodes (11): ActionButton, ActionButtonRow, actions, alignment, build, _buildButton, destructive, icon (+3 more)

### Community 221 - "AuthProvider"
Cohesion: 0.18
Nodes (10): _LoginScreenState, _AuthWrapperState, build, _checkAuth, _checkBackgroundTimeout, _LoginScreenState, _AuthWrapperState, initState (+2 more)

### Community 222 - "dart:typed_data"
Cohesion: 0.15
Nodes (6): triggerBrowserDownload, triggerBrowserDownload, bytes, name, PickedPdf, pickPdfFile

### Community 223 - "upsert_supplier_target"
Cohesion: 0.19
Nodes (4): delete_supplier_target(), list_supplier_targets(), _require_known_supplier(), upsert_supplier_target()

### Community 225 - "sales-app/lib/presentation/screens/auth/login_screen.dart"
Cohesion: 0.18
Nodes (9): build, createState, dispose, _formKey, _handleLogin, LoginScreen, _obscurePassword, _passwordController (+1 more)

### Community 226 - "VoidCallback"
Cohesion: 0.18
Nodes (9): AppPagination, build, hasNext, hasPrev, onNext, onPrev, page, summary (+1 more)

### Community 227 - "String? get"
Cohesion: 0.22
Nodes (7): displayName, fromJson, id, nama, role, SalesUser, username

### Community 228 - "web_download_web.dart"
Cohesion: 0.25
Nodes (5): anchor, blob, blobParts, triggerBrowserDownload, url

### Community 229 - "customer_provider.dart"
Cohesion: 0.25
Nodes (5): _customerRepo, _customers, _error, _isLoading, loadCustomers

## Knowledge Gaps
- **2995 isolated node(s):** `supabase`, `message`, `statusCode`, `toString`, `onResponse` (+2990 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 4002 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **52 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Order` connect `Order Flow Review Step` to `security.py`, `customer_submissions.py`, `storage.py`, `products.py`, `reports.py`, `config`?**
  _High betweenness centrality (0.117) - this node is a cross-community bridge._
- **What connects `supabase`, `message`, `statusCode` to the rest of the system?**
  _2995 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AdminProvider State Hub` be split into smaller, more focused modules?**
  _Cohesion score 0.009216589861751152 - nodes in this community are weakly interconnected._
- **Why does `Task 2.3 — Stop `loadAll()` di `approveOrder/rejectOrder/cancelOrderItem`` connect `config` to `customer_submission_detail_screen`, `Order Flow Review Step`?**
  _High betweenness centrality (0.117) - this node is a cross-community bridge._
- **Should `Sales App Home Screens` be split into smaller, more focused modules?**
  _Cohesion score 0.012345679012345678 - nodes in this community are weakly interconnected._
- **Why does `OrdersTabPage` connect `config` to `BasePage`, `responsive`, `bulletin_provider`?**
  _High betweenness centrality (0.115) - this node is a cross-community bridge._
- **Should `Admin Stats Tab` be split into smaller, more focused modules?**
  _Cohesion score 0.035003431708991076 - nodes in this community are weakly interconnected._