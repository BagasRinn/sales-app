import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../core/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/draft_order_provider.dart';
import '../order_flow/order_flow_screen.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() => _CustomerRegistrationScreenState();
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

  List<String> _kodeAreaOptions = [];
  String? _kodeArea;
  bool _kodeAreaIsCustom = false;
  final _kodeAreaCtl = TextEditingController();
  String? _tipeLanggananKategori;
  final _namaPasarCtl = TextEditingController();

  // Section 2: Pembayaran
  String? _tipePembayaran;
  final _batasKreditCtl = TextEditingController();

  // Section 3: Channel
  String? _channelKategori;
  String? _clusterLangganan;
  final _keyAccountCtl = TextEditingController();

  // Section 4: Salesman
  final _kodeSalesmanCtl = TextEditingController();
  final _namaSalesmanCtl = TextEditingController();
  String? _siklusKunjungan;
  String? _hariKunjungan;

  // Bareng Order toggle
  bool _barengOrder = false;

  bool _isSubmitting = false;

  static const _channelOptions = [
    'GT', 'FOSR', 'MTKA', 'MTI', 'BABYSHOP', 'COSMETICS',
    'PHARMA', 'B2B NON FOOD', 'MATERIAL BANGUNAN', 'LANGGANAN KANTOR',
  ];

  static const _tipeLanggananKategoriOptions = ['PASAR', 'NON PASAR'];
  static const _tipeBayarOptions = ['TUNAI', 'KREDIT'];
  static const _siklusKunjunganOptions = [
    'W (Mingguan)', 'W1 W3 (Minggu Ganjil)', 'W2 W4 (Minggu Genap)',
  ];
  static const _hariKunjunganOptions = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.username != null) _kodeSalesmanCtl.text = auth.username!;
      if (auth.nama != null) _namaSalesmanCtl.text = auth.nama!;
      // Load kode area options silently
      CustomerRepository(context.read<ApiService>()).getKodeAreas().then((areas) {
        if (!mounted) return;
        setState(() => _kodeAreaOptions = areas);
      }).catchError((_) {});
    });
  }

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

  String? _orNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
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

    final isKredit = _tipePembayaran == 'KREDIT';

    return {
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
      'tipe_pembayaran': _tipePembayaran,
      'nama_pasar': _orNull(_namaPasarCtl.text),
      'jangka_kredit_hari': isKredit ? 14 : null,
      'batas_kredit_rupiah': isKredit ? parseIntOrNull(_batasKreditCtl.text) : null,
      'channel_kategori': _channelKategori,
      'key_account_ref_id': _orNull(_keyAccountCtl.text),
      'cluster_langganan': _clusterLangganan,
      'kode_salesman': _kodeSalesmanCtl.text.trim().isEmpty ? null : _kodeSalesmanCtl.text.trim(),
      'nama_salesman': _namaSalesmanCtl.text.trim().isEmpty ? null : _namaSalesmanCtl.text.trim(),
      'siklus_kunjungan': _siklusKunjungan,
      'hari_kunjungan': _hariKunjungan,
      'bareng_order': _barengOrder,
    };
  }

  Future<void> _submit() async {
    if (_namaCtl.text.trim().isEmpty) { _snack('Nama langganan wajib diisi'); return; }
    if (_kontakCtl.text.trim().isEmpty) { _snack('Nama kontak/pemilik wajib diisi'); return; }
    if (_telponCtl.text.trim().isEmpty) { _snack('Telpon/HP wajib diisi'); return; }
    if (_alamatKirimCtl.text.trim().isEmpty) { _snack('Alamat kirim wajib diisi'); return; }
    if (_propinsiCtl.text.trim().isEmpty) { _snack('Propinsi wajib diisi'); return; }
    if (_kecamatanCtl.text.trim().isEmpty) { _snack('Kecamatan wajib diisi'); return; }
    if (_kotaCtl.text.trim().isEmpty) { _snack('Kota wajib diisi'); return; }
    if (_kelurahanCtl.text.trim().isEmpty) { _snack('Kelurahan wajib diisi'); return; }
    if (_tipeLanggananKategori == null) { _snack('Tipe langganan wajib dipilih'); return; }
    if (_tipeLanggananKategori == 'PASAR' && _namaPasarCtl.text.trim().isEmpty) {
      _snack('Nama pasar wajib diisi');
      return;
    }
    if (_tipePembayaran == null) { _snack('Tipe pembayaran wajib dipilih'); return; }
    if (_channelKategori == null) { _snack('Channel/kategori wajib dipilih'); return; }
    if (_siklusKunjungan == null) { _snack('Siklus kunjungan wajib dipilih'); return; }
    if (_hariKunjungan == null) { _snack('Hari kunjungan wajib dipilih'); return; }
    if (_tipePembayaran == 'KREDIT' && _batasKreditCtl.text.trim().isEmpty) {
      _snack('Batas kredit wajib diisi untuk pembayaran Kredit');
      return;
    }

    final repo = CustomerRepository(context.read<ApiService>());
    final scaffold = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);
    try {
      final result = await repo.submitCustomerRegistration(_buildPayload());
      if (!mounted) return;

      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            _barengOrder
                ? 'Customer berhasil diajukan. Lanjut buat order.'
                : 'Pengajuan customer terkirim. Admin akan review.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      if (_barengOrder && result.barengCustomerId != null) {
        final draft = context.read<DraftOrderProvider>();
        draft.reset();
        draft.setCustomerDirect(id: result.barengCustomerId!, namaToko: _namaCtl.text.trim());
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OrderFlowScreen()),
        );
        return;
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Gagal kirim pengajuan: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengajuan Customer Baru'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Bareng Order toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 18, color: AppColors.info),
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
                    _toggleChip(label: 'Ya', selected: _barengOrder, onSelected: () => setState(() => _barengOrder = true)),
                    const SizedBox(width: 8),
                    _toggleChip(label: 'Tidak', selected: !_barengOrder, onSelected: () => setState(() => _barengOrder = false)),
                  ],
                ),
                if (_barengOrder) ...[
                  const SizedBox(height: 8),
                  Text('Setelah customer disubmit, akan langsung diarahkan ke langkah order.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.info)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 1: Identitas
          _sectionHeader('1. Identitas Pelanggan'),
          const SizedBox(height: 8),
          _field('Nama Langganan / Outlet *', _namaCtl),
          _field('Nomor ID /KTP', _ktpCtl),
          _field('Alamat KTP', _alamatKtpCtl, maxLines: 3),
          _field('Nama Kontak /Pemilik', _kontakCtl),
          _field('Telpon / HP', _telponCtl, keyboardType: TextInputType.phone),
          _field('Alamat Kirim', _alamatKirimCtl, maxLines: 3),
          _field('Propinsi', _propinsiCtl),
          _field('Kecamatan', _kecamatanCtl),
          _field('Kota', _kotaCtl),
          _field('Kelurahan', _kelurahanCtl),
          _field('Area / Route', _areaCtl),
          const SizedBox(height: 4),
          _fieldLabel('Kode Area'),
          _kodeAreaDropdown(),
          _fieldLabel('Tipe Langganan'),
          _choiceRow(_tipeLanggananKategoriOptions, _tipeLanggananKategori,
              (v) => setState(() => _tipeLanggananKategori = v)),
          if (_tipeLanggananKategori == 'PASAR') ...[
            const SizedBox(height: 4),
            _field('Nama pasar *', _namaPasarCtl, hintText: 'Contoh: pasar Senen'),
          ],
          const SizedBox(height: 20),

          // Section 2: Pembayaran
          _sectionHeader('2. Tipe Pembayaran'),
          const SizedBox(height: 8),
          _choiceRow(_tipeBayarOptions, _tipePembayaran,
              (v) => setState(() => _tipePembayaran = v)),
          if (_tipePembayaran == 'KREDIT') ...[
            const SizedBox(height: 8),
            _field('Batas Kredit *', _batasKreditCtl, keyboardType: TextInputType.number),
          ],
          if (_tipePembayaran == null) ...[
            const SizedBox(height: 8),
            Text('Pilih tipe pembayaran di atas.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 20),

          // Section 3: Channel
          _sectionHeader('3. Channel / Kategori'),
          const SizedBox(height: 8),
          _fieldLabel('Tipe Channel'),
          _choiceWrap(_channelOptions, _channelKategori,
              (v) => setState(() => _channelKategori = v)),
          _field('Key Account (REF ID)', _keyAccountCtl),
          _fieldLabel('Cluster Langganan'),
          _clusterField(),
          const SizedBox(height: 20),

          // Section 4: Kunjungan Salesman
          _sectionHeader('4. Kunjungan Salesman'),
          const SizedBox(height: 8),
          _readOnlyField('Kode Salesman', _kodeSalesmanCtl.text),
          _readOnlyField('Nama Salesman', _namaSalesmanCtl.text),
          _fieldLabel('Siklus Kunjungan'),
          _choiceWrap(_siklusKunjunganOptions, _siklusKunjungan,
              (v) => setState(() => _siklusKunjungan = v)),
          _fieldLabel('Hari Kunjungan'),
          _choiceWrap(_hariKunjunganOptions, _hariKunjungan,
              (v) => setState(() => _hariKunjungan = v)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: AppColors.textOnPrimary,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_barengOrder ? 'Submit & Buat Order' : 'Submit Pengajuan'),
          ),
        ),
      ),
    );
  }

  Widget _toggleChip({required String label, required bool selected, required VoidCallback onSelected}) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.info : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.info : AppColors.border),
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

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      title,
      style: AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 6),
    child: Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    ),
  );

  Widget _readOnlyField(String label, String value) => Padding(
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
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _kodeAreaDropdown() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _kodeAreaIsCustom
              ? '__custom__'
              : (_kodeAreaOptions.contains(_kodeArea) ? _kodeArea : null),
          hint: const Text('Pilih kode area'),
          isExpanded: true,
          items: [
            ..._kodeAreaOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))),
            const DropdownMenuItem(value: '__custom__', child: Text('Lainnya (ketik manual)…')),
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
    ),
  );

  Widget _choiceRow(List<String> options, String? selected, ValueChanged<String> onSelected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: isSel,
          onSelected: (sel) { if (sel) onSelected(o); },
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

  Widget _choiceWrap(List<String> options, String? selected, ValueChanged<String> onSelected) {
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
            onSelected: (sel) { if (sel) onSelected(o); },
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

  Widget _clusterField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ['STOCKIEST', 'SUBDIST', 'NO CLUSTER'].map((o) {
        final isSel = o == _clusterLangganan;
        return ChoiceChip(
          label: Text(o),
          selected: isSel,
          onSelected: (sel) => setState(() => _clusterLangganan = sel ? o : null),
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
