# Graph Report - Project-magang  (2026-10-20)

## Corpus Check
- 287 files · ~991,030 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 48 file(s) not represented in the graph (top: (none) 16, .xml 7, .plist 4)

## Summary
- 4943 nodes · 8012 edges · 195 communities (145 shown, 50 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 338 edges (avg confidence: 0.93)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1dc057a6`
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
- CustomerSubmissionCreate
- customers_tab
- web_auth_storage
- main
- confirm_dialog
- storage.py
- login_screen
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
- OrderProvider
- Sales App Order Repository
- Mobile Order Detail
- @playwright/test
- Data Repositories
- my_submissions_screen
- Orders Provider
- 4. Per-Screen Responsive Adaptations
- Customer Submission Endpoints
- bulletin_provider
- Cross-Branch Reports Tab
- Sales Performance Model
- customer_submission_detail_screen
- branches
- sales_target
- home_stats_provider
- suppliers_tab
- State
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
- customer_sync
- data_card
- order_provider
- product_provider
- sync_result
- product
- BasePage
- product
- change_password_dialog
- api_service
- screens/change_password_dialog.dart
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
- supplier_targets
- config
- auth_provider
- bulletin
- customer
- jwt_utils
- datetime_utils
- win32_window
- user_item
- manifest
- config
- bulletin
- manifest
- win32_window
- supplier_performance
- String? get
- supplier
- supplier_target
- api_exception
- sales_assignment
- railway
- Point
- generated_plugin_registrant
- api_exception
- auth_interceptor
- jwt_utils
- api_exception
- package
- config
- MainActivity
- vercel
- orders_tab
- orders_tab
- orders_tab
- orders_tab
- orders_tab
- penugasan_sales_tab
- penugasan_sales_tab
- penugasan_sales_tab
- penugasan_sales_tab
- penugasan_sales_tab
- stats_tab
- stats_tab
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
- supplier_create_dialog.dart
- SubmissionDetailPage
- StatsTabPage
- Admin Web E2E Test Suite
- MultiSelectSalesDialog
- ChangePasswordDialog
- Size
- CLAUDE.md
- LaunchImage.imageset/README.md

## God Nodes (most connected - your core abstractions)
1. `============================================================` - 163 edges
2. `AdminProvider` - 96 edges
3. `BaseSchema` - 68 edges
4. `BasePage` - 51 edges
5. `Product` - 47 edges
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
- `initState` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart
- `_showDeleteDialog` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart

## Import Cycles
- None detected.

## Communities (195 total, 50 thin omitted)

### Community 0 - "AdminProvider State Hub"
Cohesion: 0.01
Nodes (180): _activeTabIndex, adminRepository, AdminState, _allOrders, approveCustomerSubmission, approveOrder, bulletins, _bulletinsCacheTime (+172 more)

### Community 1 - "Sales App Home Screens"
Cohesion: 0.04
Nodes (51): _animation, _BerandaTab, _BerandaTabState, color, _controller, createState, currency, _currentIndex (+43 more)

### Community 2 - "Admin Stats Tab"
Cohesion: 0.02
Nodes (100): aggregateDashboardPerformance, _applyFilters, approvedMtdCount, approvedMtdRevenue, approvedTodayCount, approvedTodayRevenue, branch, _branchFilter (+92 more)

### Community 3 - "Backend Auth Endpoints"
Cohesion: 0.04
Nodes (43): change_password(), login(), refresh_token(), register(), disable_branch(), _reload_cache(), _build_bulletin_response(), expire_bulletins() (+35 more)

### Community 4 - "Backend Pydantic Schemas"
Cohesion: 0.04
Nodes (71): BaseSchema, BranchBase, BranchCreate, BranchResponse, Config, BranchSalesSummary, BranchStatsResponse, BranchStockSummary (+63 more)

### Community 5 - "Admin API Repositories"
Cohesion: 0.02
Nodes (70): _api, approveCustomerSubmission, approveOrder, cancelOrderItems, changePassword, clearImportErrors, clearTokens, createBulletin (+62 more)

### Community 6 - "Sales Web Order Flow UI"
Cohesion: 0.03
Nodes (78): _activeLayersSummary, _bsDetailRow, _buildBottomBar, _buildStepContent, _calcPreview, _chip, color, _commit (+70 more)

### Community 7 - "Backend Order Endpoints"
Cohesion: 0.09
Nodes (33): _apply_3_layers(), approve_order(), _book_items(), _build_order_response(), cancel_order(), cancel_order_items(), create_order(), delete_draft_order() (+25 more)

### Community 8 - "Admin Orders Tab"
Cohesion: 0.03
Nodes (74): _applyFilters, _buildAllOrders, _buildPendingOrders, _buildPriceSummary, _CancelItemResult, canEdit, controller, createState (+66 more)

### Community 9 - "Backend Product Endpoints"
Cohesion: 0.07
Nodes (33): clear_import_errors(), delete_product(), _get_4p_suppliers(), get_admin_stats(), get_import_logs(), get_kategori_list(), get_product(), get_product_count() (+25 more)

### Community 10 - "Backend Customer Endpoints"
Cohesion: 0.08
Nodes (29): create_customer(), _customer_to_response(), delete_customer(), _exclude_deleted(), get_customer(), get_customer_count(), import_excel(), _list_assignments() (+21 more)

### Community 11 - "Order Flow Review Step"
Cohesion: 0.03
Nodes (62): _actionIconBtn, _activeLayersSummary, _AddLineSheet, _AddLineSheetState, _buildDiscount, _calcPreview, _chip, color (+54 more)

### Community 12 - "Customer Registration Form"
Cohesion: 0.03
Nodes (64): _alamatKirimCtl, _alamatKtpCtl, _areaCtl, _barengOrder, _batasKreditCtl, _buildPayload, _channelKategori, _channelOptions (+56 more)

### Community 13 - "Admin Design System"
Cohesion: 0.03
Nodes (63): AppCard, AppColors, AppTextStyles, AppTheme, available, background, bodyLarge, bodyMedium (+55 more)

### Community 14 - "Sales Web Order Models"
Cohesion: 0.03
Nodes (62): CancelledItem, cancelledItems, canDelete, canEdit, createdAt, customerId, customerName, cutFrom (+54 more)

### Community 15 - "Shared UI Widget Classes"
Cohesion: 0.04
Nodes (61): _EmptyState, _StatCard, _SubmissionsList, _NavPanel, _LayerField, _OrderItemRow, _BranchPerformanceCard, _PeriodReportCard (+53 more)

### Community 16 - "Draft Order Provider"
Cohesion: 0.03
Nodes (60): addLine, _applyItemLayers, buildItemsPayload, copyWith, customerAddress, customerId, customerName, cutFrom (+52 more)

### Community 17 - "Mobile Design System"
Cohesion: 0.03
Nodes (57): AppColors, AppTextStyles, AppTheme, available, background, bodyLarge, bodyMedium, bodySmall (+49 more)

### Community 18 - "Mobile Order Flow"
Cohesion: 0.05
Nodes (46): _back, _backFromProducts, build, _confirmCancel, _connector, createState, currentStep, _dot (+38 more)

### Community 19 - "customer_submission"
Cohesion: 0.04
Nodes (55): alamatKirim, alamatKtp, approvedCustomerId, areaRoute, batasKreditRupiah, branch, branchNama, channelKategori (+47 more)

### Community 20 - "misc_screen"
Cohesion: 0.05
Nodes (42): build, bulletin, _BulletinCard, BulletinScreen, _BulletinScreenState, createState, initState, onTap (+34 more)

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
Nodes (35): accessToken, _adminProvider, _apiService, branch, branchNama, _buildBody, _checkIdle, createState (+27 more)

### Community 25 - "order"
Cohesion: 0.04
Nodes (52): branch, branchNama, CancelledItem, cancelledItems, copyWith, createdAt, customerId, customerKode (+44 more)

### Community 26 - "sync_tab"
Cohesion: 0.05
Nodes (40): align, build, _buildDesktopTable, _buildErrorTile, _buildMobileList, _clearErrors, color, createState (+32 more)

### Community 27 - "design_system"
Cohesion: 0.04
Nodes (46): AppColors, AppTextStyles, AppTheme, available, background, _bg, bodyLarge, bodyMedium (+38 more)

### Community 28 - "customer_registration_screen"
Cohesion: 0.04
Nodes (48): _alamatKirimCtl, _alamatKtpCtl, _areaCtl, _barengOrder, _batasKreditCtl, build, _buildPayload, _channelKategori (+40 more)

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.03
Nodes (44): rootNavigatorKey, actions, build, child, content, contentMaxWidth, desktopWidthFraction, maxHeight (+36 more)

### Community 30 - "penugasan_sales_tab"
Cohesion: 0.05
Nodes (40): _allCustomers, _allSalesUsers, _allUsers, area, _areaAssignments, _AreaRow, areas, _AssignmentChip (+32 more)

### Community 31 - "users_tab"
Cohesion: 0.05
Nodes (40): active, _branch, _BranchChip, build, _buildCardList, _buildHeader, _buildRow, _buildTable (+32 more)

### Community 32 - "order"
Cohesion: 0.05
Nodes (42): CancelledItem, cancelledItems, canDelete, canEdit, createdAt, customerId, customerName, discount2Nominal (+34 more)

### Community 34 - "customers_tab"
Cohesion: 0.05
Nodes (38): _alamatC, build, _buildCardList, _buildError, _buildFooter, _buildForm, _buildHeader, _buildRow (+30 more)

### Community 35 - "web_auth_storage"
Cohesion: 0.05
Nodes (29): triggerBrowserDownload, triggerBrowserDownload, anchor, blob, blobParts, triggerBrowserDownload, url, bytes (+21 more)

### Community 36 - "main"
Cohesion: 0.06
Nodes (25): _apiService, _authRepo, AuthWrapper, _AuthWrapperState, _backgroundTimeout, _checking, createState, didChangeAppLifecycleState (+17 more)

### Community 37 - "confirm_dialog"
Cohesion: 0.07
Nodes (24): build, _CancelButton, _ConfirmButton, ConfirmDialog, InfoDialog, isDestructive, label, onPressed (+16 more)

### Community 38 - "storage.py"
Cohesion: 0.08
Nodes (18): _assert_bulletin_visible(), bulletin_upload_pdf(), create_bulletin(), delete_bulletin(), dismiss_bulletin(), list_bulletins(), update_bulletin(), delete_file() (+10 more)

### Community 39 - "login_screen"
Cohesion: 0.07
Nodes (27): build, _checkAuth, _checkBackgroundTimeout, build, createState, dispose, _formKey, _handleLogin (+19 more)

### Community 40 - "customer_submissions_tab"
Cohesion: 0.04
Nodes (55): AdminProvider, active, _changeFilter, color, count, createState, CustomerSubmissionsTab, _CustomerSubmissionsTabState (+47 more)

### Community 41 - "auth_provider"
Cohesion: 0.06
Nodes (30): _authRepo, AuthState, changeOwnPassword, checkLoginStatus, _errorMessage, forceLogout, getToken, isAuthenticated (+22 more)

### Community 42 - "performance_tab"
Cohesion: 0.06
Nodes (30): align, build, _buildLeaderboard, _buildPeriodFilterSection, _buildSectionTitle, _buildSupplierPerformanceTable, _buildTargetSection, child (+22 more)

### Community 43 - "reports.py"
Cohesion: 0.05
Nodes (30): _build_daily_xlsx(), _build_report(), cross_branch_sales_summary(), cross_branch_stock_summary(), daily_report(), get_supplier_performance(), _layer_cut_value(), period_report() (+22 more)

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
Cohesion: 0.07
Nodes (27): _animation, available, _controller, createState, _detailRow, didUpdateWidget, disabled, dispose (+19 more)

### Community 48 - "action_button_row"
Cohesion: 0.04
Nodes (50): ActionButton, ActionButtonRow, actions, alignment, build, _buildButton, destructive, icon (+42 more)

### Community 49 - "product_provider"
Cohesion: 0.06
Nodes (30): _allProducts, _categoryFilter, clearFilters, clearSearch, countByStatus, countByStatusAll, dispose, _errorMessage (+22 more)

### Community 50 - "Admin Bulletins Tab"
Cohesion: 0.07
Nodes (22): completer, input, onChange, pickPdfFile, build, bulletin, _BulletinCard, BulletinsTab (+14 more)

### Community 51 - "step_pick_customer.dart"
Cohesion: 0.05
Nodes (33): build, _controller, createState, dispose, height, initState, label, LoadingState (+25 more)

### Community 52 - "============================================================"
Cohesion: 0.01
Nodes (162): ============================================================, ----------------------------------------, ----------------------------------------, ----------------------------------------, ============================================================, ============================================================, ----------------------------------------, ---------------------------------------- (+154 more)

### Community 53 - "OrderProvider"
Cohesion: 0.03
Nodes (66): build, _maybeShowBulletinPopup, build, build, build, _HomeScreenState, _openOrderFlow, build (+58 more)

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
Cohesion: 0.07
Nodes (27): _buildBody, createState, _error, _formatDate, initState, _loading, MySubmissionsScreen, _MySubmissionsScreenState (+19 more)

### Community 59 - "Orders Provider"
Cohesion: 0.08
Nodes (22): _activeStatusFilter, cancelOrder, clearMessages, countByStatus, createOrder, deleteOrder, _errorMessage, getOrderDetail (+14 more)

### Community 60 - "4. Per-Screen Responsive Adaptations"
Cohesion: 0.05
Nodes (37): 0. Keputusan User (locked in), 1. Ringkasan & Tujuan, 2.1 Breakpoints, 2.2 Layout Strategy, 2.3 Dialog & Bottom Sheet Strategy, 2.4 Typography & Spacing, 2. Target Responsive Design System, 3. Reusable Component Library (+29 more)

### Community 61 - "Customer Submission Endpoints"
Cohesion: 0.17
Nodes (9): approve_submission(), cancel_submission(), check_duplicate_customer(), get_submission(), list_my_submissions(), list_submissions(), reject_submission(), _serialize() (+1 more)

### Community 62 - "bulletin_provider"
Cohesion: 0.07
Nodes (23): build, FilterBar, filters, search, trailing, BulletinProvider, _bulletins, dismissBulletin (+15 more)

### Community 63 - "Cross-Branch Reports Tab"
Cohesion: 0.09
Nodes (21): build, _buildEmpty, _buildSalesCard, _buildSalesTab, _buildStatChip, _buildStockCard, _buildStockTab, _buildTotalCard (+13 more)

### Community 64 - "Sales Performance Model"
Cohesion: 0.08
Nodes (23): approvedMtdCount, approvedMtdRevenue, approvedTodayCount, approvedTodayRevenue, branch, displayName, fromJson, nama (+15 more)

### Community 65 - "customer_submission_detail_screen"
Cohesion: 0.06
Nodes (28): _confirmSubmit, initState, _submit, children, _color, createState, _currentRole, _currentUsername (+20 more)

### Community 66 - "branches"
Cohesion: 0.18
Nodes (7): create_branch(), enable_branch(), get_branch(), get_branch_stats(), list_branches(), update_branch(), Branch

### Community 67 - "sales_target"
Cohesion: 0.15
Nodes (12): copyWith, fromJson, id, incentiveAmount, isOrderCount, isRevenue, period, SalesTarget (+4 more)

### Community 68 - "home_stats_provider"
Cohesion: 0.11
Nodes (14): _errorMessage, HomeStatsProvider, isLoading, load, _loading, _orderRepository, refresh, _stats (+6 more)

### Community 69 - "suppliers_tab"
Cohesion: 0.08
Nodes (21): _activeFilter, build, _buildEmptyState, _cardList, _chip, createState, dispose, initState (+13 more)

### Community 70 - "State"
Cohesion: 0.06
Nodes (42): _ChangePasswordDialogState, _CustomerDetailDialog, _CustomerDetailDialogState, DashboardScreen, _DashboardScreenState, _OrderCard, _UserEditDialog, _UserEditDialogState (+34 more)

### Community 71 - "customer_submission_detail_screen"
Cohesion: 0.09
Nodes (20): build, children, _color, createState, _currentUsername, CustomerSubmissionDetailScreen, _fmtNumber, _formatDate (+12 more)

### Community 72 - "DashboardPage"
Cohesion: 0.18
Nodes (16): test, DashboardPage, LoginPage, gotoBulletinsTab(), gotoCrossBranchTab(), gotoSubmissionsTab(), gotoCustomersTab(), gotoOrdersTab() (+8 more)

### Community 73 - "api_service"
Cohesion: 0.10
Nodes (16): accessToken, ApiService, _authInterceptor, clearTokens, delete, _dio, _handleError, hasToken (+8 more)

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

### Community 81 - "flutter_window"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 82 - "customer_sync"
Cohesion: 0.18
Nodes (7): _bulk_upsert_customers(), _normalize(), _read_excel(), _safe_reason(), _str_or_none(), sync_customers_from_excel(), _validate_row()

### Community 83 - "data_card"
Cohesion: 0.07
Nodes (21): actions, badges, build, _buildActions, _buildField, _buildFields, _buildHeader, DataCard (+13 more)

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

### Community 90 - "change_password_dialog"
Cohesion: 0.12
Nodes (15): build, _buildPasswordField, ChangePasswordDialog, _confirmController, createState, _currentController, dispose, _error (+7 more)

### Community 91 - "api_service"
Cohesion: 0.13
Nodes (11): _accessToken, ApiService, _checkTokenExpiry, clearAccessToken, delete, _handleResponse, message, post (+3 more)

### Community 92 - "screens/change_password_dialog.dart"
Cohesion: 0.06
Nodes (24): adminRepository, build, ChangePasswordDialog, _confirmC, createState, dispose, _errSnack, _newC (+16 more)

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
Cohesion: 0.19
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 108 - "order_repository"
Cohesion: 0.15
Nodes (11): _api, cancelOrder, createOrder, deleteOrder, getMyOrders, getMyStats, getOrderDetail, OrderRepository (+3 more)

### Community 109 - "sales_targets"
Cohesion: 0.24
Nodes (3): get_my_target(), list_sales_targets(), upsert_sales_target()

### Community 110 - "supplier_targets"
Cohesion: 0.22
Nodes (3): delete_supplier_target(), list_supplier_targets(), upsert_supplier_target()

### Community 111 - "config"
Cohesion: 0.15
Nodes (12): accessTokenKey, AppConfig, baseUrl, refreshTokenKey, requestTimeout, tokenKey, userBranchKey, userBranchNamaKey (+4 more)

### Community 112 - "auth_provider"
Cohesion: 0.20
Nodes (9): AuthProvider, DraftOrderProvider, OrderProvider, ProductProvider, AuthProvider, DraftOrderProvider, HomeStatsProvider, OrderProvider (+1 more)

### Community 113 - "bulletin"
Cohesion: 0.17
Nodes (11): branch, branchNama, Bulletin, createdAt, description, expireAt, fromJson, id (+3 more)

### Community 114 - "customer"
Cohesion: 0.17
Nodes (11): alamat, createdAt, Customer, deletedAt, fromJson, id, kode, kodeArea (+3 more)

### Community 115 - "jwt_utils"
Cohesion: 0.18
Nodes (8): _base64UrlDecode, decodePayload, isExpired, JwtUtils, decodePayload, getExpiryDate, isExpired, JwtUtils

### Community 117 - "datetime_utils"
Cohesion: 0.18
Nodes (7): toWita, WitaDateTime, witaFormat, toWita, WitaDateTime, witaFormat, witaFormat

### Community 118 - "win32_window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

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

### Community 126 - "String? get"
Cohesion: 0.11
Nodes (13): displayName, fromJson, id, nama, role, SalesUser, username, CustomerProvider (+5 more)

### Community 127 - "supplier"
Cohesion: 0.20
Nodes (9): createdAt, fromJson, isActive, name, orderType, productCount, Supplier, toJson (+1 more)

### Community 128 - "supplier_target"
Cohesion: 0.22
Nodes (8): branch, fromJson, id, period, supplierName, SupplierTarget, targetValue, toJson

### Community 129 - "api_exception"
Cohesion: 0.22
Nodes (8): data, isConflict, isForbidden, isNotFound, isUnauthorized, message, statusCode, toString

### Community 130 - "sales_assignment"
Cohesion: 0.25
Nodes (6): assignedAt, fromJson, SalesAssignment, salesId, salesNama, salesUsername

### Community 131 - "railway"
Cohesion: 0.25
Nodes (7): build, dockerfilePath, deploy, numReplicas, restartPolicyLimit, restartPolicyType, $schema

### Community 132 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 134 - "api_exception"
Cohesion: 0.33
Nodes (5): ApiException, ApiException, TokenExpiredException, ApiException, TokenExpiredException

### Community 135 - "auth_interceptor"
Cohesion: 0.33
Nodes (3): AuthInterceptor, onError, onResponse

### Community 136 - "jwt_utils"
Cohesion: 0.33
Nodes (5): _base64UrlDecode, decodePayload, getExpiry, isExpired, JwtUtils

### Community 137 - "api_exception"
Cohesion: 0.40
Nodes (3): message, statusCode, toString

### Community 138 - "package"
Cohesion: 0.50
Nodes (3): firebase, dependencies, firebase

### Community 173 - "compilerOptions"
Cohesion: 0.14
Nodes (13): compilerOptions, esModuleInterop, module, moduleResolution, outDir, resolveJsonModule, rootDir, skipLibCheck (+5 more)

### Community 174 - "list_suppliers"
Cohesion: 0.22
Nodes (5): create_supplier(), list_suppliers(), update_supplier_active(), update_supplier_order_type(), SupplierResponse

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

### Community 186 - "supplier_create_dialog.dart"
Cohesion: 0.25
Nodes (6): formKey, name, nameController, orderType, showSupplierCreateDialog, SupplierCreateResult

### Community 189 - "Admin Web E2E Test Suite"
Cohesion: 0.29
Nodes (6): Admin Web E2E Test Suite, Environment Variables, Running Tests, Setup, Test Structure, Writing New Tests

### Community 192 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

## Knowledge Gaps
- **2697 isolated node(s):** `message`, `statusCode`, `toString`, `onResponse`, `onError` (+2692 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3558 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **50 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Order` connect `Backend Order Endpoints` to `Backend Auth Endpoints`, `OrdersTabPage`, `Backend Product Endpoints`, `reports.py`, `Customer Submission Endpoints`?**
  _High betweenness centrality (0.140) - this node is a cross-community bridge._
- **What connects `message`, `statusCode`, `toString` to the rest of the system?**
  _2697 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AdminProvider State Hub` be split into smaller, more focused modules?**
  _Cohesion score 0.0106951871657754 - nodes in this community are weakly interconnected._
- **Why does `Task 2.3 — Stop `loadAll()` di `approveOrder/rejectOrder/cancelOrderItem`` connect `OrdersTabPage` to `Backend Order Endpoints`?**
  _High betweenness centrality (0.140) - this node is a cross-community bridge._
- **Should `Sales App Home Screens` be split into smaller, more focused modules?**
  _Cohesion score 0.04038461538461539 - nodes in this community are weakly interconnected._
- **Why does `OrdersTabPage` connect `OrdersTabPage` to `@playwright/test`, `DashboardPage`, `BasePage`?**
  _High betweenness centrality (0.138) - this node is a cross-community bridge._
- **Should `Admin Stats Tab` be split into smaller, more focused modules?**
  _Cohesion score 0.019230769230769232 - nodes in this community are weakly interconnected._