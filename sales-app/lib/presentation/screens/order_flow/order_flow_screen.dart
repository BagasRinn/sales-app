import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system.dart';
import '../../../data/models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/draft_order_provider.dart';
import 'step_pick_customer.dart';
import 'step_pick_order_type.dart';
import 'step_pick_products.dart';
import 'step_review.dart';

class OrderFlowScreen extends StatefulWidget {
  const OrderFlowScreen({super.key});

  @override
  State<OrderFlowScreen> createState() => _OrderFlowScreenState();
}

class _OrderFlowScreenState extends State<OrderFlowScreen> {
  int _step = 1;
  bool _isSubmitting = false;

  Future<bool> _confirmCancel() async {
    final draft = context.read<DraftOrderProvider>();
    if (!draft.hasCustomer && !draft.hasItems) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batal Order?'),
        content: const Text(
          'Data yang sudah dimasukkan akan hilang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjut Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batal'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _next() {
    if (_step < 4) setState(() => _step++);
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    }
  }

  /// Back dari step 3 (Produk) ke step 2 (Tipe). Kalau sudah ada item, dialog konfirmasi.
  Future<void> _backFromProducts() async {
    final draft = context.read<DraftOrderProvider>();
    if (!draft.hasItems) {
      _back();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kembali ke halaman tipe order?'),
        content: const Text(
          'Item & diskon yang sudah dipilih tetap tersimpan. '
          'Anda bisa ganti tipe order tanpa kehilangan item yang dipilih.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tetap di sini'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _back();
    }
  }

  Future<void> _handleClose() async {
    if (await _confirmCancel()) {
      if (mounted) {
        context.read<DraftOrderProvider>().reset();
        Navigator.pop(context);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showLoading(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Row(
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(width: 20),
              Text(message, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  void _hideLoading() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _submitDraft() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    try {
      final draft = context.read<DraftOrderProvider>();
      if (draft.customerId == null) return;

      _showLoading('Menyimpan draft...');
      final result = await context.read<OrderProvider>().createOrder(
            customerId: draft.customerId!,
            items: draft.buildItemsPayload(),
            notes: draft.notes,
            orderType: draft.orderType,
          );
      _hideLoading();

      if (!mounted) return;

      if (result != null) {
        context.read<DraftOrderProvider>().reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft disimpan'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        final err = context.read<OrderProvider>().errorMessage ?? 'Gagal menyimpan draft';
        _showError(err);
      }
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> _submitToPENDING() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    try {
      final draft = context.read<DraftOrderProvider>();
      if (draft.customerId == null) return;

      final orderProvider = context.read<OrderProvider>();

      _showLoading(
        draft.isEditingPending ? 'Menyimpan perubahan...' : 'Mengirim order...',
      );
      Order? result;
      if (draft.isEditing && draft.editingOrderId != null) {
        result = await orderProvider.updateDraftOrder(
          orderId: draft.editingOrderId!,
          customerId: draft.customerId!,
          items: draft.buildItemsPayload(),
          notes: draft.notes,
          orderType: draft.orderType,
        );
      } else {
        result = await orderProvider.createOrder(
          customerId: draft.customerId!,
          items: draft.buildItemsPayload(),
          notes: draft.notes,
          orderType: draft.orderType,
        );
      }

      if (!mounted || result == null) {
        _hideLoading();
        final err = orderProvider.errorMessage ?? 'Gagal';
        _showError(err);
        return;
      }

      // Edit PENDING: order sudah PENDING, skip submit (status tetap PENDING).
      // Edit DRAFT / order baru: perlu submit untuk jadi PENDING.
      bool success = true;
      if (!draft.isEditingPending) {
        success = await orderProvider.submitOrder(result.id);
      }
      _hideLoading();
      if (!mounted) return;

      if (success) {
        context.read<DraftOrderProvider>().reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(draft.isEditingPending || draft.isEditing
                ? 'Order berhasil diperbarui'
                : 'Order berhasil dikirim'),
            backgroundColor: AppColors.success,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
      } else {
        final err = orderProvider.errorMessage ?? 'Gagal mengirim order';
        _showError(err);
      }
    } finally {
      _isSubmitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final isEditing = draft.isEditing;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmCancel();
        if (shouldPop && context.mounted) {
          context.read<DraftOrderProvider>().reset();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleClose,
          ),
          title: Text(
            isEditing
                ? (draft.isEditingPending ? 'Edit Order' : 'Edit Draft')
                : 'Order Baru',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        body: Column(
          children: [
            _StepIndicator(currentStep: _step),
            Expanded(
              child: switch (_step) {
                1 => StepPickCustomer(onNext: _next),
                2 => StepPickOrderType(onNext: _next, onBack: _back),
                3 => StepPickProducts(onNext: _next, onBack: _backFromProducts),
                _ => StepReview(
                    onBack: _back,
                    onSaveDraft: _submitDraft,
                    onSubmit: _submitToPENDING,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  static const _labels = ['Toko', 'Tipe', 'Produk', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            _dot(_labels[i], i + 1, currentStep),
            if (i < _labels.length - 1) _connector(i + 1, currentStep),
          ],
        ],
      ),
    );
  }

  Widget _dot(String label, int step, int currentStep) {
    final active = step <= currentStep;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.borderLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: active
              ? Icon(
                  step < currentStep ? Icons.check : null,
                  size: 14,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: active ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _connector(int beforeStep, int currentStep) {
    final active = currentStep > beforeStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: active ? AppColors.primaryLight : AppColors.borderLight,
      ),
    );
  }
}
