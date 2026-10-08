import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart' hide ItemDiscount, DiscountLayer;
import '../../../data/models/product.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../core/api_service.dart';
import '../../providers/draft_order_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/order_provider.dart';

class OrderFlowScreen extends StatefulWidget {
  final Order? existingOrder;

  const OrderFlowScreen({super.key, this.existingOrder});

  @override
  State<OrderFlowScreen> createState() => _OrderFlowScreenState();
}

class _OrderFlowScreenState extends State<OrderFlowScreen> {
  int _step = 1;

  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingOrder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final draft = context.read<DraftOrderProvider>();
        draft.loadFromExisting(widget.existingOrder!);
        _notesController.text = widget.existingOrder!.notes ?? '';
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < 4) {
      setState(() => _step++);
    }
  }

  void _prevStep() {
    if (_step > 1) {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(_stepTitle),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmClose(context),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(currentStep: _step),

          // Content
          Expanded(
            child: _buildStepContent(),
          ),

          // Bottom bar
          _buildBottomBar(draft, onBack: _prevStep),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 1: return 'Pilih Customer';
      case 2: return 'Tipe Order';
      case 3: return 'Pilih Produk';
      case 4: return 'Review Order';
      default: return '';
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1: return _StepPickCustomer(onNext: _nextStep);
      case 2: return _StepPickOrderType(onNext: _nextStep, onBack: _prevStep);
      case 3: return _StepPickProducts(onNext: _nextStep, onBack: _prevStep);
      case 4: return _StepReview(
        notesController: _notesController,
        onBack: _prevStep,
        onSubmit: () => _submitOrder(),
        onSaveDraft: () => _saveDraft(),
      );
      default: return const SizedBox();
    }
  }

  Widget _buildBottomBar(DraftOrderProvider draft, {required VoidCallback onBack}) {
    if (_step == 3) {
      final idr = NumberFormat('#,###', 'id');
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _prevStep,
                child: const Text('Kembali'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${draft.items.length} item',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Rp ${idr.format(draft.totalPrice)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: draft.items.isEmpty ? null : _nextStep,
                child: const Text('Lanjut'),
              ),
            ],
          ),
        ),
      );
    }

    if (_step == 4) {
      return const SizedBox(height: 16);
    }

    return const SizedBox(height: 16);
  }

  void _confirmClose(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    if (draft.items.isEmpty && draft.customerId == null) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batal Order?'),
        content: const Text('Order yang sudah dibuat akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lanjut Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    final draft = context.read<DraftOrderProvider>();
    final apiService = context.read<ApiService>();

    try {
      final orderRepo = OrderRepository(apiService);
      final items = draft.buildItemsPayload();

      if (draft.editingOrderId != null) {
        await orderRepo.updateOrder(
          orderId: draft.editingOrderId!,
          customerId: draft.customerId!,
          items: items,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          orderType: draft.orderType,
        );
      } else {
        await orderRepo.createOrder(
          customerId: draft.customerId!,
          items: items,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          orderType: draft.orderType,
        );
      }

      // Refresh orders
      if (mounted) {
        context.read<OrderProvider>().loadOrders();
        context.read<OrderProvider>().loadRecentOrders();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    final draft = context.read<DraftOrderProvider>();
    final apiService = context.read<ApiService>();

    try {
      final orderRepo = OrderRepository(apiService);
      final items = draft.buildItemsPayload();

      await orderRepo.saveDraft(
        customerId: draft.customerId!,
        items: items,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        orderType: draft.orderType,
        existingOrderId: draft.editingOrderId,
      );

      if (mounted) {
        context.read<OrderProvider>().loadOrders();
        context.read<OrderProvider>().loadRecentOrders();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft disimpan'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const circleSize = 32.0;
    const totalSteps = 4;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Line between circles
            final stepNum = (index ~/ 2) + 1;
            final isDone = stepNum < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isDone ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
            );
          } else {
            // Circle
            final stepNum = (index ~/ 2) + 1;
            final isActive = stepNum == currentStep;
            final isDone = stepNum < currentStep;
            return Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: isDone || isActive
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '$stepNum',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            );
          }
        }),
      ),
    );
  }
}

// ─── Step 1: Pick Customer ────────────────────────────────────────────────────

