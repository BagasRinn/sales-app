import 'package:flutter/material.dart';
import 'package:admin_web/core/responsive_dialog.dart';

/// Result dari dialog create supplier — null kalau user cancel.
class SupplierCreateResult {
  final String name;
  final String orderType;
  const SupplierCreateResult({required this.name, required this.orderType});
}

/// Opens a small dialog to create a new supplier. Manager dapat memilih
/// order_type (REGULER / 4P) saat create — backend default REGULER kalau
/// tidak dikirim.
Future<SupplierCreateResult?> showSupplierCreateDialog(BuildContext context) async {
  final nameController = TextEditingController();
  String orderType = 'REGULER';
  final formKey = GlobalKey<FormState>();
  return showDialog<SupplierCreateResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocalState) => ResponsiveAlertDialog(
        title: const Text('Buat Supplier Baru'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Supplier',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tipe Order',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'REGULER',
                    label: Text('Reguler'),
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                  ButtonSegment(
                    value: '4P',
                    label: Text('4P'),
                    icon: Icon(Icons.local_offer_outlined),
                  ),
                ],
                selected: {orderType},
                onSelectionChanged: (sel) =>
                    setLocalState(() => orderType = sel.first),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(SupplierCreateResult(
                  name: nameController.text.trim(),
                  orderType: orderType,
                ));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}
