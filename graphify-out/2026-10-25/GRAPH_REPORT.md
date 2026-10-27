# Graph Report - Project-magang  (2026-10-20)

## Corpus Check
- 285 files · ~191,193 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 48 file(s) not represented in the graph (top: (none) 16, .xml 7, .plist 4)

## Summary
- 5142 nodes · 8461 edges · 198 communities (158 shown, 40 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 339 edges (avg confidence: 0.93)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `155d8142`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- AdminProvider State Hub
- Sales App Home Screens
- Admin Stats Tab
- Backend Auth Endpoints
- Backend Pydantic Schemas
- Admin API Repositories
- Sales Web Order Flow UI
- Backend Order Endpoints
- Admin Orders Tab
- Backend Product Endpoints
- Backend Customer Endpoints
- Order Flow Review Step
- Customer Registration Form
- Admin Design System
- Sales Web Order Models
- Shared UI Widget Classes
- Draft Order Provider
- Mobile Design System
- Mobile Order Flow
- customer_submission
- misc_screen
- draft_order_provider
- customer_submission
- customer_submission
- dashboard_screen
- order
- sync_tab
- design_system
- customer_registration_screen
- package:flutter/material.dart
- penugasan_sales_tab
- users_tab
- order
- sales-app/lib/presentation/screens/orders/order_list_screen.dart
- customers_tab
- web_auth_storage.dart
- main
- confirm_dialog
- storage.py
- package:provider/provider.dart
- customer_submissions_tab
- auth_provider
- performance_tab
- reports.py
- responsive
- product_catalog_screen
- products_tab
- step_pick_products
- action_button_row
- product_provider
- Admin Bulletins Tab
- step_pick_customer.dart
- ============================================================
- sales_web/lib/presentation/screens/orders/order_list_screen.dart
- Sales App Order Repository
- Mobile Order Detail
- @playwright/test
- Data Repositories
- my_submissions_screen
- Orders Provider
- 4. Per-Screen Responsive Adaptations
- customer_submissions.py
- bulletin_provider
- Cross-Branch Reports Tab
- Sales Performance Model
- customer_submission_detail_screen
- branches
- sales_target
- home_stats_provider
- suppliers_tab
- StatefulWidget
- customer_submission_detail_screen
- DashboardPage
- api_service
- SceneDelegate
- auth_repository
- customer_repository
- auth_repository
- supplier_target_edit_dialog
- Supabase Egress Reduction Plan
- win32_window
- flutter_window
- models.py
- data_card
- order_provider
- product_provider
- sync_result
- product
- BasePage
- product
- User
- api_service
- screens/login_screen.dart
- api_service
- main
- e2e/package.json
- auth_storage
- branch
- branch
- product
- ProductsTabPage
- OrdersTabPage
- change_password_dialog
- SuppliersTabPage
- branch_report
- customer
- branch
- utils
- order_repository
- sales_targets
- test_egress_optimizations.py
- config
- auth_provider
- bulletin
- customer
- jwt_utils
- admin_web/lib/core/datetime_utils.dart
- win32_window
- user_item
- manifest
- config
- bulletin
- manifest
- win32_window
- supplier_performance
- List
- supplier
- supplier_target
- api_exception
- step_pick_order_type.dart
- railway
- Point
- generated_plugin_registrant
- test_reports_summary.py
- uuid
- list_sales_customers
- api_exception
- package
- config
- MainActivity
- test_suppliers_list.py
- sales_web/lib/presentation/screens/auth/change_password_dialog.dart
- screens/change_password_dialog.dart
- admin_provider_supplier_test.dart
- migrate_supabase.py
- web_download_web.dart
- stat_tile.dart
- responsive_dialog.dart
- test_products_supplier_filter.py
- _DashboardContentState
- DashboardScreen
- test_reports_detail_param.py
- create_access_token
- CustomersTabPage
- BulletinsTabPage
- compilerOptions
- list_suppliers
- Architecting Flutter Applications
- Sales Order App
- UsersTabPage
- PenugasanSalesTabPage
- package:flutter/foundation.dart
- sales_web/lib/data/models/bulletin.dart
- sales_web/lib/data/models/customer.dart
- bool get
- CrossBranchReportsTabPage
- PerformanceTabPage
- SyncTabPage
- test_suppliers_create.py
- SubmissionDetailPage
- StatsTabPage
- Admin Web E2E Test Suite
- MultiSelectSalesDialog
- ChangePasswordDialog
- test_suppliers_toggle.py
- CLAUDE.md
- LaunchImage.imageset/README.md
- test_migration_idempotent_preserves_toggle.py
- bulletin_pdf_picker_stub.dart

## God Nodes (most connected - your core abstractions)
1. `============================================================` - 163 edges
2. `AdminProvider` - 96 edges
3. `BaseSchema` - 68 edges
4. `BasePage` - 51 edges
5. `Product` - 46 edges
6. `apply_branch_filter()` - 44 edges
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
- `initState` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart
- `_showDeleteDialog` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart

## Import Cycles
- None detected.

## Communities (198 total, 40 thin omitted)

### Community 0 - "AdminProvider State Hub"
Cohesion: 0.01
Nodes (180): _activeTabIndex, adminRepository, AdminState, _allOrders, approveCustomerSubmission, approveOrder, bulletins, _bulletinsCacheTime (+172 more)

### Community 1 - "Sales App Home Screens"
Cohesion: 0.04
Nodes (61): _animation, _BerandaTab, _BerandaTabState, build, color, _controller, createState, currency (+53 more)

### Community 2 - "Admin Stats Tab"
Cohesion: 0.02
Nodes (104): aggregateDashboardPerformance, _applyFilters, approvedMtdCount, approvedMtdRevenue, approvedTodayCount, approvedTodayRevenue, branch, _branchFilter (+96 more)

### Community 3 - "Backend Auth Endpoints"
Cohesion: 0.05
Nodes (17): load_branches_cache(), require_admin_or_supervisor(), require_auth(), require_manager(), require_manager_global(), require_supervisor(), require_supervisor_or_manager_global(), require_write_access() (+9 more)

### Community 4 - "Backend Pydantic Schemas"
Cohesion: 0.03
Nodes (73): AreaAssignmentListItem, AreaAssignmentsPut, BaseSchema, BranchBase, BranchCreate, BranchResponse, Config, BranchSalesSummary (+65 more)

### Community 5 - "Admin API Repositories"
Cohesion: 0.02
Nodes (70): _api, approveCustomerSubmission, approveOrder, cancelOrderItems, changePassword, clearImportErrors, clearTokens, createBulletin (+62 more)

### Community 6 - "Sales Web Order Flow UI"
Cohesion: 0.03
Nodes (78): _activeLayersSummary, _bsDetailRow, _buildBottomBar, _buildStepContent, _calcPreview, _chip, color, _commit (+70 more)

### Community 7 - "Backend Order Endpoints"
Cohesion: 0.09
Nodes (34): _apply_3_layers(), approve_order(), _book_items(), _build_order_response(), cancel_order(), cancel_order_items(), create_order(), delete_draft_order() (+26 more)

### Community 8 - "Admin Orders Tab"
Cohesion: 0.02
Nodes (82): _applyFilters, _buildAllOrders, _buildPendingOrders, _buildPriceSummary, _CancelItemDialog, _CancelItemDialogState, _CancelItemResult, canEdit (+74 more)

### Community 9 - "Backend Product Endpoints"
Cohesion: 0.10
Nodes (25): clear_import_errors(), delete_product(), _get_4p_suppliers(), get_admin_stats(), get_import_logs(), get_kategori_list(), get_product(), get_product_count() (+17 more)

### Community 10 - "Backend Customer Endpoints"
Cohesion: 0.13
Nodes (18): create_customer(), _customer_to_response(), delete_customer(), _exclude_deleted(), get_customer(), get_customer_count(), import_excel(), _list_assignments() (+10 more)

### Community 11 - "Order Flow Review Step"
Cohesion: 0.03
Nodes (63): _actionIconBtn, _activeLayersSummary, _AddLineSheet, _AddLineSheetState, _buildDiscount, _calcPreview, _chip, color (+55 more)

### Community 12 - "Customer Registration Form"
Cohesion: 0.03
Nodes (57): _alamatKirimCtl, _alamatKtpCtl, _areaCtl, _barengOrder, _batasKreditCtl, _buildPayload, _channelKategori, _channelOptions (+49 more)

### Community 13 - "Admin Design System"
Cohesion: 0.03
Nodes (63): AppCard, AppColors, AppTextStyles, AppTheme, available, background, bodyLarge, bodyMedium (+55 more)

### Community 14 - "Sales Web Order Models"
Cohesion: 0.03
Nodes (62): CancelledItem, cancelledItems, canDelete, canEdit, createdAt, customerId, customerName, cutFrom (+54 more)

### Community 15 - "Shared UI Widget Classes"
Cohesion: 0.03
Nodes (64): _EmptyState, _OrderSection, _StatCard, _SubmissionsList, _LayerField, _OrderItemRow, _BranchPerformanceCard, _PeriodReportCard (+56 more)

### Community 16 - "Draft Order Provider"
Cohesion: 0.03
Nodes (62): addLine, applyDiscountToAll, _applyItemLayers, buildItemsPayload, copyWith, customerAddress, customerId, customerName (+54 more)

### Community 17 - "Mobile Design System"
Cohesion: 0.03
Nodes (57): AppColors, AppTextStyles, AppTheme, available, background, bodyLarge, bodyMedium, bodySmall (+49 more)

### Community 18 - "Mobile Order Flow"
Cohesion: 0.04
Nodes (61): _ChangePasswordDialogState, _maybeShowBulletinPopup, _ChangePasswordDialogState, _CustomerRegistrationScreenState, build, build, _openOrderFlow, build (+53 more)

### Community 19 - "customer_submission"
Cohesion: 0.04
Nodes (55): alamatKirim, alamatKtp, approvedCustomerId, areaRoute, batasKreditRupiah, branch, branchNama, channelKategori (+47 more)

### Community 20 - "misc_screen"
Cohesion: 0.05
Nodes (40): build, bulletin, _BulletinCard, BulletinScreen, _BulletinScreenState, createState, initState, onTap (+32 more)

### Community 21 - "draft_order_provider"
Cohesion: 0.04
Nodes (52): addItem, addLine, buildItemsPayload, _customerAddress, _customerId, _customerName, cutFrom, discount (+44 more)

### Community 22 - "customer_submission"
Cohesion: 0.04
Nodes (53): alamatKirim, alamatKtp, approvedCustomerId, areaRoute, barengCustomerId, batasKreditRupiah, channelKategori, clusterLangganan (+45 more)

### Community 23 - "customer_submission"
Cohesion: 0.04
Nodes (53): alamatKirim, alamatKtp, approvedCustomerId, areaRoute, barengCustomerId, batasKreditRupiah, channelKategori, clusterLangganan (+45 more)

### Community 24 - "dashboard_screen"
Cohesion: 0.04
Nodes (40): accessToken, _adminProvider, _apiService, branch, branchNama, build, _buildBody, _buildDrawer (+32 more)

### Community 25 - "order"
Cohesion: 0.04
Nodes (52): branch, branchNama, CancelledItem, cancelledItems, copyWith, createdAt, customerId, customerKode (+44 more)

### Community 26 - "sync_tab"
Cohesion: 0.04
Nodes (43): rootNavigatorKey, align, build, _buildDesktopTable, _buildErrorTile, _buildMobileList, _clearErrors, color (+35 more)

### Community 27 - "design_system"
Cohesion: 0.04
Nodes (46): AppColors, AppTextStyles, AppTheme, available, background, _bg, bodyLarge, bodyMedium (+38 more)

### Community 28 - "customer_registration_screen"
Cohesion: 0.04
Nodes (48): _alamatKirimCtl, _alamatKtpCtl, _areaCtl, _barengOrder, _batasKreditCtl, build, _buildPayload, _channelKategori (+40 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (23): formKey, name, nameController, orderType, showSupplierCreateDialog, SupplierCreateResult, showSupplierEditOrderTypeDialog, message (+15 more)

### Community 30 - "penugasan_sales_tab"
Cohesion: 0.04
Nodes (48): _allCustomers, _allSalesUsers, _allUsers, area, _AreaAssignmentRow, _AreaAssignmentRowState, _areaAssignments, _AreaRow (+40 more)

### Community 31 - "users_tab"
Cohesion: 0.05
Nodes (42): active, _branch, _BranchChip, build, _buildCardList, _buildHeader, _buildRow, _buildTable (+34 more)

### Community 32 - "order"
Cohesion: 0.05
Nodes (42): CancelledItem, cancelledItems, canDelete, canEdit, createdAt, customerId, customerName, discount2Nominal (+34 more)

### Community 33 - "sales-app/lib/presentation/screens/orders/order_list_screen.dart"
Cohesion: 0.05
Nodes (37): build, _controller, createState, dispose, height, initState, label, LoadingState (+29 more)

### Community 34 - "customers_tab"
Cohesion: 0.05
Nodes (40): _alamatC, build, _buildCardList, _buildError, _buildFooter, _buildForm, _buildHeader, _buildRow (+32 more)

### Community 35 - "web_auth_storage.dart"
Cohesion: 0.11
Nodes (18): _accessToken, clearAccessToken, clearAll, deleteRefreshToken, getAccessToken, getBranch, getBranchNama, getNama (+10 more)

### Community 36 - "main"
Cohesion: 0.06
Nodes (31): _apiService, _authRepo, _AuthWrapperState, _backgroundTimeout, build, _checkAuth, _checkBackgroundTimeout, _checking (+23 more)

### Community 37 - "confirm_dialog"
Cohesion: 0.07
Nodes (23): build, _CancelButton, _ConfirmButton, ConfirmDialog, InfoDialog, isDestructive, label, onPressed (+15 more)

### Community 38 - "storage.py"
Cohesion: 0.07
Nodes (24): _assert_bulletin_visible(), _build_bulletin_response(), bulletin_upload_pdf(), create_bulletin(), delete_bulletin(), dismiss_bulletin(), list_bulletins(), expire_bulletins() (+16 more)

### Community 39 - "package:provider/provider.dart"
Cohesion: 0.08
Nodes (21): _LoginScreenState, build, createState, dispose, _formKey, _handleLogin, LoginScreen, _LoginScreenState (+13 more)

### Community 40 - "customer_submissions_tab"
Cohesion: 0.04
Nodes (52): AdminProvider, active, build, _changeFilter, color, count, createState, CustomerSubmissionsTab (+44 more)

### Community 41 - "auth_provider"
Cohesion: 0.06
Nodes (30): _authRepo, AuthState, changeOwnPassword, checkLoginStatus, _errorMessage, forceLogout, getToken, isAuthenticated (+22 more)

### Community 42 - "performance_tab"
Cohesion: 0.06
Nodes (30): align, build, _buildLeaderboard, _buildPeriodFilterSection, _buildSectionTitle, _buildSupplierPerformanceTable, _buildTargetSection, child (+22 more)

### Community 43 - "reports.py"
Cohesion: 0.05
Nodes (31): _build_daily_xlsx(), _build_period_xlsx(), _build_report(), cross_branch_sales_summary(), cross_branch_stock_summary(), daily_report(), get_supplier_performance(), _layer_cut_value() (+23 more)

### Community 44 - "responsive"
Cohesion: 0.06
Nodes (32): _, Breakpoints, cardGap, cardPadding, columns, compactMax, contentPadding, device (+24 more)

### Community 45 - "product_catalog_screen"
Cohesion: 0.07
Nodes (26): build, build, initState, _ProductRow, build, build, initState, _onScroll (+18 more)

### Community 46 - "products_tab"
Cohesion: 0.06
Nodes (31): build, _buildCardList, _buildFilterDropdowns, _buildProductCard, _buildTable, colW, _confirmDelete, createState (+23 more)

### Community 47 - "step_pick_products"
Cohesion: 0.06
Nodes (28): _animation, _applyInput, available, _controller, createState, _detailRow, didUpdateWidget, disabled (+20 more)

### Community 48 - "action_button_row"
Cohesion: 0.06
Nodes (32): ActionButton, ActionButtonRow, actions, alignment, build, _buildButton, destructive, icon (+24 more)

### Community 49 - "product_provider"
Cohesion: 0.06
Nodes (30): _allProducts, _categoryFilter, clearFilters, clearSearch, countByStatus, countByStatusAll, dispose, _errorMessage (+22 more)

### Community 50 - "Admin Bulletins Tab"
Cohesion: 0.07
Nodes (22): completer, input, onChange, pickPdfFile, build, bulletin, _BulletinCard, BulletinsTab (+14 more)

### Community 51 - "step_pick_customer.dart"
Cohesion: 0.11
Nodes (18): _animation, build, _controller, createState, customer, _customers, _CustomerSkeletonTile, _CustomerSkeletonTileState (+10 more)

### Community 52 - "============================================================"
Cohesion: 0.01
Nodes (162): ============================================================, ----------------------------------------, ----------------------------------------, ----------------------------------------, ============================================================, ============================================================, ----------------------------------------, ---------------------------------------- (+154 more)

### Community 53 - "sales_web/lib/presentation/screens/orders/order_list_screen.dart"
Cohesion: 0.07
Nodes (25): witaFormat, build, _buildActionButtons, _cancelOrder, _confirmDelete, createState, _deleteOrder, dispose (+17 more)

### Community 54 - "Sales App Order Repository"
Cohesion: 0.07
Nodes (27): _api, cancelOrder, createOrder, deleteOrder, fromJson, getMyOrders, getMyStats, getMyTarget (+19 more)

### Community 55 - "Mobile Order Detail"
Cohesion: 0.08
Nodes (25): _animation, build, _confirmAndCancel, _confirmAndDelete, _controller, createState, dispose, _error (+17 more)

### Community 56 - "@playwright/test"
Cohesion: 0.16
Nodes (8): @playwright/test, AuthFixtures, TabName, UserRole, randomString(), TEST_DATA, TEST_FILES, TEST_USERS

### Community 57 - "Data Repositories"
Cohesion: 0.07
Nodes (23): _api, BulletinRepository, dismissBulletin, getBulletins, _api, get4pSuppliers, getProduct, getProducts (+15 more)

### Community 58 - "my_submissions_screen"
Cohesion: 0.06
Nodes (33): _confirmSubmit, initState, _submit, initState, _buildBody, createState, _error, _formatDate (+25 more)

### Community 59 - "Orders Provider"
Cohesion: 0.08
Nodes (22): _activeStatusFilter, cancelOrder, clearMessages, countByStatus, createOrder, deleteOrder, _errorMessage, getOrderDetail (+14 more)

### Community 60 - "4. Per-Screen Responsive Adaptations"
Cohesion: 0.05
Nodes (37): 0. Keputusan User (locked in), 1. Ringkasan & Tujuan, 2.1 Breakpoints, 2.2 Layout Strategy, 2.3 Dialog & Bottom Sheet Strategy, 2.4 Typography & Spacing, 2. Target Responsive Design System, 3. Reusable Component Library (+29 more)

### Community 61 - "customer_submissions.py"
Cohesion: 0.10
Nodes (14): approve_submission(), cancel_submission(), check_duplicate_customer(), get_submission(), list_my_submissions(), list_submissions(), reject_submission(), _serialize() (+6 more)

### Community 62 - "bulletin_provider"
Cohesion: 0.09
Nodes (17): _bulletins, dismissBulletin, _error, hasUnread, latestUnread, loadBulletins, _loading, _repo (+9 more)

### Community 63 - "Cross-Branch Reports Tab"
Cohesion: 0.09
Nodes (21): build, _buildEmpty, _buildSalesCard, _buildSalesTab, _buildStatChip, _buildStockCard, _buildStockTab, _buildTotalCard (+13 more)

### Community 64 - "Sales Performance Model"
Cohesion: 0.08
Nodes (23): approvedMtdCount, approvedMtdRevenue, approvedTodayCount, approvedTodayRevenue, branch, displayName, fromJson, nama (+15 more)

### Community 65 - "customer_submission_detail_screen"
Cohesion: 0.09
Nodes (20): children, _color, createState, _currentRole, _currentUsername, CustomerSubmissionDetailScreen, _fmtNumber, _formatDate (+12 more)

### Community 66 - "branches"
Cohesion: 0.16
Nodes (9): create_branch(), disable_branch(), enable_branch(), get_branch(), get_branch_stats(), list_branches(), _reload_cache(), update_branch() (+1 more)

### Community 67 - "sales_target"
Cohesion: 0.15
Nodes (12): copyWith, fromJson, id, incentiveAmount, isOrderCount, isRevenue, period, SalesTarget (+4 more)

### Community 68 - "home_stats_provider"
Cohesion: 0.08
Nodes (21): displayName, fromJson, id, nama, role, SalesUser, username, _errorMessage (+13 more)

### Community 69 - "suppliers_tab"
Cohesion: 0.08
Nodes (21): _activeFilter, build, _buildEmptyState, _cardList, _chip, createState, dispose, initState (+13 more)

### Community 70 - "StatefulWidget"
Cohesion: 0.10
Nodes (19): _OrderCard, AuthWrapper, CustomerRegistrationScreen, _ProductSearchSheet, _ProductSearchSheetState, HomeScreen, _QtyStepper, StepPickProducts (+11 more)

### Community 71 - "customer_submission_detail_screen"
Cohesion: 0.08
Nodes (22): _CustomerSubmissionDetailScreenState, build, children, _color, createState, _currentUsername, CustomerSubmissionDetailScreen, _CustomerSubmissionDetailScreenState (+14 more)

### Community 72 - "DashboardPage"
Cohesion: 0.18
Nodes (16): test, DashboardPage, LoginPage, gotoBulletinsTab(), gotoCrossBranchTab(), gotoSubmissionsTab(), gotoCustomersTab(), gotoOrdersTab() (+8 more)

### Community 73 - "api_service"
Cohesion: 0.08
Nodes (19): AuthInterceptor, onError, onResponse, accessToken, ApiService, _authInterceptor, clearTokens, delete (+11 more)

### Community 74 - "SceneDelegate"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 75 - "auth_repository"
Cohesion: 0.10
Nodes (18): _api, AuthRepository, _backgroundPausedAtKey, changePassword, getNama, getRefreshToken, getToken, getUsername (+10 more)

### Community 76 - "customer_repository"
Cohesion: 0.11
Nodes (16): _api, cancelSubmission, checkDuplicateCustomer, CustomerRepository, getKodeAreas, getMyCustomers, getMyCustomerSubmissions, submitCustomerRegistration (+8 more)

### Community 77 - "auth_repository"
Cohesion: 0.11
Nodes (17): accessToken, _api, AuthRepository, branch, branchNama, changePassword, isLoggedIn, login (+9 more)

### Community 78 - "supplier_target_edit_dialog"
Cohesion: 0.11
Nodes (14): build, createState, _ctrl, dispose, _formKey, initialValue, initState, period (+6 more)

### Community 79 - "Supabase Egress Reduction Plan"
Cohesion: 0.07
Nodes (28): 0. Keputusan User (locked in), 10. Phase Execution Order & Verifikasi, 11. Catatan Teknis, 1. Ringkasan & Tujuan, 2. Phase 1 — Mobile Search Debounce (HIGH impact, 1 fase), 4. Phase 3 — Backend N+1 Elimination (MEDIUM impact, 1 fase), 5. Phase 4 — Backend Connection Pool (MEDIUM impact, 1 fase), 6. Phase 5 — Excel Report Optimization (HIGH impact, 1 fase) (+20 more)

### Community 80 - "win32_window"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 82 - "models.py"
Cohesion: 0.10
Nodes (17): SyncValidationError, _bulk_upsert_customers(), _normalize(), _read_excel(), _safe_reason(), _str_or_none(), sync_customers_from_excel(), _validate_row() (+9 more)

### Community 83 - "data_card"
Cohesion: 0.11
Nodes (17): actions, badges, build, _buildActions, _buildField, _buildFields, _buildHeader, DataCard (+9 more)

### Community 84 - "order_provider"
Cohesion: 0.11
Nodes (17): cancelOrder, countByStatus, _currentSearch, _currentStatus, deleteOrder, _error, getOrderDetail, _hasMore (+9 more)

### Community 85 - "product_provider"
Cohesion: 0.12
Nodes (13): _allProducts, countByStockStatus, _error, getStockStatus, _isLoading, loadProducts, loadSuppliers4p, _orderTypeFilter (+5 more)

### Community 86 - "sync_result"
Cohesion: 0.12
Nodes (16): fileName, fromJson, importType, inserted, isStoreImport, message, needsReview, reason (+8 more)

### Community 87 - "product"
Cohesion: 0.12
Nodes (15): branch, branchNama, fromJson, harga, id, kategori, namaBarang, namaSupplier (+7 more)

### Community 89 - "product"
Cohesion: 0.12
Nodes (15): fromJson, harga, id, kategori, namaBarang, namaSupplier, orderType, perluDitinjau (+7 more)

### Community 90 - "User"
Cohesion: 0.11
Nodes (17): change_password(), register(), create_user(), delete_user(), _exclude_deleted(), list_sales_users(), list_users(), update_user() (+9 more)

### Community 91 - "api_service"
Cohesion: 0.13
Nodes (11): _accessToken, ApiService, _checkTokenExpiry, clearAccessToken, delete, _handleResponse, message, post (+3 more)

### Community 92 - "screens/login_screen.dart"
Cohesion: 0.13
Nodes (11): build, createState, dispose, _error, _formKey, _isLoading, _login, LoginScreen (+3 more)

### Community 93 - "api_service"
Cohesion: 0.13
Nodes (11): _accessToken, ApiService, _checkTokenExpiry, clearAccessToken, delete, _handleResponse, message, post (+3 more)

### Community 94 - "main"
Cohesion: 0.13
Nodes (8): AdminApp, build, initializeDateFormatting, initialTokens, main, null, storage, tokens

### Community 95 - "e2e/package.json"
Cohesion: 0.10
Nodes (19): @types/node, typescript, description, devDependencies, @playwright/test, @types/node, typescript, name (+11 more)

### Community 96 - "auth_storage"
Cohesion: 0.13
Nodes (12): _accessKey, AuthStorage, _branchKey, _branchNamaKey, clearTokens, getTokens, _namaKey, _refreshKey (+4 more)

### Community 97 - "branch"
Cohesion: 0.13
Nodes (13): all, banjarmasin, barabai, batulicin, BranchCode, BranchLabel, display, isValid (+5 more)

### Community 98 - "branch"
Cohesion: 0.13
Nodes (13): all, banjarmasin, barabai, batulicin, BranchCode, BranchLabel, display, isValid (+5 more)

### Community 99 - "product"
Cohesion: 0.13
Nodes (14): fromJson, harga, id, kategori, namaBarang, namaSupplier, orderType, perluDitinjau (+6 more)

### Community 100 - "ProductsTabPage"
Cohesion: 0.12
Nodes (3): EditProductDialog, ProductsTabPage, UbahStokDialog

### Community 101 - "OrdersTabPage"
Cohesion: 0.15
Nodes (6): 3. Phase 2 — Admin Web Debounce + Stop Refetch on Mutation (HIGH impact, 1 fase), Task 2.1 — Tambah `Debouncer` di admin_web, Task 2.2 — Debounce `orders_tab` search, Task 2.3 — Stop `loadAll()` di `approveOrder/rejectOrder/cancelOrderItem`, Task 2.4 — Skip auto-refresh saat tab tersembunyi, OrdersTabPage

### Community 102 - "change_password_dialog"
Cohesion: 0.14
Nodes (12): authProvider, build, ChangePasswordDialog, _confirmC, createState, dispose, _errSnack, _newC (+4 more)

### Community 103 - "SuppliersTabPage"
Cohesion: 0.12
Nodes (3): SupplierDialog, SuppliersTabPage, UbahTipeOrderDialog

### Community 104 - "branch_report"
Cohesion: 0.14
Nodes (13): approvedCount, approvedRevenue, branch, branchNama, BranchSalesSummary, BranchStockSummary, customerCount, fromJson (+5 more)

### Community 105 - "customer"
Cohesion: 0.14
Nodes (13): alamat, branch, branchNama, createdAt, Customer, deletedAt, fromJson, id (+5 more)

### Community 106 - "branch"
Cohesion: 0.14
Nodes (13): all, banjarmasin, barabai, batulicin, BranchCode, BranchLabel, display, isValid (+5 more)

### Community 107 - "utils"
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 108 - "order_repository"
Cohesion: 0.15
Nodes (11): _api, cancelOrder, createOrder, deleteOrder, getMyOrders, getMyStats, getOrderDetail, OrderRepository (+3 more)

### Community 109 - "sales_targets"
Cohesion: 0.24
Nodes (3): get_my_target(), list_sales_targets(), upsert_sales_target()

### Community 110 - "test_egress_optimizations.py"
Cohesion: 0.14
Nodes (13): _auth(), captured_statements(), _cleanup(), _count(), _seed_bulletin(), _seed_customer(), _seed_product(), _seed_user() (+5 more)

### Community 111 - "config"
Cohesion: 0.15
Nodes (12): accessTokenKey, AppConfig, baseUrl, refreshTokenKey, requestTimeout, tokenKey, userBranchKey, userBranchNamaKey (+4 more)

### Community 112 - "auth_provider"
Cohesion: 0.18
Nodes (10): AuthProvider, BulletinProvider, DraftOrderProvider, OrderProvider, ProductProvider, AuthProvider, DraftOrderProvider, HomeStatsProvider (+2 more)

### Community 113 - "bulletin"
Cohesion: 0.17
Nodes (11): branch, branchNama, Bulletin, createdAt, description, expireAt, fromJson, id (+3 more)

### Community 114 - "customer"
Cohesion: 0.17
Nodes (11): alamat, createdAt, Customer, deletedAt, fromJson, id, kode, kodeArea (+3 more)

### Community 115 - "jwt_utils"
Cohesion: 0.12
Nodes (13): _base64UrlDecode, decodePayload, isExpired, JwtUtils, _base64UrlDecode, decodePayload, getExpiry, isExpired (+5 more)

### Community 117 - "admin_web/lib/core/datetime_utils.dart"
Cohesion: 0.07
Nodes (26): _bulanIndonesia, day, hour, minute, monthName, monthNum, parseWitaIso, parseWitaIsoOrNull (+18 more)

### Community 118 - "win32_window"
Cohesion: 0.13
Nodes (7): FlutterWindow, flutter_controller_, project_, Win32Window, child_content_, quit_on_close_, window_handle_

### Community 119 - "user_item"
Cohesion: 0.18
Nodes (10): branch, branchNama, displayName, fromJson, id, isActive, nama, role (+2 more)

### Community 120 - "manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 121 - "config"
Cohesion: 0.18
Nodes (9): AppConfig, baseUrl, refreshTokenKey, requestTimeout, tokenKey, userIdKey, userNamaKey, userRoleKey (+1 more)

### Community 122 - "bulletin"
Cohesion: 0.20
Nodes (9): Bulletin, createdAt, description, expireAt, fromJson, id, isRead, pdfUrl (+1 more)

### Community 123 - "manifest"
Cohesion: 0.20
Nodes (9): background_color, description, display, icons, name, orientation, short_name, start_url (+1 more)

### Community 125 - "supplier_performance"
Cohesion: 0.22
Nodes (7): fromJson, hasTarget, pencapaian, supplierName, SupplierPerformanceRow, target, value

### Community 126 - "List"
Cohesion: 0.11
Nodes (12): actions, build, leading, PageHeader, subtitle, title, CustomerProvider, _customerRepo (+4 more)

### Community 127 - "supplier"
Cohesion: 0.11
Nodes (15): assignedAt, fromJson, SalesAssignment, salesId, salesNama, salesUsername, createdAt, fromJson (+7 more)

### Community 128 - "supplier_target"
Cohesion: 0.22
Nodes (8): branch, fromJson, id, period, supplierName, SupplierTarget, targetValue, toJson

### Community 129 - "api_exception"
Cohesion: 0.13
Nodes (13): ApiException, ApiException, data, isConflict, isForbidden, isNotFound, isUnauthorized, message (+5 more)

### Community 130 - "step_pick_order_type.dart"
Cohesion: 0.09
Nodes (20): build, ErrorState, icon, message, onRetry, title, build, createState (+12 more)

### Community 131 - "railway"
Cohesion: 0.25
Nodes (7): build, dockerfilePath, deploy, numReplicas, restartPolicyLimit, restartPolicyType, $schema

### Community 132 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 134 - "test_reports_summary.py"
Cohesion: 0.18
Nodes (12): _cleanup(), _seed_customer(), _seed_order(), _seed_order_item(), _seed_product(), _seed_user(), test_summary_aggregates_correctly(), test_summary_branch_scoped_for_supervisor() (+4 more)

### Community 135 - "uuid"
Cohesion: 0.20
Nodes (8): get_valid_branch_codes(), _best_ms(), _cleanup(), _seed_customer(), _seed_dataset(), _seed_product(), _seed_user(), test_cross_branch_endpoints_under_500ms_with_1000_orders()

### Community 136 - "list_sales_customers"
Cohesion: 0.20
Nodes (6): list_area_assignment_detail(), list_area_assignments(), _list_area_assignments(), list_sales_customers(), put_area_assignment(), SalesAssignmentItem

### Community 137 - "api_exception"
Cohesion: 0.40
Nodes (3): message, statusCode, toString

### Community 138 - "package"
Cohesion: 0.50
Nodes (3): firebase, dependencies, firebase

### Community 142 - "test_suppliers_list.py"
Cohesion: 0.30
Nodes (11): _cleanup(), _cleanup_suppliers(), _cleanup_users(), _make_user(), _seed(), _seed_other_branch(), test_manager_product_count_is_global(), test_supervisor_product_count_excludes_other_branches() (+3 more)

### Community 145 - "sales_web/lib/presentation/screens/auth/change_password_dialog.dart"
Cohesion: 0.12
Nodes (15): build, _buildPasswordField, ChangePasswordDialog, _confirmController, createState, _currentController, dispose, _error (+7 more)

### Community 146 - "screens/change_password_dialog.dart"
Cohesion: 0.13
Nodes (12): adminRepository, build, ChangePasswordDialog, _confirmC, createState, dispose, _errSnack, _newC (+4 more)

### Community 147 - "admin_provider_supplier_test.dart"
Cohesion: 0.09
Nodes (18): AdminRepository, createSupplier, failWith, _FakeAdminRepository, getSuppliers, main, suppliers, updateSupplierActive (+10 more)

### Community 148 - "migrate_supabase.py"
Cohesion: 0.21
Nodes (6): export_all(), export_table(), import_all(), import_table(), main(), verify()

### Community 149 - "web_download_web.dart"
Cohesion: 0.13
Nodes (7): triggerBrowserDownload, triggerBrowserDownload, anchor, blob, blobParts, triggerBrowserDownload, url

### Community 150 - "stat_tile.dart"
Cohesion: 0.14
Nodes (12): build, color, icon, label, onTap, StatTile, text, trend (+4 more)

### Community 151 - "responsive_dialog.dart"
Cohesion: 0.14
Nodes (12): actions, build, child, content, contentMaxWidth, desktopWidthFraction, maxHeight, maxWidth (+4 more)

### Community 152 - "test_products_supplier_filter.py"
Cohesion: 0.42
Nodes (9): _cleanup(), _make_user(), _seed(), test_admin_sees_all_products_regardless_of_supplier(), test_manager_sees_all_products_regardless_of_supplier(), test_sales_sees_only_active_or_null_supplier(), test_supervisor_sees_all_products_regardless_of_supplier(), test_toggling_supplier_hides_product_from_sales_on_refetch() (+1 more)

### Community 155 - "test_reports_detail_param.py"
Cohesion: 0.33
Nodes (8): _cleanup(), _seed_one_order(), _seed_user(), test_daily_default_returns_summary_json(), test_daily_with_detail_returns_xlsx(), test_period_default_returns_summary_json(), test_period_with_detail_returns_xlsx(), _token()

### Community 156 - "create_access_token"
Cohesion: 0.25
Nodes (6): login(), refresh_token(), create_access_token(), create_refresh_token(), decode_token(), get_current_user()

### Community 173 - "compilerOptions"
Cohesion: 0.14
Nodes (13): compilerOptions, esModuleInterop, module, moduleResolution, outDir, resolveJsonModule, rootDir, skipLibCheck (+5 more)

### Community 174 - "list_suppliers"
Cohesion: 0.16
Nodes (10): create_supplier(), list_suppliers(), update_supplier_active(), update_supplier_order_type(), SupplierActiveUpdate, SupplierCreate, SupplierResponse, test_supplier_active_update_requires_bool() (+2 more)

### Community 175 - "Architecting Flutter Applications"
Cohesion: 0.15
Nodes (12): Architecting Flutter Applications, Architectural Layers, Contents, Data Layer, Data Layer: Service and Repository, Examples, Logic Layer (Domain - Optional), Project Structure (+4 more)

### Community 176 - "Sales Order App"
Cohesion: 0.15
Nodes (12): Admin Web, Arsitektur Singkat, Backend, Catatan Deployment, Endpoint API Utama, Mobile, Roles & Permission, Sales Order App (+4 more)

### Community 179 - "package:flutter/foundation.dart"
Cohesion: 0.20
Nodes (6): call, cancel, Debouncer, delay, dispose, _timer

### Community 180 - "sales_web/lib/data/models/bulletin.dart"
Cohesion: 0.20
Nodes (9): Bulletin, createdAt, description, expireAt, fromJson, id, isRead, pdfUrl (+1 more)

### Community 181 - "sales_web/lib/data/models/customer.dart"
Cohesion: 0.20
Nodes (9): alamat, createdAt, Customer, fromJson, id, kode, kodeArea, namaToko (+1 more)

### Community 182 - "bool get"
Cohesion: 0.22
Nodes (7): isForbidden, isNotFound, isServerError, isUnauthorized, message, statusCode, toString

### Community 186 - "test_suppliers_create.py"
Cohesion: 0.53
Nodes (8): _cleanup(), _cleanup_suppliers(), _cleanup_users(), _make_user(), test_post_suppliers_as_manager_creates_row(), test_post_suppliers_duplicate_returns_409(), test_post_suppliers_rejects_non_manager(), _token()

### Community 189 - "Admin Web E2E Test Suite"
Cohesion: 0.29
Nodes (6): Admin Web E2E Test Suite, Environment Variables, Running Tests, Setup, Test Structure, Writing New Tests

### Community 192 - "test_suppliers_toggle.py"
Cohesion: 0.53
Nodes (8): _cleanup(), _cleanup_suppliers(), _cleanup_users(), _make_user(), test_patch_active_404_for_missing(), test_patch_active_as_manager_toggles(), test_patch_active_rejects_admin(), _token()

### Community 195 - "test_migration_idempotent_preserves_toggle.py"
Cohesion: 0.38
Nodes (3): _cleanup(), _seed_product(), test_migration_idempotent_preserves_toggle()

### Community 196 - "bulletin_pdf_picker_stub.dart"
Cohesion: 0.33
Nodes (4): bytes, name, PickedPdf, pickPdfFile

## Knowledge Gaps
- **2720 isolated node(s):** `message`, `statusCode`, `toString`, `onResponse`, `onError` (+2715 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3633 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **40 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Order` connect `Backend Order Endpoints` to `Backend Auth Endpoints`, `OrdersTabPage`, `Backend Product Endpoints`, `reports.py`, `customer_submissions.py`?**
  _High betweenness centrality (0.149) - this node is a cross-community bridge._
- **What connects `message`, `statusCode`, `toString` to the rest of the system?**
  _2720 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AdminProvider State Hub` be split into smaller, more focused modules?**
  _Cohesion score 0.0106951871657754 - nodes in this community are weakly interconnected._
- **Why does `Task 2.3 — Stop `loadAll()` di `approveOrder/rejectOrder/cancelOrderItem`` connect `OrdersTabPage` to `Backend Order Endpoints`?**
  _High betweenness centrality (0.147) - this node is a cross-community bridge._
- **Should `Sales App Home Screens` be split into smaller, more focused modules?**
  _Cohesion score 0.037650113599480686 - nodes in this community are weakly interconnected._
- **Why does `OrdersTabPage` connect `OrdersTabPage` to `@playwright/test`, `DashboardPage`, `BasePage`?**
  _High betweenness centrality (0.145) - this node is a cross-community bridge._
- **Should `Admin Stats Tab` be split into smaller, more focused modules?**
  _Cohesion score 0.019044260271557045 - nodes in this community are weakly interconnected._