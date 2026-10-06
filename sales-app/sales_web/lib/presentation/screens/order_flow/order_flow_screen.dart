import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
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
          _buildBottomBar(draft),
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
      );
      default: return const SizedBox();
    }
  }

  Widget _buildBottomBar(DraftOrderProvider draft) {
    if (_step == 3) {
      // Show cart summary at bottom
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
    super.dispose();
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

    return Column(
      children: [
        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() {}),
              ),
              if (draft.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: draft.items.length,
                    itemBuilder: (context, index) {
                      final item = draft.items[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.namaBarang} x${item.qty}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                context
                                    .read<DraftOrderProvider>()
                                    .removeItem(item.id);
                              },
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // Products
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final item = draft.items
                        .where((i) => i.productId == product.id)
                        .toList();
                    final qty = item.isNotEmpty ? item.first.qty : 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.namaBarang,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rp ${idr.format(product.harga)}',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (product.stokTersedia <= 5)
                                    Text(
                                      'Stok: ${product.stokTersedia}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: product.stokTersedia <= 0
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: qty > 0
                                      ? const Color(0xFFDC2626)
                                      : Colors.grey,
                                  onPressed: qty > 0
                                      ? () => context
                                          .read<DraftOrderProvider>()
                                          .setQty(item.first.id, qty - 1)
                                      : null,
                                ),
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '$qty',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: const Color(0xFF2563EB),
                                  onPressed: product.stokTersedia > 0
                                      ? () {
                                          context
                                              .read<DraftOrderProvider>()
                                              .addItem(product);
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Step 4: Review ──────────────────────────────────────────────────────────

class _StepReview extends StatelessWidget {
  final TextEditingController notesController;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _StepReview({
    required this.notesController,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final idr = NumberFormat('#,###', 'id');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        draft.customerName ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (draft.customerAddress != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      draft.customerAddress!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      draft.orderType,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items
          const Text(
            'Item',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...draft.items.map<Widget>((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.namaBarang,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${item.qty}x Rp ${idr.format(item.hargaSatuan)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rp ${idr.format(item.subtotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: notesController,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Tambahkan catatan untuk order ini...',
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 24),

          // Total
          Card(
            color: const Color(0xFFF8FAFC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text('Rp ${idr.format(draft.totalRaw)}'),
                    ],
                  ),
                  if (draft.totalDiscount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Diskon',
                          style: TextStyle(color: Color(0xFF059669)),
                        ),
                        Text(
                          '- Rp ${idr.format(draft.totalDiscount)}',
                          style: const TextStyle(color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Rp ${idr.format(draft.totalPrice)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Buttons
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
                flex: 2,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  child: const Text('Kirim Order'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
