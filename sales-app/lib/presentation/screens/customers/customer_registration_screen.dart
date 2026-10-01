import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system.dart';
import '../../../data/repositories/customer_repository.dart';

/// Form pengajuan customer baru dari sales.
/// 5 section: Identitas, Pembayaran, Kredit, Channel, Salesman.
/// Setelah submit, status langsung PENDING. Admin/manager yang approve di admin web.
class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState extends State<CustomerRegistrationScreen> {
  // Section 1: Identitas
  final _namaCtl = TextEditingController();
  final _ktpCtl = TextEditingController();
  final _alamatKtpCtl = TextEditingController();
  final _kontakCtl = TextEditingController();
  final _telponCtl = TextEditingController();
  final _alamatKirimCtl = TextEditingController();
  final _propinsiCtl = TextEditingController();
  final _kecamatanCtl = TextEditingController();
  final _areaCtl = TextEditingController();
  final _tipeLanggananCtl = TextEditingController();

  // Section 2: Pembayaran
  String? _tipePembayaran;
  final _namaPasarCtl = TextEditingController();
  final _jangkaKreditCtl = TextEditingController();

  // Section 3: Kredit
  final _batasKreditCtl = TextEditingController();

  // Section 4: Channel
  String? _channelKategori;

  // Section 5: Salesman
  final _keyAccountCtl = TextEditingController();
  final _clusterCtl = TextEditingController();
  final _salesmanCtl = TextEditingController();
  final _siklusCtl = TextEditingController();

  bool _isSubmitting = false;

  static const _channelOptions = [
    'GT',
    'FOSR',
    'MTKA',
    'MTI',
    'BABYSHOP',
    'COSMETICS',
    'PHARMA',
    'B2B NON FOOD',
    'MATERIAL BANGUNAN',
    'LANGGANAN KANTOR',
  ];

  static const _tipeBayarOptions = ['NON PASAR', 'PASAR', 'TUNAI', 'KREDIT'];

  @override
  void dispose() {
    _namaCtl.dispose();
    _ktpCtl.dispose();
    _alamatKtpCtl.dispose();
    _kontakCtl.dispose();
    _telponCtl.dispose();
    _alamatKirimCtl.dispose();
    _propinsiCtl.dispose();
    _kecamatanCtl.dispose();
    _areaCtl.dispose();
    _tipeLanggananCtl.dispose();
    _namaPasarCtl.dispose();
    _jangkaKreditCtl.dispose();
    _batasKreditCtl.dispose();
    _keyAccountCtl.dispose();
    _clusterCtl.dispose();
    _salesmanCtl.dispose();
    _siklusCtl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    int? parseIntOrNull(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }

    return {
      // Section 1
      'nama_langganan': _namaCtl.text.trim(),
      'nomor_id_ktp': _orNull(_ktpCtl.text),
      'alamat_ktp': _orNull(_alamatKtpCtl.text),
      'nama_kontak_pemilik': _orNull(_kontakCtl.text),
      'telpon_hp': _orNull(_telponCtl.text),
      'alamat_kirim': _orNull(_alamatKirimCtl.text),
      'propinsi': _orNull(_propinsiCtl.text),
      'kecamatan': _orNull(_kecamatanCtl.text),
      'area_route': _orNull(_areaCtl.text),
      'tipe_langganan': _orNull(_tipeLanggananCtl.text),
      // Section 2
      'tipe_pembayaran': _tipePembayaran,
      'nama_pasar': _orNull(_namaPasarCtl.text),
      'jangka_kredit_hari': parseIntOrNull(_jangkaKreditCtl.text),
      // Section 3
      'batas_kredit_rupiah': parseIntOrNull(_batasKreditCtl.text),
      // Section 4
      'channel_kategori': _channelKategori,
      // Section 5
      'key_account_ref_id': _orNull(_keyAccountCtl.text),
      'cluster_langganan': _orNull(_clusterCtl.text),
      'kode_nama_salesman': _orNull(_salesmanCtl.text),
      'siklus_kunjungan': _orNull(_siklusCtl.text),
    };
  }

