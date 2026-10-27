import 'package:flutter/material.dart';
import 'package:admin_web/core/responsive_dialog.dart';
import 'package:admin_web/data/models/supplier.dart';

/// Dialog untuk edit order_type supplier existing (MANAGER only).
/// Return string orderType baru kalau user save, null kalau cancel.
///
/// Perhatian: backend akan cascade update ke semua products supplier ini.
/// Tampilkan warning yang jelas di dialog.
Future<String?> showSupplierEditOrderTypeDialog(
  BuildContext context, {
  required Supplier supplier,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String selected = supplier.orderType;
      return StatefulBuilder(
        builder: (ctx, setLocalState) => ResponsiveAlertDialog(
          title: Text('Ubah Tipe Order — ${supplier.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipe order menentukan kategori order yang memakai produk supplier ini. '
                'Perubahan akan berlaku ke SEMUA produk dari supplier ini.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
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
                selected: {selected},
                onSelectionChanged: (sel) =>
                    setLocalState(() => selected = sel.first),
              ),
              if (supplier.productCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Perubahan akan mempengaruhi ${supplier.productCount} produk.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: selected == supplier.orderType
                  ? null
                  : () => Navigator.of(ctx).pop(selected),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
    },
  );
}
