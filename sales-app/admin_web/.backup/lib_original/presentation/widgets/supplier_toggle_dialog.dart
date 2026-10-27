import 'package:flutter/material.dart';
import 'package:admin_web/core/responsive_dialog.dart';
import 'package:admin_web/data/models/supplier.dart';

/// Confirmation dialog for toggling a supplier's active status. Shows the
/// product_count so the user knows the blast radius of the action.
Future<bool?> showSupplierToggleDialog(
  BuildContext context, {
  required Supplier supplier,
}) {
  final willActivate = !supplier.isActive;
  final message = willActivate
      ? 'Mengaktifkan supplier "${supplier.name}" akan menampilkan kembali '
          '${supplier.productCount} produk di aplikasi sales.'
      : 'Menonaktifkan supplier "${supplier.name}" akan menyembunyikan '
          '${supplier.productCount} produk dari aplikasi sales.';
  return showDialog<bool>(
    context: context,
    builder: (ctx) => ResponsiveAlertDialog(
      title: Text(willActivate ? 'Aktifkan Supplier?' : 'Nonaktifkan Supplier?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(willActivate ? 'Aktifkan' : 'Nonaktifkan'),
        ),
      ],
    ),
  );
}