  String? _orNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _submit() async {
    if (_namaCtl.text.trim().isEmpty) {
      _snack('Nama langganan wajib diisi');
      return;
    }

    final repo = context.read<CustomerRepository>();
    final scaffold = ScaffoldMessenger.of(context);

    final confirmed = await _confirmSubmit();
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await repo.submitCustomerRegistration(_buildPayload());
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(
          content: Text(
            'Pengajuan customer terkirim. Admin akan review dan approve.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true); // return true supaya caller bisa refresh
    } catch (e) {
      _snack('Gagal kirim pengajuan: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool?> _confirmSubmit() async {
    final nama = _namaCtl.text.trim();
    final alamat = _alamatKirimCtl.text.trim();
    final repo = context.read<CustomerRepository>();

    Map<String, dynamic>? dupResult;
    try {
      dupResult = await repo.checkDuplicateCustomer(
        name: nama,
        alamat: alamat,
      );
    } catch (_) {
      // Kalau check gagal, tetap izinkan submit
      dupResult = null;
    }

    if (!mounted) return null;
    final hasDup = dupResult?['has_duplicate'] == true;
    final matches = (dupResult?['matches'] as List?) ?? [];

    final confirmMessage = hasDup
        ? 'Toko dengan nama "$nama"${alamat.isNotEmpty ? ' di alamat tersebut' : ''} sudah pernah terdaftar. Lanjut submit?'
        : 'Kirim pengajuan customer "$nama"?';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Submit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(confirmMessage),
            if (hasDup) ...[
              const SizedBox(height: 12),
              ...matches.take(3).map((m) {
                final c = m as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${c['kode'] ?? '-'} — ${c['nama_toko']}${c['alamat'] != null ? ' (${c['alamat']})' : ''}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                );
              }),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Customer Baru'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _SectionHeader(title: '1. Identitas Pelanggan'),
          const SizedBox(height: 8),
          _Field(label: 'Nama Langganan / Outlet *', controller: _namaCtl, required: true),
          _Field(label: 'Nomor ID / KTP', controller: _ktpCtl),
          _Field(label: 'Alamat KTP', controller: _alamatKtpCtl, maxLines: 3),
          _Field(label: 'Nama Kontak / Pemilik', controller: _kontakCtl),
          _Field(label: 'Telpon / HP', controller: _telponCtl, keyboardType: TextInputType.phone),
          _Field(label: 'Alamat Kirim', controller: _alamatKirimCtl, maxLines: 3),
          _Field(label: 'Propinsi', controller: _propinsiCtl),
          _Field(label: 'Kecamatan', controller: _kecamatanCtl),
          _Field(label: 'Area / Route', controller: _areaCtl),
          _Field(label: 'Tipe Langganan', controller: _tipeLanggananCtl),
          const SizedBox(height: 24),

          _SectionHeader(title: '2. Tipe Pembayaran'),
          const SizedBox(height: 8),
          _ChoiceRow(
            options: _tipeBayarOptions,
            selected: _tipePembayaran,
            onSelected: (v) => setState(() => _tipePembayaran = v),
          ),
          const SizedBox(height: 8),
          _Field(label: 'Nama Pasar', controller: _namaPasarCtl),
          _Field(
            label: 'Jangka Kredit (hari)',
            controller: _jangkaKreditCtl,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          _SectionHeader(title: '3. Batas Kredit (Rp)'),
          const SizedBox(height: 8),
          _Field(
            label: 'Batas Kredit',
            controller: _batasKreditCtl,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          _SectionHeader(title: '4. Channel / Kategori'),
          const SizedBox(height: 8),
          _ChoiceWrap(
            options: _channelOptions,
            selected: _channelKategori,
            onSelected: (v) => setState(() => _channelKategori = v),
          ),
          const SizedBox(height: 24),

          _SectionHeader(title: '5. Salesman'),
          const SizedBox(height: 8),
          _Field(label: 'Key Account (REF ID)', controller: _keyAccountCtl),
          _Field(label: 'Cluster Langganan', controller: _clusterCtl),
          _Field(label: 'Kode & Nama Salesman', controller: _salesmanCtl),
          _Field(label: 'Siklus Kunjungan', controller: _siklusCtl),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: const Text('Submit Pengajuan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.cardSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: isSel,
          onSelected: (sel) {
            if (sel) onSelected(o);
          },
          selectedColor: AppColors.primaryLight,
          labelStyle: TextStyle(
            color: isSel ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: isSel,
          onSelected: (sel) {
            if (sel) onSelected(o);
          },
          selectedColor: AppColors.primaryLight,
          labelStyle: TextStyle(
            color: isSel ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }
}