class _StepPickCustomer extends StatefulWidget {
  final VoidCallback onNext;

  const _StepPickCustomer({required this.onNext});

  @override
  State<_StepPickCustomer> createState() => _StepPickCustomerState();
}

class _StepPickCustomerState extends State<_StepPickCustomer> {
  final _searchController = TextEditingController();
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers({String? search}) async {
    setState(() => _isLoading = true);
    final apiService = context.read<ApiService>();
    final repo = CustomerRepository(apiService);
    try {
      _customers = await repo.getMyCustomers(search: search);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();

    return Column(
      children: [
        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari customer...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadCustomers();
                      },
                    )
                  : null,
            ),
            onSubmitted: (v) => _loadCustomers(search: v),
          ),
        ),

        // Selected customer
        if (draft.customerId != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.customerName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (draft.customerAddress != null)
                        Text(
                          draft.customerAddress!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Customer list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    final isSelected = draft.customerId == customer.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? const Color(0xFFEFF6FF) : null,
                      child: ListTile(
                        title: Text(
                          customer.namaToko,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          customer.alamat ?? customer.kodeArea ?? '-',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF2563EB),
                              )
                            : null,
                        onTap: () {
                          context.read<DraftOrderProvider>().setCustomer(customer);
                        },
                      ),
                    );
                  },
                ),
        ),

        // Next button
        Container(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: draft.customerId != null ? widget.onNext : null,
                child: const Text('Lanjut'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Pick Order Type ─────────────────────────────────────────────────

class _StepPickOrderType extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StepPickOrderType({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Tipe Order',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih jenis order yang akan dibuat',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          _OrderTypeCard(
            type: 'REGULER',
            title: 'Order Reguler',
            description: 'Order standar dengan pengiriman normal',
            icon: Icons.shopping_cart,
            color: const Color(0xFF2563EB),
            isSelected: draft.orderType == 'REGULER',
            onTap: () {
              context.read<DraftOrderProvider>().setOrderType('REGULER');
            },
          ),
          const SizedBox(height: 16),
          _OrderTypeCard(
            type: '4P',
            title: 'Order 4P (Program Promosi)',
            description: 'Order untuk program promosi supplier',
            icon: Icons.local_offer,
            color: const Color(0xFFD97706),
            isSelected: draft.orderType == '4P',
            onTap: () {
              context.read<DraftOrderProvider>().setOrderType('4P');
            },
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onNext,
                  child: const Text('Lanjut'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderTypeCard extends StatelessWidget {
  final String type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderTypeCard({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Color.lerp(color, Colors.white, 0.9) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color.lerp(color, Colors.white, 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color)
              else
                Icon(Icons.circle_outlined, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 3: Pick Products ─────────────────────────────────────────────────────

class _StepPickProducts extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StepPickProducts({required this.onNext, required this.onBack});

  @override
  State<_StepPickProducts> createState() => _StepPickProductsState();
}

class _StepPickProductsState extends State<_StepPickProducts> {
  final _searchController = TextEditingController();
  final _qtyFocusNode = FocusNode();
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProductProvider>();
    if (provider.allProducts.isEmpty) {
      final draft = context.read<DraftOrderProvider>();
      provider.loadProducts(orderType: draft.orderType);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _qtyFocusNode.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getQtyController(String productId, int currentQty) {
    if (!_qtyControllers.containsKey(productId)) {
      _qtyControllers[productId] = TextEditingController(text: currentQty > 0 ? '$currentQty' : '');
    } else {
      final c = _qtyControllers[productId]!;
      if (c.text.isEmpty && currentQty > 0) {
        c.text = '$currentQty';
      } else if (currentQty == 0 && c.text.isNotEmpty) {
        c.text = '';
      }
    }
    return _qtyControllers[productId]!;
  }

  void _onQtyChanged(String productId, String value, dynamic product) {
    final qty = int.tryParse(value) ?? 0;
    final draft = context.read<DraftOrderProvider>();
    final existing = draft.items.where((i) => i.productId == productId).toList();

    if (qty <= 0) {
      if (existing.isNotEmpty) draft.removeItem(existing.first.id);
    } else {
      if (existing.isNotEmpty) {
        draft.setQty(existing.first.id, qty);
      } else {
        draft.addItem(product);
        // adjust to target qty
        final newly = draft.items.where((i) => i.productId == productId).toList();
        if (newly.isNotEmpty && newly.first.qty > qty) {
          draft.setQty(newly.first.id, qty);
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final draft = context.watch<DraftOrderProvider>();
    final idr = NumberFormat('#,###', 'id');

    var products = provider.allProducts;
    if (draft.orderType.isNotEmpty) {
      products = products.where((p) => p.orderType == draft.orderType).toList();
    }

    // Search filter by code, name, supplier
    final q = _searchController.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      products = products.where((p) {
        final name = p.namaBarang.toLowerCase();
        final id = p.id.toLowerCase();
        final supplier = (p.namaSupplier ?? '').toLowerCase();
        return name.contains(q) || id.contains(q) || supplier.contains(q);
      }).toList();
    }

    return Column(
      children: [
        // ── Header: Tipe + Toko ──────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tipe order badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tipe: ${draft.orderType}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Toko + Ganti
              Row(
                children: [
                  Icon(Icons.store_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      draft.customerName ?? '-',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Ganti',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Search bar ────────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari kode, nama, atau supplier...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // ── Selected item chips ───────────────────────────────────────────────
        if (draft.items.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: draft.items.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.namaBarang} x${item.qty}',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            context.read<DraftOrderProvider>().removeItem(item.id);
                            setState(() {});
                          },
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // ── Product list ──────────────────────────────────────────────────────
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? Center(
                      child: Text(
                        q.isEmpty ? 'Tidak ada produk' : 'Produk tidak ditemukan',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _OrderProductCard(
                          product: product,
                          idr: idr,
                          qtyController: _getQtyController(
                            product.id,
                            _getQty(draft, product.id),
                          ),
                          currentQty: _getQty(draft, product.id),
                          onQtyChanged: (v) => _onQtyChanged(product.id, v, product),
                          onCardTap: () => _showProductBottomSheet(context, product, idr),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  int _getQty(DraftOrderProvider draft, String productId) {
    final item = draft.items.where((i) => i.productId == productId).toList();
    return item.isNotEmpty ? item.first.qty : 0;
  }

  void _showProductBottomSheet(BuildContext context, dynamic product, NumberFormat idr) {
    final available = product.stokTersedia as int;
    final satuan = product.satuan as String? ?? 'unit';
    final id = product.id as String;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: nama + SKU
            Text(
              product.namaBarang ?? '',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'SKU: $id',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 20),
            // Detail rows
            _bsDetailRow(Icons.qr_code_outlined, 'SKU', id),
            if (satuan.isNotEmpty && satuan != 'unit')
              _bsDetailRow(Icons.scale_outlined, 'Satuan', satuan),
            if (product.namaSupplier != null && (product.namaSupplier as String).isNotEmpty)
              _bsDetailRow(Icons.business_outlined, 'Supplier', product.namaSupplier),
            if (product.kategori != null && (product.kategori as String).isNotEmpty)
              _bsDetailRow(Icons.category_outlined, 'Kategori', product.kategori),
            const SizedBox(height: 16),
            // Harga + Stok
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Harga', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${idr.format(product.harga)}',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Stok', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '$available $satuan',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: available == 0 ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textSecondary,
                  foregroundColor: AppColors.textOnPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bsDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ─── Order Product Card ──────────────────────────────────────────────────────

class _OrderProductCard extends StatelessWidget {
  final dynamic product;
  final NumberFormat idr;
  final TextEditingController qtyController;
  final int currentQty;
  final ValueChanged<String> onQtyChanged;
  final VoidCallback onCardTap;

  const _OrderProductCard({
    required this.product,
    required this.idr,
    required this.qtyController,
    required this.currentQty,
    required this.onQtyChanged,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = product.stokTersedia as int;
    final satuan = product.satuan as String? ?? 'unit';
    final id = product.id as String;
    final supplier = product.namaSupplier as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama barang
              Text(
                product.namaBarang ?? '',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              // SKU / Stok / Supplier
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'SKU  ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    TextSpan(text: '$id\n', style: AppTextStyles.bodySmall.copyWith(fontFamily: 'monospace')),
                    TextSpan(text: 'Stok  ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    TextSpan(
                      text: '$available $satuan',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: available == 0 ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                    if (supplier != null && supplier.isNotEmpty) ...[
                      TextSpan(text: '\nSupplier  ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                      TextSpan(text: supplier, style: AppTextStyles.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Harga + Stepper
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Rp ${idr.format(product.harga)}',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stepper
                  _QtyStepper(
                    controller: qtyController,
                    currentQty: currentQty,
                    enabled: available > 0,
                    onChanged: onQtyChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quantity Stepper ───────────────────────────────────────────────────────

class _QtyStepper extends StatelessWidget {
  final TextEditingController controller;
  final int currentQty;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _QtyStepper({
    required this.controller,
    required this.currentQty,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus
          GestureDetector(
            onTap: enabled && currentQty > 0
                ? () {
                    final newQty = currentQty - 1;
                    onChanged('$newQty');
                  }
                : null,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Icon(
                Icons.remove,
                size: 18,
                color: enabled && currentQty > 0
                    ? AppColors.primaryLight
                    : AppColors.textMuted,
              ),
            ),
          ),
          // Qty input
          Container(
            width: 44,
            height: 36,
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: AppTextStyles.labelLarge,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
            ),
          ),
          // Plus
          GestureDetector(
            onTap: enabled
                ? () {
                    final newQty = currentQty + 1;
                    onChanged('$newQty');
                  }
                : null,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? AppColors.primaryLight : AppColors.borderLight,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: enabled ? AppColors.textOnPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Review ──────────────────────────────────────────────────────────

class _StepReview extends StatefulWidget {
  final TextEditingController notesController;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final VoidCallback onSaveDraft;

  const _StepReview({
    required this.notesController,
    required this.onBack,
    required this.onSubmit,
    required this.onSaveDraft,
  });

  @override
  State<_StepReview> createState() => _StepReviewState();
}

class _StepReviewState extends State<_StepReview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DraftOrderProvider>().setNotes(widget.notesController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final products = context.watch<ProductProvider>().allProducts;
    final productMap = {for (final p in products) p.id: p};
    final idr = NumberFormat('#,###', 'id');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              // ── Toko section ──────────────────────────────────────────────
              _sectionHeader('Toko'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.customerName ?? '-',
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (draft.customerAddress != null && draft.customerAddress!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              draft.customerAddress!,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onBack,
                      child: const Text('Ganti'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Produk section ───────────────────────────────────────────
              _sectionHeader('Produk (${draft.totalItems})'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < draft.items.length; i++) ...[
                      if (draft.items[i].qty > 0)
                        _LineRow(
                          line: draft.items[i],
                          product: productMap[draft.items[i].productId],
                        ),
                      if (i < draft.items.length - 1 && draft.items[i].qty > 0)
                        Container(height: 1, color: AppColors.border),
                    ],
                    Container(height: 1, color: AppColors.border),
                    InkWell(
                      onTap: widget.onBack,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Tambah Produk',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Catatan ──────────────────────────────────────────────────
              _sectionHeader('Catatan (opsional)'),
              const SizedBox(height: 8),
              TextField(
                controller: widget.notesController,
                maxLines: 3,
                onChanged: (v) => draft.setNotes(v),
                decoration: InputDecoration(
                  hintText: 'Tulis catatan untuk order ini...',
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // ── Total ───────────────────────────────────────────────────
              _OrderTotalCard(draft: draft, idr: idr),
            ],
          ),
        ),

        // ── Bottom buttons ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onSaveDraft,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Simpan Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onSubmit,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Kirim Order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      label,
      style: AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

// ─── Total Card ────────────────────────────────────────────────────────────

class _OrderTotalCard extends StatelessWidget {
  final DraftOrderProvider draft;
  final NumberFormat idr;

  const _OrderTotalCard({required this.draft, required this.idr});

  @override
  Widget build(BuildContext context) {
    final l1 = draft.discountLayer1Total;
    final l2 = draft.discountLayer2Total;
    final l3 = draft.discountLayer3Total;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Total (x item)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total (${draft.totalItems} item)', style: AppTextStyles.bodyLarge),
                    Text(
                      'Rp ${idr.format(draft.totalRaw)}',
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.primaryLight),
                    ),
                  ],
                ),
                // Per-layer discount rows
                if (l1 > 0) ...[
                  const SizedBox(height: 4),
                  _discRow('Diskon 1', l1, idr),
                ],
                if (l2 > 0) ...[
                  const SizedBox(height: 4),
                  _discRow('Diskon 2', l2, idr),
                ],
                if (l3 > 0) ...[
                  const SizedBox(height: 4),
                  _discRow('Diskon 3', l3, idr),
                ],
                Container(height: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(vertical: 10)),
                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      'Rp ${idr.format(draft.totalPrice)}',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (draft.freeItemsCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Item gratis: ${draft.freeItemsCount}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discRow(String label, int amount, NumberFormat idr) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
      Text(
        '- Rp ${idr.format(amount)}',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

// ─── Line Row ─────────────────────────────────────────────────────────────

class _LineRow extends StatelessWidget {
  final OrderLine line;
  final Product? product;

  const _LineRow({required this.line, required this.product});

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final idr = NumberFormat('#,###', 'id');
    final name = product?.namaBarang ?? line.productId;
    final price = product?.harga ?? line.hargaSatuan;
    final rawSubtotal = price * line.qty;
    final disc = line.discount;
    final isFree = line.isFree;

    // Calculate total cut
    int running = rawSubtotal;
    int d1 = 0, d2 = 0, d3 = 0;
    if (disc.layer1 != null) { d1 = disc.layer1!.cutFrom(running); running -= d1; }
    if (disc.layer2 != null) { d2 = disc.layer2!.cutFrom(running); running -= d2; }
    if (disc.layer3 != null) { d3 = disc.layer3!.cutFrom(running); running -= d3; }
    final subtotal = running;
    final totalCut = d1 + d2 + d3;

    return Opacity(
      opacity: isFree ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: nama + harga
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFree) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'GRATIS',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product?.id != null)
                        Text(product!.id, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${idr.format(subtotal)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: totalCut > 0 ? AppColors.success : AppColors.textPrimary,
                      ),
                    ),
                    if (totalCut > 0)
                      Text(
                        'Rp ${idr.format(rawSubtotal)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: qty meta + stepper + actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '× ${line.qty} · Rp ${idr.format(price)}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      if (!disc.isEmpty) ...[
                        const SizedBox(height: 2),
                        _activeLayersSummary(disc, idr),
                      ],
                    ],
                  ),
                ),
                if (!isFree) ...[
                  _ReviewQtyStepper(
                    qty: line.qty,
                    max: product?.stokTersedia ?? 0,
                    onChanged: (newQty) {
                      if (newQty == 0) {
                        draft.removeItem(line.id);
                      } else {
                        draft.setQty(line.id, newQty);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                // Diskon button
                if (!isFree)
                  _iconBtn(
                    icon: Icons.discount_outlined,
                    color: !disc.isEmpty ? AppColors.success : AppColors.textSecondary,
                    onTap: () => _showDiscountSheet(context, line, product),
                  ),
                const SizedBox(width: 4),
                // More menu
                _PopupMenuBtn(
                  items: [
                    if (!isFree)
                      _PopupMenuItem(
                        label: 'Barang Gratis',
                        icon: Icons.card_giftcard,
                        color: AppColors.success,
                        onTap: () => _showGratisDialog(context, name, draft),
                      ),
                    _PopupMenuItem(
                      label: 'Hapus',
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: () => draft.removeItem(line.id),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeLayersSummary(ItemDiscount disc, NumberFormat idr) {
    final parts = <String>[];
    for (final entry in [(1, disc.layer1), (2, disc.layer2), (3, disc.layer3)]) {
      final l = entry.$2;
      if (l == null) continue;
      final label = 'Diskon ${entry.$1}';
      final cut = l.type == 'NOMINAL'
          ? 'Rp ${idr.format(l.value)}'
          : '${l.value}%';
      parts.add('$label: $cut');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w500),
    );
  }

  void _showDiscountSheet(BuildContext context, OrderLine line, Product? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DiscountSheet(line: line, product: product),
    );
  }

  void _showGratisDialog(BuildContext context, String name, DraftOrderProvider draft) {
    final qtyCtl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Barang Gratis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produk: $name', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Item duplikat akan mendapat diskon 100% (GRATIS).',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Jumlah gratis (qty)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtl.text) ?? 0;
              if (qty <= 0) return;
              final newLine = draft.addLine(line.productId, qty: qty);
              draft.setDiscountLayer(lineId: newLine.id, layer: 1, type: 'PERCENT', value: 100);
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

// ─── Review Qty Stepper ──────────────────────────────────────────────────

class _ReviewQtyStepper extends StatefulWidget {
  final int qty;
  final int max;
  final ValueChanged<int> onChanged;

  const _ReviewQtyStepper({required this.qty, required this.max, required this.onChanged});

  @override
  State<_ReviewQtyStepper> createState() => _ReviewQtyStepperState();
}

class _ReviewQtyStepperState extends State<_ReviewQtyStepper> {
  late TextEditingController _ctrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.qty}');
  }

  @override
  void didUpdateWidget(_ReviewQtyStepper old) {
    super.didUpdateWidget(old);
    if (!_isEditing && old.qty != widget.qty) {
      _ctrl.text = '${widget.qty}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 0) {
      widget.onChanged(parsed == 0 ? 0 : (parsed <= widget.max ? parsed : widget.max));
    }
    setState(() => _isEditing = false);
    if (!_isEditing) {
      _ctrl.text = '${widget.qty}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(
          icon: Icons.remove,
          onTap: widget.qty > 1
              ? () => widget.onChanged(widget.qty - 1)
              : () => widget.onChanged(0),
          isPrimary: false,
        ),
        SizedBox(
          width: 46,
          child: GestureDetector(
            onTap: () => setState(() {
              _isEditing = true;
              _ctrl.text = '${widget.qty}';
              _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
            }),
            child: _isEditing
                ? TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6), border: InputBorder.none),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: _commit,
                    onTapOutside: (_) => _commit(_ctrl.text),
                  )
                : Text(
                    '${widget.qty}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
          ),
        ),
        _stepBtn(
          icon: Icons.add,
          onTap: widget.qty < widget.max ? () => widget.onChanged(widget.qty + 1) : null,
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _stepBtn({required IconData icon, required VoidCallback? onTap, required bool isPrimary}) {
    return Material(
      color: isPrimary ? (onTap != null ? AppColors.primaryLight : AppColors.primaryLight.withValues(alpha: 0.4)) : AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isPrimary ? BorderSide.none : BorderSide(color: onTap != null ? AppColors.border : AppColors.border.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 32, height: 32,
          child: Icon(icon, size: 16, color: isPrimary ? Colors.white : (onTap != null ? AppColors.textPrimary : AppColors.textMuted)),
        ),
      ),
    );
  }
}

// ─── Discount Sheet ───────────────────────────────────────────────────────

class _DiscountSheet extends StatefulWidget {
  final OrderLine line;
  final Product? product;

  const _DiscountSheet({required this.line, this.product});

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late String _type1, _type2, _type3;
  late TextEditingController _ctrl1, _ctrl2, _ctrl3;
  late NumberFormat _idr;

  @override
  void initState() {
    super.initState();
    _idr = NumberFormat('#,###', 'id');
    _initLayer(1, widget.line.discount.layer1);
    _initLayer(2, widget.line.discount.layer2);
    _initLayer(3, widget.line.discount.layer3);
  }

  void _initLayer(int idx, DiscountLayer? layer) {
    switch (idx) {
      case 1: _type1 = layer?.type ?? 'PERCENT'; _ctrl1 = TextEditingController(text: layer != null ? '${layer.value}' : ''); break;
      case 2: _type2 = layer?.type ?? 'PERCENT'; _ctrl2 = TextEditingController(text: layer != null ? '${layer.value}' : ''); break;
      case 3: _type3 = layer?.type ?? 'PERCENT'; _ctrl3 = TextEditingController(text: layer != null ? '${layer.value}' : ''); break;
    }
  }

  @override
  void dispose() {
    _ctrl1.dispose(); _ctrl2.dispose(); _ctrl3.dispose();
    super.dispose();
  }

  String _typeFor(int idx) {
    switch (idx) { case 1: return _type1; case 2: return _type2; case 3: return _type3; }
    return 'PERCENT';
  }

  TextEditingController _ctrlFor(int idx) {
    switch (idx) { case 1: return _ctrl1; case 2: return _ctrl2; case 3: return _ctrl3; }
    return _ctrl1;
  }

  void _setType(int idx, String t) {
    setState(() {
      switch (idx) { case 1: _type1 = t; break; case 2: _type2 = t; break; case 3: _type3 = t; break; }
    });
    _ctrlFor(idx).clear();
  }

  int _calcPreview(int idx) {
    final v = double.tryParse(_ctrlFor(idx).text.replaceAll(',', '.')) ?? 0.0;
    if (v <= 0) return 0;
    final price = widget.product?.harga ?? widget.line.hargaSatuan;
    final raw = price * widget.line.qty;
    if (idx == 1) return _typeFor(idx) == 'PERCENT' ? (raw * v / 100).round() : v.round();
    int running = raw;
    for (var i = 1; i < idx; i++) {
      final prevV = double.tryParse(_ctrlFor(i).text.replaceAll(',', '.')) ?? 0.0;
      if (prevV <= 0) continue;
      final cut = _typeFor(i) == 'PERCENT' ? (running * prevV / 100).round() : prevV.round();
      running -= cut;
    }
    return _typeFor(idx) == 'PERCENT' ? (running * v / 100).round() : v.round();
  }

  int get _subtotal {
    final price = widget.product?.harga ?? widget.line.hargaSatuan;
    final raw = price * widget.line.qty;
    int running = raw;
    for (var i = 1; i <= 3; i++) { running -= _calcPreview(i); }
    return running < 0 ? 0 : running;
  }

  void _onSave() {
    final draft = context.read<DraftOrderProvider>();
    for (var idx = 1; idx <= 3; idx++) {
      final v = double.tryParse(_ctrlFor(idx).text.replaceAll(',', '.')) ?? 0.0;
      final capped = _typeFor(idx) == 'PERCENT' && v > 100 ? 100.0 : v;
      draft.setDiscountLayer(lineId: widget.line.id, layer: idx, type: _typeFor(idx), value: capped.round());
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.product?.namaBarang ?? widget.line.productId;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Diskon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text(name, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          for (var idx = 1; idx <= 3; idx++) _LayerCard(
            idx: idx, type: _typeFor(idx), controller: _ctrlFor(idx),
            preview: _calcPreview(idx), idr: _idr,
            onTypeChanged: (t) => _setType(idx, t),
            onChanged: (_) => setState(() {}),
            onClear: () { _ctrlFor(idx).clear(); setState(() {}); },
          ),
          Container(height: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 20)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Rp ${_idr.format(_subtotal)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Simpan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final int idx;
  final String type;
  final TextEditingController controller;
  final int preview;
  final NumberFormat idr;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _LayerCard({
    required this.idx, required this.type, required this.controller,
    required this.preview, required this.idr,
    required this.onTypeChanged, required this.onChanged, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = controller.text.isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DISKON $idx', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05)),
              if (!isEmpty)
                GestureDetector(
                  onTap: onClear,
                  child: Text('Hapus', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chip('%', type == 'PERCENT', () => onTypeChanged('PERCENT')),
                    _chip('Rp', type == 'NOMINAL', () => onTypeChanged('NOMINAL')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    prefixText: type == 'NOMINAL' ? 'Rp ' : null,
                    suffixText: type == 'PERCENT' ? '%' : null,
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  preview > 0 ? '−Rp ${idr.format(preview)}' : '',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
    ),
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────

class _PopupMenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PopupMenuItem({required this.label, required this.icon, required this.color, required this.onTap});
}

class _PopupMenuBtn extends StatelessWidget {
  final List<_PopupMenuItem> items;
  const _PopupMenuBtn({required this.items});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.cardSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
    child: PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textSecondary),
      tooltip: 'Menu',
      onSelected: (value) => items[int.parse(value)].onTap(),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: '$i',
            child: Row(
              children: [
                Icon(items[i].icon, size: 16, color: items[i].color),
                const SizedBox(width: 8),
                Text(items[i].label, style: TextStyle(color: items[i].color)),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _iconBtn({required IconData icon, required Color color, required VoidCallback onTap}) => Material(
  color: AppColors.cardSurface,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color == AppColors.success ? color : AppColors.border)),
  child: InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 16, color: color)),
  ),
);
