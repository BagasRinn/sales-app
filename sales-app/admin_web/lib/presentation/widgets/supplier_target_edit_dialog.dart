import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/data/models/supplier_performance.dart';
import 'package:admin_web/core/responsive_dialog.dart';

/// Opens the target-edit dialog for a (supplier, period) row in the
/// supplier performance table. The row's `target` is used as the prefill
/// (it's already resolved to current-or-carried-over by the backend).
/// On save, calls [AdminProvider.updateSupplierTarget] then refreshes the
/// table via [AdminProvider.loadSupplierPerformance].
Future<void> showSupplierTargetEditDialog(
  BuildContext context,
  AdminProvider provider, {
  required String supplierName,
  required String period,
  required String branch,
}) async {
  // Find the current row to use its resolved target as the prefill.
  // If the supplier isn't in the list (e.g. no product yet), default to 0.
  SupplierPerformanceRow? row;
  for (final r in provider.supplierPerformance) {
    if (r.supplierName == supplierName) {
      row = r;
      break;
    }
  }
  final initialValue = row != null && row.hasTarget ? row.target : 0;

  final result = await showDialog<int?>(
    context: context,
    builder: (ctx) => _SupplierTargetEditDialog(
      supplierName: supplierName,
      period: period,
      initialValue: initialValue,
    ),
  );
  if (result == null) return; // user cancelled

  try {
    await provider.updateSupplierTarget(
      branch: branch,
      supplierName: supplierName,
      period: period,
      targetValue: result,
    );
    await provider.loadSupplierPerformance(yearMonth: period, branch: branch);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan target: $e')));
    }
  }
}

class _SupplierTargetEditDialog extends StatefulWidget {
  final String supplierName;
  final String period;
  final int initialValue;
  const _SupplierTargetEditDialog({
    required this.supplierName,
    required this.period,
    required this.initialValue,
  });

  @override
  State<_SupplierTargetEditDialog> createState() =>
      _SupplierTargetEditDialogState();
}

class _SupplierTargetEditDialogState extends State<_SupplierTargetEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAlertDialog(
      title: const Text('Edit Target'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier: ${widget.supplierName}'),
            const SizedBox(height: 4),
            Text('Periode: ${widget.period}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Target (Rp)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (int.tryParse(v) == null) return 'Harus angka';
                if (int.parse(v) < 0) return 'Minimal 0';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(int.parse(_ctrl.text));
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
