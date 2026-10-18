# Graph Report - Project-magang  (2026-10-17)

## Corpus Check
- 273 files · ~164,815 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 47 file(s) not represented in the graph (top: (none) 15, .xml 7, .plist 4)

## Summary
- 4315 nodes · 6992 edges · 171 communities (136 shown, 35 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 283 edges (avg confidence: 0.94)
- Token cost: 0 input · 0 output

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
- supplier_create_dialog
- penugasan_sales_tab
- users_tab
- order
- bulletin
- customers_tab
- web_auth_storage
- main
- confirm_dialog
- bulletins
- login_screen
- customer_submissions_tab
- auth_provider
- performance_tab
- reports
- responsive
- product_catalog_screen
- products_tab
- step_pick_products
- action_button_row
- product_provider
- Admin Bulletins Tab
- Pick Customer Step
- Stateful Widget States
- Mobile Order List
- Sales App Order Repository
- Mobile Order Detail
- Backend User Endpoints
- Data Repositories
- my_submissions_screen
- Orders Provider
- Admin Suppliers Tests
- Customer Submission Endpoints
- bulletin_provider
- Cross-Branch Reports Tab
- Sales Performance Model
- customer_submission_detail_screen
- branches
- sales_target
- home_stats_provider
- suppliers_tab
- customer_registration_screen
- customer_submission_detail_screen
- dashboard_screen
- api_service
- SceneDelegate
- auth_repository
- customer_repository
- auth_repository
- supplier_target_edit_dialog
- my_submissions_screen
- win32_window
- flutter_window
- customer_sync
- data_card
- order_provider
- product_provider
- sync_result
- product
- responsive_action_menu
- product
- change_password_dialog
- api_service
- login_screen
- api_service
- main
- change_password_dialog
- auth_storage
- branch
- branch
- product
- loading_state
- stat_tile
- change_password_dialog
- responsive_dialog
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
- sales_user
- supplier
- supplier_target
- api_exception
- sales_assignment
- railway
- win32_window
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

## God Nodes (most connected - your core abstractions)
1. `AdminProvider` - 94 edges
2. `BaseSchema` - 67 edges
3. `apply_branch_filter()` - 44 edges
4. `Product` - 44 edges
5. `User` - 43 edges
6. `Customer` - 41 edges
7. `_` - 38 edges
8. `Order` - 34 edges
9. `OrderItem` - 32 edges
10. `Win32Window` - 21 edges

## Surprising Connections (you probably didn't know these)
- `initState` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart
- `_showDeleteDialog` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart
- `_showFormDialog` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/bulletins_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart
- `_buildSalesTab` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/cross_branch_reports_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart
- `_buildStockTab` --references--> `AdminProvider`  [EXTRACTED]
  sales-app/admin_web/lib/presentation/screens/cross_branch_reports_tab.dart → sales-app/admin_web/lib/presentation/providers/admin_provider.dart

## Import Cycles
- None detected.

## Communities (171 total, 35 thin omitted)

### Community 0 - "AdminProvider State Hub"
Cohesion: 0.01
Nodes (159): adminRepository, AdminState, _allOrders, approveCustomerSubmission, approveOrder, _autoRefresh, _autoRefreshTimer, _bulletins (+151 more)

### Community 1 - "Sales App Home Screens"
Cohesion: 0.03
Nodes (90): build, _maybeShowBulletinPopup, build, build, _animation, _BerandaTab, _BerandaTabState, build (+82 more)

### Community 2 - "Admin Stats Tab"
Cohesion: 0.02
Nodes (100): aggregateDashboardPerformance, _applyFilters, approvedMtdCount, approvedMtdRevenue, approvedTodayCount, approvedTodayRevenue, branch, _branchFilter (+92 more)

### Community 3 - "Backend Auth Endpoints"
Cohesion: 0.06
Nodes (26): change_password(), login(), refresh_token(), register(), reset_all_bulletins(), load_branches_cache(), create_access_token(), create_refresh_token() (+18 more)

### Community 4 - "Backend Pydantic Schemas"
Cohesion: 0.04
Nodes (71): AreaAssignmentListItem, AreaAssignmentsPut, BaseSchema, BranchBase, BranchCreate, BranchResponse, Config, BranchSalesSummary (+63 more)

### Community 5 - "Admin API Repositories"
Cohesion: 0.03
Nodes (68): _api, approveCustomerSubmission, approveOrder, cancelOrderItems, changePassword, clearImportErrors, clearTokens, createBulletin (+60 more)

### Community 6 - "Sales Web Order Flow UI"
Cohesion: 0.03
Nodes (78): _activeLayersSummary, _bsDetailRow, _buildBottomBar, _buildStepContent, _calcPreview, _chip, color, _commit (+70 more)

### Community 7 - "Backend Order Endpoints"
Cohesion: 0.07
Nodes (39): _apply_3_layers(), approve_order(), _book_items(), _build_order_response(), cancel_order(), cancel_order_items(), create_order(), delete_draft_order() (+31 more)

### Community 8 - "Admin Orders Tab"
Cohesion: 0.03
Nodes (74): _applyFilters, _buildAllOrders, _buildPendingOrders, _buildPriceSummary, _CancelItemResult, canEdit, controller, createState (+66 more)

### Community 9 - "Backend Product Endpoints"
Cohesion: 0.07
Nodes (33): clear_import_errors(), delete_product(), _get_4p_suppliers(), get_admin_stats(), get_import_logs(), get_kategori_list(), get_product(), get_product_count() (+25 more)

### Community 10 - "Backend Customer Endpoints"
Cohesion: 0.08
Nodes (28): create_customer(), _customer_to_response(), delete_customer(), _exclude_deleted(), get_customer(), get_customer_count(), import_excel(), _list_assignments() (+20 more)

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
Nodes (58): _EmptyState, _StatCard, _SubmissionCard, _SubmissionDetailScreen, _LayerField, _OrderItemRow, _BranchPerformanceCard, _PeriodReportCard (+50 more)

### Community 16 - "Draft Order Provider"
Cohesion: 0.03
Nodes (60): addLine, _applyItemLayers, buildItemsPayload, copyWith, customerAddress, customerId, customerName, cutFrom (+52 more)

### Community 17 - "Mobile Design System"
Cohesion: 0.03
Nodes (57): AppColors, AppTextStyles, AppTheme, available, background, bodyLarge, bodyMedium, bodySmall (+49 more)

### Community 18 - "Mobile Order Flow"
Cohesion: 0.04
Nodes (47): _back, _backFromProducts, build, _confirmCancel, _connector, createState, currentStep, _dot (+39 more)

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
Nodes (37): accessToken, _adminProvider, _apiService, branch, branchNama, _buildBody, _checkIdle, createState (+29 more)

### Community 25 - "order"
Cohesion: 0.04
Nodes (51): branch, branchNama, CancelledItem, cancelledItems, createdAt, customerId, customerKode, customerName (+43 more)

### Community 26 - "sync_tab"
Cohesion: 0.04
Nodes (42): rootNavigatorKey, align, build, _buildDesktopTable, _buildErrorTile, _buildMobileList, color, createState (+34 more)

### Community 27 - "design_system"
Cohesion: 0.04
Nodes (46): AppColors, AppTextStyles, AppTheme, available, background, _bg, bodyLarge, bodyMedium (+38 more)

### Community 28 - "customer_registration_screen"
Cohesion: 0.04
Nodes (48): _alamatKirimCtl, _alamatKtpCtl, _areaCtl, _barengOrder, _batasKreditCtl, build, _buildPayload, _channelKategori (+40 more)

### Community 29 - "supplier_create_dialog"
Cohesion: 0.06
Nodes (19): controller, formKey, showSupplierCreateDialog, message, showSupplierToggleDialog, willActivate, main, _harness (+11 more)

### Community 30 - "penugasan_sales_tab"
Cohesion: 0.05
Nodes (40): _allCustomers, _allSalesUsers, _allUsers, area, _areaAssignments, _AreaRow, areas, _AssignmentChip (+32 more)

### Community 31 - "users_tab"
Cohesion: 0.05
Nodes (42): active, _branch, _BranchChip, build, _buildCardList, _buildHeader, _buildRow, _buildTable (+34 more)

### Community 32 - "order"
Cohesion: 0.05
Nodes (42): CancelledItem, cancelledItems, canDelete, canEdit, createdAt, customerId, customerName, discount2Nominal (+34 more)

### Community 33 - "bulletin"
Cohesion: 0.05
Nodes (22): create_supplier(), list_suppliers(), update_supplier_active(), CustomerSubmissionCreate, Bulletin, createdAt, description, expireAt (+14 more)

### Community 34 - "customers_tab"
Cohesion: 0.05
Nodes (40): _alamatC, build, _buildCardList, _buildError, _buildFooter, _buildForm, _buildHeader, _buildRow (+32 more)

### Community 35 - "web_auth_storage"
Cohesion: 0.05
Nodes (29): triggerBrowserDownload, triggerBrowserDownload, anchor, blob, blobParts, triggerBrowserDownload, url, bytes (+21 more)

### Community 36 - "main"
Cohesion: 0.06
Nodes (25): _apiService, _authRepo, AuthWrapper, _AuthWrapperState, _backgroundTimeout, _checking, createState, didChangeAppLifecycleState (+17 more)

### Community 37 - "confirm_dialog"
Cohesion: 0.06
Nodes (29): build, _CancelButton, _ConfirmButton, ConfirmDialog, InfoDialog, isDestructive, label, onPressed (+21 more)

### Community 38 - "bulletins"
Cohesion: 0.11
Nodes (16): _assert_bulletin_visible(), _build_bulletin_response(), bulletin_upload_pdf(), create_bulletin(), delete_bulletin(), dismiss_bulletin(), list_bulletins(), expire_bulletins() (+8 more)

### Community 39 - "login_screen"
Cohesion: 0.06
Nodes (31): _LoginScreenState, build, _checkAuth, _checkBackgroundTimeout, build, createState, dispose, _formKey (+23 more)

### Community 40 - "customer_submissions_tab"
Cohesion: 0.06
Nodes (36): active, _changeFilter, color, count, createState, CustomerSubmissionsTab, _CustomerSubmissionsTabState, _displayLimit (+28 more)

### Community 41 - "auth_provider"
Cohesion: 0.06
Nodes (30): _authRepo, AuthState, changeOwnPassword, checkLoginStatus, _errorMessage, forceLogout, getToken, isAuthenticated (+22 more)

### Community 42 - "performance_tab"
Cohesion: 0.06
Nodes (30): align, build, _buildLeaderboard, _buildPeriodFilterSection, _buildSectionTitle, _buildSupplierPerformanceTable, _buildTargetSection, child (+22 more)

### Community 43 - "reports"
Cohesion: 0.08
Nodes (17): _build_report(), _layer_cut_value(), report_summary(), sales_performance_dashboard(), _aggregate(), _revenue_for_order(), _three_layer_breakdown(), ReportSummaryByBranch (+9 more)

### Community 44 - "responsive"
Cohesion: 0.06
Nodes (32): _, Breakpoints, cardGap, cardPadding, columns, compactMax, contentPadding, device (+24 more)

### Community 45 - "product_catalog_screen"
Cohesion: 0.07
Nodes (29): build, build, initState, _ProductRow, build, _StepReviewState, build, initState (+21 more)

### Community 46 - "products_tab"
Cohesion: 0.06
Nodes (30): build, _buildCardList, _buildFilterDropdowns, _buildProductCard, _buildTable, colW, _confirmDelete, createState (+22 more)

### Community 47 - "step_pick_products"
Cohesion: 0.06
Nodes (28): _animation, _applyInput, available, _controller, createState, _detailRow, didUpdateWidget, disabled (+20 more)

### Community 48 - "action_button_row"
Cohesion: 0.07
Nodes (23): ActionButton, ActionButtonRow, actions, alignment, build, _buildButton, destructive, icon (+15 more)

### Community 49 - "product_provider"
Cohesion: 0.06
Nodes (29): _allProducts, _categoryFilter, clearFilters, clearSearch, countByStatus, countByStatusAll, _errorMessage, hasActiveFilters (+21 more)

### Community 50 - "Admin Bulletins Tab"
Cohesion: 0.07
Nodes (22): completer, input, onChange, pickPdfFile, build, bulletin, _BulletinCard, BulletinsTab (+14 more)

### Community 51 - "Pick Customer Step"
Cohesion: 0.08
Nodes (23): _animation, build, _controller, createState, customer, _customers, _CustomerSkeletonTile, _CustomerSkeletonTileState (+15 more)

### Community 52 - "Stateful Widget States"
Cohesion: 0.10
Nodes (18): _ChangePasswordDialogState, _SkeletonBoxState, _ChangePasswordDialogState, _HomeScreenState, _StepPickCustomerState, _StepPickProductsState, _DiscountSheetState, _UpPriceSheetState (+10 more)

### Community 53 - "Mobile Order List"
Cohesion: 0.07
Nodes (25): _animation, _buildList, _controller, createState, didChangeAppLifecycleState, dispose, _filterOrders, initState (+17 more)

### Community 54 - "Sales App Order Repository"
Cohesion: 0.07
Nodes (27): _api, cancelOrder, createOrder, deleteOrder, fromJson, getMyOrders, getMyStats, getMyTarget (+19 more)

### Community 55 - "Mobile Order Detail"
Cohesion: 0.08
Nodes (25): _animation, build, _confirmAndCancel, _confirmAndDelete, _controller, createState, dispose, _error (+17 more)

### Community 56 - "Backend User Endpoints"
Cohesion: 0.13
Nodes (11): create_user(), delete_user(), _exclude_deleted(), list_sales_users(), list_users(), update_user(), _user_to_response(), is_valid_branch() (+3 more)

### Community 57 - "Data Repositories"
Cohesion: 0.08
Nodes (17): _api, BulletinRepository, dismissBulletin, getBulletins, _api, get4pSuppliers, getProduct, getProducts (+9 more)

### Community 58 - "my_submissions_screen"
Cohesion: 0.09
Nodes (19): _confirmSubmit, initState, _submit, initState, _buildBody, createState, _error, _formatDate (+11 more)

### Community 59 - "Orders Provider"
Cohesion: 0.08
Nodes (22): _activeStatusFilter, cancelOrder, clearMessages, countByStatus, createOrder, deleteOrder, _errorMessage, getOrderDetail (+14 more)

### Community 60 - "Admin Suppliers Tests"
Cohesion: 0.09
Nodes (18): AdminRepository, createSupplier, failWith, _FakeAdminRepository, getSuppliers, main, suppliers, updateSupplierActive (+10 more)

### Community 61 - "Customer Submission Endpoints"
Cohesion: 0.18
Nodes (10): approve_submission(), cancel_submission(), check_duplicate_customer(), get_submission(), list_my_submissions(), list_submissions(), reject_submission(), _serialize() (+2 more)

### Community 62 - "bulletin_provider"
Cohesion: 0.09
Nodes (16): _bulletins, dismissBulletin, _error, hasUnread, latestUnread, loadBulletins, _loading, _repo (+8 more)

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
Cohesion: 0.09
Nodes (19): copyWith, fromJson, id, incentiveAmount, isOrderCount, isRevenue, period, SalesTarget (+11 more)

### Community 68 - "home_stats_provider"
Cohesion: 0.10
Nodes (15): _errorMessage, HomeStatsProvider, isLoading, load, _loading, _orderRepository, refresh, _stats (+7 more)

### Community 69 - "suppliers_tab"
Cohesion: 0.10
Nodes (19): _activeFilter, build, _buildEmptyState, _cardList, _chip, createState, dispose, initState (+11 more)

### Community 70 - "customer_registration_screen"
Cohesion: 0.09
Nodes (21): _OrderCard, CustomerRegistrationScreen, _ProductSearchSheet, _ProductSearchSheetState, HomeScreen, _QtyStepper, StepPickProducts, _DiscountSheet (+13 more)

### Community 71 - "customer_submission_detail_screen"
Cohesion: 0.09
Nodes (20): build, children, _color, createState, _currentUsername, CustomerSubmissionDetailScreen, _fmtNumber, _formatDate (+12 more)

### Community 72 - "dashboard_screen"
Cohesion: 0.10
Nodes (21): AdminProvider, build, _buildDrawer, _buildSidebar, _buildTopBar, initState, _NavPanel, _onNavTap (+13 more)

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

### Community 79 - "my_submissions_screen"
Cohesion: 0.12
Nodes (16): initState, _submit, _buildBody, createState, _error, _formatDate, initState, _load (+8 more)

### Community 80 - "win32_window"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 81 - "flutter_window"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 82 - "customer_sync"
Cohesion: 0.20
Nodes (7): _bulk_upsert_customers(), _normalize(), _read_excel(), _safe_reason(), _str_or_none(), sync_customers_from_excel(), _validate_row()

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

### Community 88 - "responsive_action_menu"
Cohesion: 0.12
Nodes (15): action, actions, build, compact, destructive, icon, _InlineActionButton, _kebab (+7 more)

### Community 89 - "product"
Cohesion: 0.12
Nodes (15): fromJson, harga, id, kategori, namaBarang, namaSupplier, orderType, perluDitinjau (+7 more)

### Community 90 - "change_password_dialog"
Cohesion: 0.12
Nodes (15): build, _buildPasswordField, ChangePasswordDialog, _confirmController, createState, _currentController, dispose, _error (+7 more)

### Community 91 - "api_service"
Cohesion: 0.13
Nodes (11): _accessToken, ApiService, _checkTokenExpiry, clearAccessToken, delete, _handleResponse, message, post (+3 more)

### Community 92 - "login_screen"
Cohesion: 0.13
Nodes (11): build, createState, dispose, _error, _formKey, _isLoading, _login, LoginScreen (+3 more)

### Community 93 - "api_service"
Cohesion: 0.13
Nodes (11): _accessToken, ApiService, _checkTokenExpiry, clearAccessToken, delete, _handleResponse, message, post (+3 more)

### Community 94 - "main"
Cohesion: 0.13
Nodes (8): AdminApp, build, initializeDateFormatting, initialTokens, main, null, storage, tokens

### Community 95 - "change_password_dialog"
Cohesion: 0.13
Nodes (12): adminRepository, build, ChangePasswordDialog, _confirmC, createState, dispose, _errSnack, _newC (+4 more)

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

### Community 100 - "loading_state"
Cohesion: 0.14
Nodes (12): build, _controller, createState, dispose, height, initState, label, LoadingState (+4 more)

### Community 101 - "stat_tile"
Cohesion: 0.14
Nodes (12): build, color, icon, label, onTap, StatTile, text, trend (+4 more)

### Community 102 - "change_password_dialog"
Cohesion: 0.14
Nodes (12): authProvider, build, ChangePasswordDialog, _confirmC, createState, dispose, _errSnack, _newC (+4 more)

### Community 103 - "responsive_dialog"
Cohesion: 0.14
Nodes (12): actions, build, child, content, contentMaxWidth, desktopWidthFraction, maxHeight, maxWidth (+4 more)

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
Cohesion: 0.22
Nodes (4): get_my_target(), list_sales_targets(), upsert_sales_target(), SalesTarget

### Community 110 - "supplier_targets"
Cohesion: 0.21
Nodes (4): delete_supplier_target(), list_supplier_targets(), upsert_supplier_target(), SupplierTarget

### Community 111 - "config"
Cohesion: 0.15
Nodes (12): accessTokenKey, AppConfig, baseUrl, refreshTokenKey, requestTimeout, tokenKey, userBranchKey, userBranchNamaKey (+4 more)

### Community 112 - "auth_provider"
Cohesion: 0.17
Nodes (11): AuthProvider, BulletinProvider, DraftOrderProvider, OrderProvider, ProductProvider, AuthProvider, BulletinProvider, CustomerProvider (+3 more)

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

### Community 126 - "sales_user"
Cohesion: 0.22
Nodes (7): displayName, fromJson, id, nama, role, SalesUser, username

### Community 127 - "supplier"
Cohesion: 0.22
Nodes (8): createdAt, fromJson, isActive, name, productCount, Supplier, toJson, updatedAt

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

### Community 132 - "win32_window"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

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

## Knowledge Gaps
- **2657 isolated node(s):** `message`, `statusCode`, `toString`, `onResponse`, `onError` (+2652 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 3066 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **35 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AdminProvider` connect `dashboard_screen` to `AdminProvider State Hub`, `Sales App Home Screens`, `Admin Stats Tab`, `Admin Orders Tab`, `Shared UI Widget Classes`, `orders_tab`, `orders_tab`, `penugasan_sales_tab`, `penugasan_sales_tab`, `dashboard_screen`, `penugasan_sales_tab`, `penugasan_sales_tab`, `sync_tab`, `stats_tab`, `penugasan_sales_tab`, `users_tab`, `customers_tab`, `customer_submissions_tab`, `performance_tab`, `products_tab`, `Admin Bulletins Tab`, `Cross-Branch Reports Tab`, `suppliers_tab`, `auth_provider`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **What connects `message`, `statusCode`, `toString` to the rest of the system?**
  _2657 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AdminProvider State Hub` be split into smaller, more focused modules?**
  _Cohesion score 0.012048192771084338 - nodes in this community are weakly interconnected._
- **Why does `Product` connect `Backend Product Endpoints` to `bulletin`, `branches`, `Backend Auth Endpoints`, `Backend Pydantic Schemas`, `Backend Order Endpoints`, `Backend Customer Endpoints`, `reports`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Should `Sales App Home Screens` be split into smaller, more focused modules?**
  _Cohesion score 0.027684711691059776 - nodes in this community are weakly interconnected._
- **Why does `apply_branch_filter()` connect `Backend Product Endpoints` to `bulletin`, `Backend Auth Endpoints`, `bulletins`, `Backend Order Endpoints`, `Backend Customer Endpoints`, `reports`, `sales_targets`, `supplier_targets`, `Backend User Endpoints`, `Customer Submission Endpoints`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Should `Admin Stats Tab` be split into smaller, more focused modules?**
  _Cohesion score 0.019230769230769232 - nodes in this community are weakly interconnected._