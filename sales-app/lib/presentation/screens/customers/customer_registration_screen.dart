import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/draft_order_provider.dart';
import '../../providers/product_provider.dart';
import '../order_flow/order_flow_screen.dart';

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
  final _kotaCtl = TextEditingController();
  final _kelurahanCtl = TextEditingController();
  final _areaCtl = TextEditingController();
  // Kode Area (grouping key untuk sales coverage) — dropdown dari distinct
  // values di customers, plus "Lainnya..." fallback untuk area baru.
  List<String> _kodeAreaOptions = [];
  String? _kodeArea;
  bool _kodeAreaIsCustom = false;
  final _kodeAreaCtl = TextEditingController();
  String? _tipeLanggananKategori; // PASAR | NON PASAR
  final _namaPasarCtl = TextEditingController();

  // Section 3: Kredit
  final _batasKreditCtl = TextEditingController();

  // Section 4: Channel
  String? _channelKategori;
  String? _clusterLangganan;
  final _keyAccountCtl = TextEditingController();

  // Section 5: Salesman (auto-fill dari akun login, read-only)
  final _kodeSalesmanCtl = TextEditingController();
  final _namaSalesmanCtl = TextEditingController();
  String? _siklusKunjungan;
  String? _hariKunjungan;

  // Toggle bareng order
  bool _barengOrder = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.username != null) _kodeSalesmanCtl.text = auth.username!;
      if (auth.nama != null) _namaSalesmanCtl.text = auth.nama!;
      // Load dropdown options. Silent on failure: empty list → form tetap
      // usable via "Lainnya (ketik manual)...".
      context.read<CustomerRepository>().getKodeAreas().then((areas) {
        if (!mounted) return;
        setState(() => _kodeAreaOptions = areas);
      }).catchError((_) {
        // sengaja di-swallow: dropdown kosong bukan error
      });
    });
  }

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

  static const _tipeLanggananKategoriOptions = ['PASAR', 'NON PASAR'];

  static const _tipeBayarOptions = ['TUNAI', 'KREDIT'];

  static const _siklusKunjunganOptions = [
    'W (Mingguan)',
    'W1 W3 (Minggu Ganjil)',
    'W2 W4 (Minggu Genap)',
  ];

  static const _hariKunjunganOptions = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

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
    _kotaCtl.dispose();
    _kelurahanCtl.dispose();
    _areaCtl.dispose();
    _kodeAreaCtl.dispose();
    _namaPasarCtl.dispose();
    _batasKreditCtl.dispose();
    _keyAccountCtl.dispose();
    _kodeSalesmanCtl.dispose();
    _namaSalesmanCtl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    int? parseIntOrNull(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }

    final tipeLangganan =
        _tipeLanggananKategori == 'PASAR' && _namaPasarCtl.text.trim().isNotEmpty
            ? 'PASAR (${_namaPasarCtl.text.trim()})'
            : _tipeLanggananKategori;

    // KREDIT: kirim jangka_kredit_hari + batas_kredit_rupiah.
    // TUNAI: kirim null supaya tidak mengisi field (backend hanya accept null).
    final isKredit = _tipePembayaran == 'KREDIT';

    return {
      // Section 1
      'nama_langganan': _namaCtl.text.trim(),
      'nomor_id_ktp': _orNull(_ktpCtl.text),
      'alamat_ktp': _orNull(_alamatKtpCtl.text),
      'nama_kontak_pemilik': _kontakCtl.text.trim(),
      'telpon_hp': _telponCtl.text.trim(),
      'alamat_kirim': _alamatKirimCtl.text.trim(),
      'propinsi': _propinsiCtl.text.trim(),
      'kecamatan': _kecamatanCtl.text.trim(),
      'kota': _kotaCtl.text.trim(),
      'kelurahan': _kelurahanCtl.text.trim(),
      'area_route': _orNull(_areaCtl.text),
      'kode_area': (_kodeArea == null || _kodeArea!.isEmpty) ? null : _kodeArea,
      'tipe_langganan': tipeLangganan,
      // Section 2
      'tipe_pembayaran': _tipePembayaran,
      'nama_pasar': _orNull(_namaPasarCtl.text),
      'jangka_kredit_hari': isKredit ? 14 : null,
      // Section 3
      'batas_kredit_rupiah': isKredit ? parseIntOrNull(_batasKreditCtl.text) : null,
      // Section 4
      'channel_kategori': _channelKategori,
      // Section 5
      'key_account_ref_id': _orNull(_keyAccountCtl.text),
      'cluster_langganan': _clusterLangganan,
      'kode_salesman': _kodeSalesmanCtl.text.trim().isEmpty ? null : _kodeSalesmanCtl.text.trim(),
      'nama_salesman': _namaSalesmanCtl.text.trim().isEmpty ? null : _namaSalesmanCtl.text.trim(),
      'siklus_kunjungan': _siklusKunjungan,
      'hari_kunjungan': _hariKunjungan,
      // Flag: buat customer langsung juga (untuk flow bareng order)
      'bareng_order': _barengOrder,
    };
  }

  // ignore: prefer_final_fields
  String? _tipePembayaran;

  String? _orNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _submit() async {
    // === Validasi ===
    if (_namaCtl.text.trim().isEmpty) {
      _snack('Nama langganan wajib diisi');
      return;
    }
    if (_kontakCtl.text.trim().isEmpty) {
      _snack('Nama kontak/pemilik wajib diisi');
      return;
    }
    if (_telponCtl.text.trim().isEmpty) {
      _snack('Telpon/HP wajib diisi');
      return;
    }
    if (_alamatKirimCtl.text.trim().isEmpty) {
      _snack('Alamat kirim wajib diisi');
      return;
    }
    if (_propinsiCtl.text.trim().isEmpty) {
      _snack('Propinsi wajib diisi');
      return;
    }
    if (_kecamatanCtl.text.trim().isEmpty) {
      _snack('Kecamatan wajib diisi');
      return;
    }
    if (_kotaCtl.text.trim().isEmpty) {
      _snack('Kota wajib diisi');
      return;
    }
    if (_kelurahanCtl.text.trim().isEmpty) {
      _snack('Kelurahan wajib diisi');
      return;
    }
    if (_tipeLanggananKategori == null) {
      _snack('Tipe langganan (Pasar/Non Pasar) wajib dipilih');
      return;
    }
    if (_tipeLanggananKategori == 'PASAR' && _namaPasarCtl.text.trim().isEmpty) {
      _snack('Nama Pasar wajib diisi');
      return;
    }
    if (_tipePembayaran == null) {
      _snack('Tipe pembayaran (Tunai/Kredit) wajib dipilih');
      return;
    }
    if (_channelKategori == null) {
      _snack('Channel/kategori wajib dipilih');
      return;
    }
    if (_siklusKunjungan == null) {
      _snack('Siklus kunjungan wajib dipilih');
      return;
    }
    if (_hariKunjungan == null) {
      _snack('Hari kunjungan wajib dipilih');
      return;
    }
    if (_tipePembayaran == 'KREDIT' && _batasKreditCtl.text.trim().isEmpty) {
      _snack('Batas kredit wajib diisi untuk pembayaran Kredit');
      return;
    }
    // === End validasi ===

    final repo = context.read<CustomerRepository>();
    final scaffold = ScaffoldMessenger.of(context);

    final confirmed = await _confirmSubmit();
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = _buildPayload();
      final result = await repo.submitCustomerRegistration(payload);
      if (!mounted) return;

      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            _barengOrder
                ? 'Customer berhasil diajukan. Lanjut buat order.'
                : 'Pengajuan customer terkirim. Admin akan review dan approve.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      if (_barengOrder && result.barengCustomerId != null) {
        // Customer sudah dibuat backend saat bareng_order=True.
        final newCustomerId = result.barengCustomerId;
        final newCustomerName = _namaCtl.text.trim();

        if (newCustomerId != null && mounted) {
          final draft = context.read<DraftOrderProvider>();
          draft.reset();
          draft.setCustomerDirect(id: newCustomerId, namaToko: newCustomerName);

          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const OrderFlowScreen(),
            ),
          );
          return;
        }
      }

      if (mounted) Navigator.of(context).pop(true);
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
          // ============================================================
          // Toggle: Bareng Order?
          // ============================================================
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.infoBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    Text(
                      'Langsung buat order juga?',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _toggleChip(
                      label: 'Ya',
                      selected: _barengOrder,
                      onSelected: () => setState(() => _barengOrder = true),
                    ),
                    const SizedBox(width: 8),
                    _toggleChip(
                      label: 'Tidak',
                      selected: !_barengOrder,
                      onSelected: () => setState(() => _barengOrder = false),
                    ),
                  ],
                ),
                if (_barengOrder) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Setelah customer disubmit, akan langsung diarahkan ke langkah order.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============================================================
          // Section 1: Identitas Pelanggan
          // ============================================================
          _SectionHeader(title: '1. Identitas Pelanggan'),
          const SizedBox(height: 8),
          _Field(label: 'Nama Langganan / Outlet *', controller: _namaCtl, required: true),
          _Field(label: 'Nomor ID /KTP', controller: _ktpCtl),
          _Field(label: 'Alamat KTP', controller: _alamatKtpCtl, maxLines: 3),
          _Field(label: 'Nama Kontak /Pemilik', controller: _kontakCtl),
          _Field(label: 'Telpon / HP', controller: _telponCtl, keyboardType: TextInputType.phone),
          _Field(label: 'Alamat Kirim', controller: _alamatKirimCtl, maxLines: 3),
          _Field(label: 'Propinsi', controller: _propinsiCtl),
          _Field(label: 'Kecamatan', controller: _kecamatanCtl),
          _Field(label: 'Kota', controller: _kotaCtl),
          _Field(label: 'Kelurahan', controller: _kelurahanCtl),
          _Field(label: 'Area / Route', controller: _areaCtl),
          // Kode Area — dropdown dari distinct values di customers.
          // Free-text fallback "Lainnya..." untuk area baru (admin
          // belum punya record-nya). Mirrors customers.kode_area.
          const SizedBox(height: 4),
          _FieldLabel(text: 'Kode Area'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _kodeAreaIsCustom
                        ? '__custom__'
                        : (_kodeAreaOptions.contains(_kodeArea) ? _kodeArea : null),
                    hint: const Text('Pilih kode area'),
                    isExpanded: true,
                    items: [
                      ..._kodeAreaOptions.map(
                        (a) => DropdownMenuItem<String>(
                          value: a,
                          child: Text(a),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: '__custom__',
                        child: Text('Lainnya (ketik manual)…'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        if (v == '__custom__') {
                          _kodeAreaIsCustom = true;
                          _kodeArea = _kodeAreaCtl.text.trim();
                        } else {
                          _kodeAreaIsCustom = false;
                          _kodeArea = v;
                        }
                      });
                    },
                  ),
                ),
                if (_kodeAreaIsCustom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _kodeAreaCtl,
                      onChanged: (v) => _kodeArea = v.trim(),
                      decoration: const InputDecoration(
                        labelText: 'Kode Area baru',
                        hintText: 'Misal: MULIA2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _FieldLabel(text: 'Tipe Langganan'),
          _ChoiceRow(
            options: _tipeLanggananKategoriOptions,
            selected: _tipeLanggananKategori,
            onSelected: (v) => setState(() => _tipeLanggananKategori = v),
          ),
          // Nama Pasar — hanya kalau PASAR
          if (_tipeLanggananKategori == 'PASAR') ...[
            const SizedBox(height: 4),
            _Field(
              label: 'Nama Pasar *',
              controller: _namaPasarCtl,
              required: true,
              hintText: 'Contoh: Pasar Senen',
            ),
          ],
          const SizedBox(height: 20),

          // ============================================================
          // Section 2: Tipe Pembayaran
          // ============================================================
          _SectionHeader(title: '2. Tipe Pembayaran'),
          const SizedBox(height: 8),
          _ChoiceRow(
            options: _tipeBayarOptions,
            selected: _tipePembayaran,
            onSelected: (v) => setState(() => _tipePembayaran = v),
          ),
          // Jangka kredit — hanya tampil jika KREDIT
          if (_tipePembayaran == 'KREDIT') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Text(
                    'Jangka Kredit (Hari): ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '14 Hari',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tipePembayaran == null) ...[
            const SizedBox(height: 8),
            Text(
              'Pilih tipe pembayaran di atas untuk melihat detail kredit.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ============================================================
          // Section 3: Batas Kredit — hanya tampil jika KREDIT
          // ============================================================
          if (_tipePembayaran == 'KREDIT') ...[
            _SectionHeader(title: '3. Batas Kredit (Rp)'),
            const SizedBox(height: 8),
            _Field(
              label: 'Batas Kredit *',
              controller: _batasKreditCtl,
              keyboardType: TextInputType.number,
              required: true,
            ),
            const SizedBox(height: 20),
          ],

          // ============================================================
          // Section 4: Channel / Kategori Langganan
          // ============================================================
          _SectionHeader(title: '4. Channel / Kategori'),
          const SizedBox(height: 8),
          _FieldLabel(text: 'Tipe Langganan'),
          _ChoiceWrap(
            options: _channelOptions,
            selected: _channelKategori,
            onSelected: (v) => setState(() => _channelKategori = v),
          ),
          _Field(label: 'Key Account (REF ID)', controller: _keyAccountCtl),
          _FieldLabel(text: 'Cluster Langganan'),
          _ClusterField(
            selected: _clusterLangganan,
            onChanged: (v) => setState(() => _clusterLangganan = v),
          ),
          const SizedBox(height: 20),

          // ============================================================
          // Section 5: Kunjungan Salesman
          // ============================================================
          _SectionHeader(title: '5. Kunjungan Salesman'),
          const SizedBox(height: 8),
          // Kode & Nama Salesman — auto-fill, read-only display.
          _ReadOnlyField(label: 'Kode Salesman', value: _kodeSalesmanCtl.text),
          _ReadOnlyField(label: 'Nama Salesman', value: _namaSalesmanCtl.text),
          _FieldLabel(text: 'Siklus Kunjungan'),
          _ChoiceWrap(
            options: _siklusKunjunganOptions,
            selected: _siklusKunjungan,
            onSelected: (v) => setState(() => _siklusKunjungan = v),
          ),
          _FieldLabel(text: 'Hari Kunjungan'),
          _ChoiceWrap(
            options: _hariKunjunganOptions,
            selected: _hariKunjungan,
            onSelected: (v) => setState(() => _hariKunjungan = v),
          ),
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
            label: Text(_barengOrder ? 'Submit & Buat Order' : 'Submit Pengajuan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.info : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.info : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClusterField extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ClusterField({required this.selected, required this.onChanged});

  static const _clusterOptions = ['STOCKIEST', 'SUBDIST', 'NO CLUSTER'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _clusterOptions.map((o) {
        final isSel = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: isSel,
          onSelected: (sel) {
            onChanged(sel ? o : null);
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

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;
  final String? hintText;

  const _Field({
    required this.label,
    required this.controller,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.hintText,
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
          hintText: hintText,
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

/// Read-only display field — greyed out, tidak bisa diedit.
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: value),
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
        ),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bareng Order — local cart item model
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Product Search Bottom Sheet
// ---------------------------------------------------------------------------

class _ProductSearchSheet extends StatefulWidget {
  final String orderType;
  const _ProductSearchSheet({required this.orderType});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _searchCtl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Trigger load with current order type filter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductProvider>().loadProducts(
        orderType: widget.orderType,
      );
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> products) {
    if (_search.isEmpty) return products;
    final q = _search.toLowerCase();
    return products.where((p) {
      return p.namaBarang.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = _filtered(productProvider.products);
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari produk...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: productProvider.isLoading && products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? Center(
                          child: Text(
                            'Produk tidak ditemukan',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: products.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final p = products[i];
                            final isOutOfStock = p.stokTersedia == 0;
                            return Material(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: isOutOfStock ? null : () => Navigator.pop(context, p),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isOutOfStock
                                          ? AppColors.borderLight.withValues(alpha: 0.5)
                                          : AppColors.borderLight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.namaBarang,
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: isOutOfStock
                                                    ? AppColors.textMuted
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Stok: ${p.stokTersedia}',
                                              style: AppTextStyles.bodySmall.copyWith(
                                                color: isOutOfStock
                                                    ? AppColors.error
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        currency.format(p.harga),
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isOutOfStock
                                              ? AppColors.textMuted
                                              : AppColors.primaryLight,
                                        ),
                                      ),
                                      if (isOutOfStock) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Habis',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
