import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/import_model.dart';
import '../services/image_service.dart';
import '../services/image_upload_service.dart';
import '../services/import_service.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/snackbar_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/forms/amount_field.dart';
import '../widgets/forms/form_add_button.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_text_field.dart';

/// Baris biaya baru yang ditambahkan saat realisasi (notul/denda yang
/// muncul belakangan — mis. PPH/PPN impor tambahan, denda penyimpanan).
class _NewCostDraft {
  _NewCostDraft({required this.stage, required this.category});

  final String stage;
  String category;
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
}

/// Satu tranche debit bank. [id] null = baris baru yang belum tersimpan.
class _PaymentDraft {
  _PaymentDraft({
    this.id,
    double? amount,
    DateTime? paidAt,
    String? note,
    this.proofPath,
    this.proofName,
    this.proofMime,
    this.proofSize,
  })  : amountCtrl = TextEditingController(
          text: amount == null ? '' : FormatUtils.formatAmount(amount),
        ),
        noteCtrl = TextEditingController(text: note ?? ''),
        paidAt = paidAt ?? DateTime.now();

  final int? id;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  DateTime paidAt;
  String? proofPath;
  String? proofName;
  String? proofMime;
  int? proofSize;
  bool uploading = false;

  bool get hasProof => (proofPath ?? '').isNotEmpty;
}

/// Satu notul. PPh/PPN dari notul terbaru menggantikan angka final.
class _NotulDraft {
  _NotulDraft({this.id, DateTime? date, ImportNotul? source})
      : numberCtrl = TextEditingController(text: source?.number ?? ''),
        pphCtrl = TextEditingController(
          text: source == null || source.pphAmount == 0
              ? ''
              : FormatUtils.formatAmount(source.pphAmount),
        ),
        ppnCtrl = TextEditingController(
          text: source == null || source.ppnAmount == 0
              ? ''
              : FormatUtils.formatAmount(source.ppnAmount),
        ),
        penaltyCtrl = TextEditingController(
          text: source == null || source.penaltyAmount == 0
              ? ''
              : FormatUtils.formatAmount(source.penaltyAmount),
        ),
        otherCtrl = TextEditingController(
          text: source == null || source.otherAmount == 0
              ? ''
              : FormatUtils.formatAmount(source.otherAmount),
        ),
        otherDescCtrl =
            TextEditingController(text: source?.otherDescription ?? ''),
        noteCtrl = TextEditingController(text: source?.note ?? ''),
        notulDate = date ?? source?.date ?? DateTime.now(),
        documentPath = source?.documentPath,
        documentName = source?.documentOriginalName,
        documentMime = source?.documentMimeType,
        documentSize = source?.documentSizeBytes;

  final int? id;
  final TextEditingController numberCtrl;
  final TextEditingController pphCtrl;
  final TextEditingController ppnCtrl;
  final TextEditingController penaltyCtrl;
  final TextEditingController otherCtrl;
  final TextEditingController otherDescCtrl;
  final TextEditingController noteCtrl;
  DateTime notulDate;
  String? documentPath;
  String? documentName;
  String? documentMime;
  int? documentSize;
  bool uploading = false;

  bool get hasDocument => (documentPath ?? '').isNotEmpty;
}

/// Input realisasi bertahap: nominal real per biaya, jumlah diterima per
/// produk, pembayaran, dan notul. Semua bagian boleh diisi pada tahap
/// non-terminal (bypass alur); final/cancelled tetap terkunci.
///
/// Prinsip: isi yang sudah diketahui, simpan kapan saja; baris kosong
/// diabaikan. Estimasi hanya tampil sebagai referensi pengisian pada
/// baris yang masih kosong (ketuk "Estimasi: Rp ... / Pakai" atau "Isi
/// estimasi" untuk semua baris kosong); setelah realisasi terisi, baris
/// menampilkan realisasi saja — tanpa perbandingan estimasi maupun
/// penanda selisih. Field nominal besar (rata kanan, pemisah ribuan live
/// via [CurrencyInputFormatter], seluruh isi terpilih saat fokus).
class ImportReceivePage extends StatefulWidget {
  final ImportPurchaseDetail detail;

  const ImportReceivePage({super.key, required this.detail});

  @override
  State<ImportReceivePage> createState() => _ImportReceivePageState();
}

class _ImportReceivePageState extends State<ImportReceivePage> {
  final ImportService _service = ImportService();

  final _qtyReceivedCtrls = <int, TextEditingController>{};
  final _amountRealCtrls = <int, TextEditingController>{};
  final _newCosts = <_NewCostDraft>[];
  final _payments = <_PaymentDraft>[];
  final _notuls = <_NotulDraft>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.detail.importPurchase.items) {
      _qtyReceivedCtrls[item.id] = TextEditingController(
        text: item.quantityReceived == null
            ? ''
            : FormatUtils.formatAmount(item.quantityReceived!, decimals: 3),
      );
    }
    for (final cost in widget.detail.importPurchase.costs) {
      if (cost.isDerived) continue;
      _amountRealCtrls[cost.id] = TextEditingController(
        text: cost.amountReal == null
            ? ''
            : FormatUtils.formatAmount(cost.amountReal!),
      );
    }
    for (final payment in widget.detail.importPurchase.payments) {
      _payments.add(_PaymentDraft(
        id: payment.id,
        amount: payment.amount,
        paidAt: payment.paidAt,
        note: payment.note,
        proofPath: payment.proofPath,
        proofName: payment.proofOriginalName,
        proofMime: payment.proofMimeType,
        proofSize: payment.proofSizeBytes,
      ));
    }
    for (final notul in widget.detail.importPurchase.notuls) {
      _notuls.add(_NotulDraft(id: notul.id, source: notul));
    }
    // Ringkasan, status "sesuai estimasi", dan tombol isi-cepat mengikuti
    // isian secara live.
    final liveControllers = <TextEditingController>[
      ..._qtyReceivedCtrls.values,
      ..._amountRealCtrls.values,
      for (final p in _payments) ...[p.amountCtrl, p.noteCtrl],
      for (final n in _notuls) ...[
        n.numberCtrl,
        n.pphCtrl,
        n.ppnCtrl,
        n.penaltyCtrl,
        n.otherCtrl,
        n.otherDescCtrl,
        n.noteCtrl,
      ],
    ];
    for (final c in liveControllers) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _qtyReceivedCtrls.values) {
      c.dispose();
    }
    for (final c in _amountRealCtrls.values) {
      c.dispose();
    }
    for (final d in _newCosts) {
      d.nameCtrl.dispose();
      d.amountCtrl.dispose();
    }
    for (final p in _payments) {
      p.amountCtrl.dispose();
      p.noteCtrl.dispose();
    }
    for (final n in _notuls) {
      n.numberCtrl.dispose();
      n.pphCtrl.dispose();
      n.ppnCtrl.dispose();
      n.penaltyCtrl.dispose();
      n.otherCtrl.dispose();
      n.otherDescCtrl.dispose();
      n.noteCtrl.dispose();
    }
    super.dispose();
  }

  /* ------------------------------------------------------ QUICK FILL */

  /// Isi satu nominal lalu taruh kursor di ujung — siap disesuaikan.
  void _fillController(TextEditingController controller, double value,
      {int decimals = 0}) {
    final text = FormatUtils.formatAmount(value, decimals: decimals);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    HapticFeedback.selectionClick();
    setState(() {});
  }

  /// Referensi = estimasi biaya. Satu ketuk pada baris "Estimasi: Rp ..."
  /// mengisi nominal real; kasus paling umum (real = estimasi) selesai
  /// tanpa mengetik satu angka pun.
  void _fillCostEstimate(ImportCost cost) {
    final controller = _amountRealCtrls[cost.id];
    if (controller == null) return;
    _fillController(controller, _effectiveEstimate(cost));
  }

  /// Referensi = jumlah dibeli. Staf tinggal mengurangi bila ada susut.
  void _fillItemQuantity(ImportItem item) {
    final controller = _qtyReceivedCtrls[item.id];
    if (controller == null) return;
    _fillController(controller, item.quantity, decimals: 3);
  }

  /// Estimasi efektif: pakai angka tersimpan bila ada; kalau nol tetapi
  /// baris punya tarif pajak, hitung dari nilai barang (mis. PPH 2,5%).
  /// Ini yang membuat baris seperti "PPH 1.6" tetap bisa diisi satu ketuk.
  double _effectiveEstimate(ImportCost cost) {
    if (cost.amountEstimate > 0) return cost.amountEstimate;
    final rate = cost.taxRate;
    if (rate == null || rate <= 0) return cost.amountEstimate;
    return widget.detail.hpp.goodsTotal * rate / 100;
  }

  /// Isi semua biaya yang masih kosong dengan estimasinya. Baris yang sudah
  /// diketik tidak pernah ditimpa, jadi aman ditekan kapan saja.
  void _fillEmptyCostEstimates() {
    var changed = 0;
    for (final cost in widget.detail.importPurchase.costs) {
      final controller = _amountRealCtrls[cost.id];
      if (controller == null || controller.text.trim().isNotEmpty) continue;
      final suggestion = _effectiveEstimate(cost);
      if (suggestion <= 0) continue;
      final text = FormatUtils.formatAmount(suggestion);
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      changed++;
    }
    if (changed == 0) return;
    HapticFeedback.selectionClick();
    setState(() {});
    showSuccessSnackBar(
      context,
      '$changed biaya kosong diisi sesuai estimasi. Periksa sebelum simpan.',
    );
  }

  bool _paymentHasValue(_PaymentDraft draft) =>
      draft.id != null ||
      draft.amountCtrl.text.trim().isNotEmpty ||
      draft.hasProof;

  bool _notulHasValue(_NotulDraft draft) =>
      draft.id != null ||
      draft.numberCtrl.text.trim().isNotEmpty ||
      draft.pphCtrl.text.trim().isNotEmpty ||
      draft.ppnCtrl.text.trim().isNotEmpty ||
      draft.penaltyCtrl.text.trim().isNotEmpty ||
      draft.otherCtrl.text.trim().isNotEmpty ||
      draft.hasDocument;

  bool get _hasPayments => _payments.any(_paymentHasValue);

  bool get _hasNotuls => _notuls.any(_notulHasValue);

  bool get _showNotulSection =>
      _notuls.isNotEmpty || widget.detail.importPurchase.stage.canRealizeCosts;

  /// Biaya manual yang relevan setelah pembayaran/notul menggantikan
  /// real bank/diskon/pajak. Baris derived tidak pernah bisa diedit.
  List<ImportCost> get _visibleManualCosts {
    return widget.detail.importPurchase.manualCosts.where((c) {
      if (_hasPayments && (c.category == 'bank' || c.category == 'discount')) {
        return false;
      }
      if (_hasNotuls && c.category == 'tax') return false;
      return true;
    }).toList(growable: false);
  }

  int get _filledCostCount => _visibleManualCosts
      .where((c) => _amountRealCtrls[c.id]?.text.trim().isNotEmpty ?? false)
      .length;

  int get _emptyEstimableCount => _visibleManualCosts.where((c) {
        final text = _amountRealCtrls[c.id]?.text.trim() ?? '';
        return text.isEmpty && _effectiveEstimate(c) > 0;
      }).length;

  /// Nilai realisasi manual yang masih dihitung server setelah pembayaran
  /// dan/atau notul ada.
  double get _manualRealTotal {
    var total = 0.0;
    for (final cost in _visibleManualCosts) {
      total += parseAmount(_amountRealCtrls[cost.id]?.text ?? '') ?? 0;
    }
    for (final draft in _newCosts) {
      total += parseAmount(draft.amountCtrl.text) ?? 0;
    }
    return total;
  }

  double get _paymentsTotal {
    var total = 0.0;
    for (final p in _payments) {
      total += parseAmount(p.amountCtrl.text) ?? 0;
    }
    return total;
  }

  /// PPh/PPN notul terbaru + akumulasi denda/biaya lain semua notul —
  /// mengikuti perhitungan server.
  (double, double) get _notulTotals {
    final active = _notuls.where(_notulHasValue).toList(growable: false);
    if (active.isEmpty) return (0, 0);

    // Samakan dengan server: tanggal terbaru menang; bila sama, baris yang
    // paling akhir (id terbesar) adalah notul terbaru.
    final indexed = active.asMap().entries.toList()
      ..sort((a, b) {
        final byDate = b.value.notulDate.compareTo(a.value.notulDate);
        return byDate != 0 ? byDate : b.key.compareTo(a.key);
      });
    final latest = indexed.first.value;
    final latestTax = (parseAmount(latest.pphCtrl.text) ?? 0) +
        (parseAmount(latest.ppnCtrl.text) ?? 0);
    var additions = 0.0;
    for (final n in active) {
      additions += parseAmount(n.penaltyCtrl.text) ?? 0;
      additions += parseAmount(n.otherCtrl.text) ?? 0;
    }
    return (latestTax, additions);
  }

  /* ------------------------------------------------------------ BUILD */

  @override
  Widget build(BuildContext context) {
    final import = widget.detail.importPurchase;

    return AppPageScaffold(
      titleText: 'Realisasi Impor #${import.id}',
      bodyPadding: EdgeInsets.zero,
      body: Builder(
        // Konteks dalam body Scaffold: clearance atas (app bar kaca) +
        // bawah (bar aksi simpan, extendBody) dari MediaQuery.
        builder: (bodyContext) => ListView(
          // Geser daftar = tutup keyboard: bar simpan naik mengikuti
          // keyboard, dan menggulir form panjang tidak perlu menahan
          // keyboard tetap terbuka.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: AppSpacing.screenPadding.copyWith(
            top: AppBarInsets.top(bodyContext),
            bottom: MediaQuery.paddingOf(bodyContext).bottom + AppSpacing.md,
          ),
          children: [
            _buildSummaryCard(),
            AppSpacing.gapVerticalMD,
            _buildPaymentsSection(),
            AppSpacing.gapVerticalMD,
            if (import.stage.canRealizeCosts) ...[
              _buildItemsSection(),
              AppSpacing.gapVerticalMD,
            ],
            _buildOtherCostsSection(),
            if (_showNotulSection) ...[
              AppSpacing.gapVerticalMD,
              _buildNotulSection(),
            ],
            AppSpacing.gapVerticalXL,
          ],
        ),
      ),
      bottomAction: ModernButton(
        text: 'Simpan Realisasi',
        icon: Icons.save_rounded,
        isLoading: _saving,
        onPressed: _saving ? null : _save,
      ),
    );
  }

  /// Ringkasan live: total realisasi vs estimasi seluruh proses impor
  /// (nilai barang + biaya) — konteks angka besar langsung terbaca.
  Widget _buildSummaryCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final import = widget.detail.importPurchase;

    final (notulTax, notulAdd) = _notulTotals;
    final filled = _manualRealTotal + _paymentsTotal + notulTax + notulAdd;
    final estimate = import.costs
        .where((c) => !c.isDerived)
        .fold<double>(0, (sum, c) => sum + _effectiveEstimate(c));
    // Total proses impor = nilai barang + pembayaran + biaya lain + notul,
    // sama dengan total_real/total_estimate yang dipakai HPP & kartu list.
    final goodsTotal = widget.detail.hpp.goodsTotal;
    final totalReal = goodsTotal + filled;
    final totalEstimate = goodsTotal + estimate;

    final newCostFilled =
        _newCosts.where((d) => d.amountCtrl.text.trim().isNotEmpty).length;
    final paymentFilled =
        _payments.where((p) => p.amountCtrl.text.trim().isNotEmpty).length;
    final notulFilled = _notuls
        .where((n) =>
            n.numberCtrl.text.trim().isNotEmpty ||
            n.pphCtrl.text.trim().isNotEmpty ||
            n.ppnCtrl.text.trim().isNotEmpty ||
            n.penaltyCtrl.text.trim().isNotEmpty ||
            n.otherCtrl.text.trim().isNotEmpty ||
            n.hasDocument)
        .length;
    final totalComponents = _payments.length +
        _visibleManualCosts.length +
        _notuls.length +
        _newCosts.length;
    final filledCount =
        paymentFilled + _filledCostCount + newCostFilled + notulFilled;
    final allFilled = totalComponents > 0 && filledCount == totalComponents;
    final canFillEmpty = _emptyEstimableCount > 0;

    return FormSectionCard(
      title: 'Ringkasan Realisasi',
      icon: Icons.calculate_outlined,
      children: [
        // Satu angka: realisasi bila sudah ada isian, estimasi sebagai
        // fallback sebelum ada — tanpa perbandingan keduanya.
        _statTile(
          label: allFilled || filledCount > 0
              ? 'Total Realisasi'
              : 'Total Estimasi',
          value: FormatUtils.formatRupiah(filledCount > 0 ? totalReal : totalEstimate),
          emphasized: true,
        ),
        Text(
          'Nilai barang + pembayaran + biaya lain + notul',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Row(
          children: [
            Icon(
              allFilled
                  ? Icons.check_circle_rounded
                  : Icons.pending_actions_outlined,
              size: 15,
              color: allFilled ? _successColor : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                allFilled
                    ? 'Semua komponen realisasi sudah terisi'
                    : '$filledCount dari $totalComponents komponen terisi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: allFilled ? _successColor : cs.onSurfaceVariant,
                  fontWeight: allFilled ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (canFillEmpty)
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 16,
                  color: cs.primary,
                ),
                label: const Text('Isi estimasi'),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: cs.primary.withValues(alpha: 0.35),
                ),
                backgroundColor: cs.primary.withValues(alpha: 0.06),
                onPressed: _fillEmptyCostEstimates,
                tooltip: 'Isi biaya kosong dengan nilai estimasi',
              ),
          ],
        ),
        Text(
          'Isi yang sudah diketahui saja — baris lain bisa menyusul kapan '
          'saat sebelum finalisasi.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    bool emphasized = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: emphasized
            ? cs.primary.withValues(alpha: 0.06)
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          // Nominal besar menyusut, bukan membungkus ke baris kedua.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: emphasized ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    final import = widget.detail.importPurchase;

    return FormSectionCard(
      title: 'Produk Diterima',
      subtitle: 'Setelah sortir/susut — boleh disimpan sebagian',
      icon: Icons.scale_outlined,
      children: [
        for (final item in import.items)
          _quantityRow(
            item,
            _qtyReceivedCtrls[item.id]!,
          ),
      ],
    );
  }

  Widget _quantityRow(ImportItem item, TextEditingController controller) {
    final hasValue = controller.text.trim().isNotEmpty;

    return _amountRow(
      title: item.productName,
      // Referensi jumlah dibeli hanya pada baris kosong (isi ceppat);
      // setelah terisi, jumlah diterima berdiri sendiri.
      meta: hasValue
          ? null
          : 'Dibeli: ${FormatUtils.formatAmount(item.quantity, decimals: 3)} '
              '${item.unitName}',
      metaTooltip: hasValue
          ? null
          : 'Isi jumlah diterima dengan jumlah dibeli',
      metaIcon: hasValue ? null : Icons.auto_fix_high_rounded,
      onMetaTap: hasValue ? null : () => _fillItemQuantity(item),
      showMetaAction: !hasValue,
      controller: controller,
      semanticLabel: 'Jumlah diterima ${item.productName}',
      suffixText: item.unitName.isEmpty ? null : item.unitName,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [CurrencyInputFormatter(decimals: 3)],
    );
  }

  Widget _buildPaymentsSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = _paymentsTotal;

    return FormSectionCard(
      title: 'Pembayaran',
      subtitle: 'Total debit bank: ${FormatUtils.formatRupiah(total)}',
      icon: Icons.account_balance_outlined,
      trailing: FormAddButton(
        label: 'Tranche',
        onPressed: () => setState(
          () => _payments.add(_PaymentDraft()),
        ),
      ),
      children: [
        Text(
          'Satu tranche = satu debit bank (nilai barang + transfer + bank − '
          'diskon). Bukti pembayaran opsional untuk setiap tranche.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (_payments.isEmpty)
          _emptyHint(
            icon: Icons.account_balance_wallet_outlined,
            text: 'Belum ada pembayaran. Tambahkan tranche saat debit bank '
                'diketahui.',
          ),
        for (var i = 0; i < _payments.length; i++) _paymentRow(_payments[i], i),
        if (_payments.isNotEmpty)
          _totalLine('Total pembayaran', FormatUtils.formatRupiah(total)),
      ],
    );
  }

  Widget _paymentRow(_PaymentDraft draft, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tranche ${index + 1}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.event_rounded, size: 15),
                label: Text(FormatUtils.formatDate(draft.paidAt)),
                onPressed: () => _pickPaymentDate(draft),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Hapus tranche',
                onPressed: () => setState(() => _payments.remove(draft)),
              ),
            ],
          ),
          AmountField(
            controller: draft.amountCtrl,
            prefixText: 'Rp ',
            hintText: '0',
            semanticLabel: 'Nominal pembayaran tranche ${index + 1}',
            inputFormatters: const [CurrencyInputFormatter()],
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapVerticalSM,
          ModernTextField(
            labelText: 'Catatan pembayaran (opsional)',
            controller: draft.noteCtrl,
            prefixIcon: Icons.notes_rounded,
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapVerticalSM,
          Row(
            children: [
              if (draft.uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  draft.hasProof
                      ? Icons.verified_rounded
                      : Icons.attach_file_rounded,
                  size: 18,
                  color: draft.hasProof ? _successColor : cs.primary,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  draft.hasProof
                      ? (draft.proofName?.isNotEmpty == true
                          ? draft.proofName!
                          : 'Bukti pembayaran terlampir')
                      : 'Bukti pembayaran (opsional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: draft.hasProof ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: draft.hasProof ? FontWeight.w600 : null,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    draft.uploading ? null : () => _uploadPaymentProof(draft),
                icon: const Icon(Icons.upload_file_rounded, size: 17),
                label: Text(draft.hasProof ? 'Ganti' : 'Lampirkan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtherCostsSection() {
    final costs = _visibleManualCosts;

    return FormSectionCard(
      title: 'Biaya Lain',
      subtitle: 'Logistik, denda, dan biaya di luar bank/notul',
      icon: Icons.receipt_long_outlined,
      trailing: FormAddButton(
        label: 'Biaya',
        onPressed: () => setState(
          () => _newCosts.add(_NewCostDraft(
            stage: _defaultCostStage,
            category: 'other',
          )),
        ),
      ),
      children: [
        if (costs.isEmpty && _newCosts.isEmpty)
          _emptyHint(
            icon: Icons.playlist_add_rounded,
            text: 'Belum ada biaya lain. Bank, diskon, dan pajak final '
                'ditangani lewat Pembayaran dan Notul.',
          ),
        for (final cost in costs) _costRow(cost),
        for (final draft in _newCosts) _newCostRow(draft),
      ],
    );
  }

  String get _defaultCostStage {
    final stage = widget.detail.importPurchase.stage.name;
    return const ['purchase', 'payment', 'shipment', 'customs', 'arrival']
            .contains(stage)
        ? stage
        : 'customs';
  }

  Widget _buildNotulSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FormSectionCard(
      title: 'Notul',
      subtitle: 'PPh/PPN terbaru menjadi angka final; denda & biaya lain '
          'ditambahkan',
      icon: Icons.gavel_outlined,
      trailing: FormAddButton(
        label: 'Notul',
        onPressed: () => setState(
          () => _notuls.add(_NotulDraft()),
        ),
      ),
      children: [
        if (_notuls.isEmpty)
          _emptyHint(
            icon: Icons.description_outlined,
            text: 'Belum ada notul. Isi PPh/PPN final dari kantor pabean di '
                'sini.',
          ),
        for (var i = 0; i < _notuls.length; i++) _notulRow(_notuls[i], i),
        Text(
          'PPh/PPN memakai notul terbaru. Denda administrasi dan biaya lain '
          'dijumlahkan dari seluruh notul.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _notulRow(_NotulDraft draft, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasOther = (parseAmount(draft.otherCtrl.text) ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notul ${index + 1}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.event_rounded, size: 15),
                label: Text(FormatUtils.formatDate(draft.notulDate)),
                onPressed: () => _pickNotulDate(draft),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Hapus notul',
                onPressed: () => setState(() => _notuls.remove(draft)),
              ),
            ],
          ),
          ModernTextField(
            labelText: 'Nomor notul (opsional)',
            controller: draft.numberCtrl,
            prefixIcon: Icons.tag_rounded,
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapVerticalSM,
          _amountFieldBlock('PPh Impor', draft.pphCtrl),
          AppSpacing.gapVerticalSM,
          _amountFieldBlock('PPN Impor', draft.ppnCtrl),
          AppSpacing.gapVerticalSM,
          _amountFieldBlock('Denda administrasi', draft.penaltyCtrl),
          AppSpacing.gapVerticalSM,
          _amountFieldBlock('Biaya lain', draft.otherCtrl),
          if (hasOther) ...[
            AppSpacing.gapVerticalSM,
            ModernTextField(
              labelText: 'Keterangan biaya lain',
              controller: draft.otherDescCtrl,
              prefixIcon: Icons.notes_rounded,
              onChanged: (_) => setState(() {}),
            ),
          ],
          AppSpacing.gapVerticalSM,
          Row(
            children: [
              if (draft.uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  draft.hasDocument
                      ? Icons.verified_rounded
                      : Icons.attach_file_rounded,
                  size: 18,
                  color: draft.hasDocument ? _successColor : cs.primary,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  draft.hasDocument
                      ? (draft.documentName?.isNotEmpty == true
                          ? draft.documentName!
                          : 'Dokumen notul terlampir')
                      : 'Dokumen notul (opsional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        draft.hasDocument ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: draft.hasDocument ? FontWeight.w600 : null,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    draft.uploading ? null : () => _uploadNotulDocument(draft),
                icon: const Icon(Icons.upload_file_rounded, size: 17),
                label: Text(draft.hasDocument ? 'Ganti' : 'Lampirkan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountFieldBlock(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        AmountField(
          controller: controller,
          prefixText: 'Rp ',
          hintText: '0',
          semanticLabel: label,
          inputFormatters: const [CurrencyInputFormatter()],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _emptyHint({required IconData icon, required String text}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPaymentDate(_PaymentDraft draft) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => draft.paidAt = picked);
  }

  Future<void> _pickNotulDate(_NotulDraft draft) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.notulDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => draft.notulDate = picked);
  }

  Future<(String, String, int)?> _pickAndUploadDocument() async {
    final file = await ImageService.selectAndPickImage(context);
    if (file == null) return null;
    final size = await file.length();
    final path = await ImageUploadService.upload(
      File(file.path),
      directory: 'documents/ImportPurchase',
    );
    if (path == null) throw Exception('Upload dokumen gagal — coba lagi.');
    return (path, file.path.split('/').last, size);
  }

  Future<void> _uploadPaymentProof(_PaymentDraft draft) async {
    setState(() => draft.uploading = true);
    try {
      final uploaded = await _pickAndUploadDocument();
      if (!mounted) return;
      if (uploaded == null) {
        setState(() => draft.uploading = false);
        return;
      }
      setState(() {
        draft
          ..proofPath = uploaded.$1
          ..proofName = uploaded.$2
          ..proofMime = 'image/webp'
          ..proofSize = uploaded.$3
          ..uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => draft.uploading = false);
      showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _uploadNotulDocument(_NotulDraft draft) async {
    setState(() => draft.uploading = true);
    try {
      final uploaded = await _pickAndUploadDocument();
      if (!mounted) return;
      if (uploaded == null) {
        setState(() => draft.uploading = false);
        return;
      }
      setState(() {
        draft
          ..documentPath = uploaded.$1
          ..documentName = uploaded.$2
          ..documentMime = 'image/webp'
          ..documentSize = uploaded.$3
          ..uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => draft.uploading = false);
      showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _stageLabel(String stage) => switch (stage) {
        'purchase' => 'Pembelian',
        'payment' => 'Pembayaran',
        'shipment' => 'Pengiriman',
        'customs' => 'Kepabeanan',
        'arrival' => 'Kedatangan',
        _ => stage,
      };

  /// Baris biaya tersimpan: nama + nominal real besar di kanan. Estimasi
  /// hanya tampil sebagai referensi pengisian pada baris yang masih
  /// kosong (sekaligus tombol isi-cepat) — setelah terisi, realisasi
  /// berdiri sendiri tanpa perbandingan/selisih.
  Widget _costRow(ImportCost cost) {
    final controller = _amountRealCtrls[cost.id]!;
    final hasValue = controller.text.trim().isNotEmpty;
    final suggestion = _effectiveEstimate(cost);
    final canSuggest = !hasValue && suggestion > 0;

    final taxNote = cost.taxRate == null
        ? null
        : '${FormatUtils.formatAmount(cost.taxRate!, decimals: 3)}% nilai barang';
    final contextLine = [
      _stageLabel(cost.stage),
      if (!hasValue) ...[
        if (cost.amountEstimate > 0)
          'Estimasi: ${FormatUtils.formatRupiah(cost.amountEstimate)}'
        else if (canSuggest && taxNote != null)
          '$taxNote ≈ ${FormatUtils.formatRupiah(suggestion)}',
        if (cost.amountEstimate > 0 && taxNote != null) taxNote,
      ],
      if (cost.isForeignCurrency && cost.amountForeign != null)
        '${widget.detail.importPurchase.currency} '
            '${FormatUtils.formatAmount(cost.amountForeign!)}',
    ].join(' • ');

    return _amountRow(
      title: cost.name,
      meta: contextLine.isEmpty ? null : contextLine,
      metaTooltip: canSuggest
          ? 'Isi realisasi dengan estimasi ${FormatUtils.formatRupiah(suggestion)}'
          : null,
      metaIcon: canSuggest ? Icons.auto_fix_high_rounded : null,
      onMetaTap: canSuggest ? () => _fillCostEstimate(cost) : null,
      showMetaAction: canSuggest,
      controller: controller,
      semanticLabel: 'Realisasi ${cost.name}',
      prefixText: 'Rp ',
      inputFormatters: const [CurrencyInputFormatter()],
    );
  }

  /// Baris biaya baru: nama di atas, nominal besar di bawah — tidak ada
  /// dua kolom sempit yang saling berebut ruang.
  Widget _newCostRow(_NewCostDraft draft) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  labelText: 'Nama biaya (mis. Denda)',
                  controller: draft.nameCtrl,
                  prefixIcon: Icons.receipt_long_outlined,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Buang baris',
                onPressed: () => setState(() => _newCosts.remove(draft)),
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          AmountField(
            controller: draft.amountCtrl,
            prefixText: 'Rp ',
            hintText: '0',
            semanticLabel: 'Nominal realisasi biaya baru',
            inputFormatters: const [CurrencyInputFormatter()],
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapVerticalSM,
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final option in const [
                ('other', 'Lainnya'),
                ('logistics', 'Logistik'),
                ('goods', 'Barang'),
                ('discount', 'Diskon'),
              ])
                ChoiceChip(
                  label: Text(option.$2),
                  selected: draft.category == option.$1,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => draft.category = option.$1),
                ),
            ],
          ),
          if (draft.category == 'discount')
            Text(
              'Diskon mengurangi total realisasi.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------ ROW LAYOUT */

  Color get _successColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF81C784)
      : const Color(0xFF2E7D32);

  /// Satu pola baris nominal: nama + konteks di kiri, input besar di kanan.
  /// Di layar sempit input turun ke bawah agar tidak ada label/angka yang
  /// terpotong.
  Widget _amountRow({
    required String title,
    required TextEditingController controller,
    required String semanticLabel,
    String? meta,
    String? metaTooltip,
    IconData? metaIcon,
    VoidCallback? onMetaTap,
    bool showMetaAction = false,
    String? prefixText,
    String? suffixText,
    TextInputType keyboardType = TextInputType.number,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final titleWidget = Text(
      title,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    // Konteks referensi (estimasi/dibeli) hanya untuk baris kosong —
    // baris terisi menampilkan realisasi saja.
    final Widget metaWidget;
    if (meta == null || meta.isEmpty) {
      metaWidget = const SizedBox.shrink();
    } else {
      final metaTappable = InkWell(
        onTap: onMetaTap,
        borderRadius: AppSpacing.borderRadiusSM,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (showMetaAction) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Pakai',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (metaIcon != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      metaIcon,
                      size: 14,
                      color: cs.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      metaWidget = metaTooltip == null || metaTooltip.isEmpty
          ? metaTappable
          : Tooltip(message: metaTooltip, child: metaTappable);
    }

    final field = AmountField(
      controller: controller,
      prefixText: prefixText,
      suffixText: suffixText,
      semanticLabel: semanticLabel,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Di ponsel sempit, input turun ke baris penuh agar nama/konteks
        // dan angka besar sama-sama tidak terpotong.
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              metaWidget,
              AppSpacing.gapVerticalSM,
              field,
            ],
          );
        }

        // Lebar: angka di kanan sejajar nama, konteks estimasi turun ke
        // bawah memakai lebar penuh — tidak ada lagi "Estimasi: Rp ..."
        // yang membungkus di kolom sempit.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleWidget),
                AppSpacing.gapHorizontalMD,
                SizedBox(width: 184, child: field),
              ],
            ),
            const SizedBox(height: 2),
            metaWidget,
          ],
        );
      },
    );
  }

  /* ------------------------------------------------------------- SAVE */

  /// Simpan parsial: hanya baris terisi yang dikirim. Baris kosong
  /// dibiarkan (bisa disimpan menyusul); finalisasi tetap dicek server.
  Future<void> _save() async {
    final importId = widget.detail.importPurchase.id;

    final items = <Map<String, dynamic>>[];
    for (final entry in _qtyReceivedCtrls.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final value = parseAmount(text);
      if (value == null || value < 0) {
        showErrorDialog(context, 'Nilai diterima tidak valid.');
        return;
      }
      items.add({'id': entry.key, 'quantity_received': value});
    }

    final costs = <Map<String, dynamic>>[];
    for (final entry in _amountRealCtrls.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final value = parseAmount(text);
      if (value == null || value < 0) continue;
      costs.add({'id': entry.key, 'amount_real': value});
    }
    for (final draft in _newCosts) {
      final name = draft.nameCtrl.text.trim();
      final amount = draft.amountCtrl.text.trim();
      if (name.isEmpty && amount.isEmpty) continue;
      if (name.isEmpty) {
        showErrorDialog(
          context,
          'Baris biaya baru wajib memiliki nama — isi nama atau buang '
          'barisnya.',
        );
        return;
      }
      costs.add({
        'name': name,
        'stage': draft.stage,
        'category': draft.category,
        if (amount.isNotEmpty) 'amount_real': parseAmount(amount),
      });
    }

    final payments = <Map<String, dynamic>>[];
    for (final draft in _payments) {
      final amountText = draft.amountCtrl.text.trim();
      if (amountText.isEmpty) {
        if (draft.hasProof) {
          showErrorDialog(
            context,
            'Nominal pembayaran belum diisi pada tranche dengan bukti.',
          );
          return;
        }
        continue;
      }
      final amount = parseAmount(amountText);
      if (amount == null || amount <= 0) {
        showErrorDialog(context, 'Nominal pembayaran tidak valid.');
        return;
      }
      payments.add({
        if (draft.id != null) 'id': draft.id,
        'amount': amount,
        'paid_at': _dateOnly(draft.paidAt),
        if (draft.noteCtrl.text.trim().isNotEmpty)
          'note': draft.noteCtrl.text.trim(),
        if (draft.proofPath != null) 'proof_path': draft.proofPath,
        if (draft.proofName != null) 'proof_original_name': draft.proofName,
        if (draft.proofMime != null) 'proof_mime_type': draft.proofMime,
        if (draft.proofSize != null) 'proof_size_bytes': draft.proofSize,
      });
    }
    final notuls = <Map<String, dynamic>>[];
    for (final draft in _notuls) {
      if (!_notulHasValue(draft)) continue;

      notuls.add({
        if (draft.id != null) 'id': draft.id,
        'notul_date': _dateOnly(draft.notulDate),
        if (draft.numberCtrl.text.trim().isNotEmpty)
          'notul_number': draft.numberCtrl.text.trim(),
        'pph_amount': parseAmount(draft.pphCtrl.text) ?? 0,
        'ppn_amount': parseAmount(draft.ppnCtrl.text) ?? 0,
        'penalty_amount': parseAmount(draft.penaltyCtrl.text) ?? 0,
        'other_amount': parseAmount(draft.otherCtrl.text) ?? 0,
        if (draft.otherDescCtrl.text.trim().isNotEmpty)
          'other_description': draft.otherDescCtrl.text.trim(),
        if (draft.documentPath != null) 'document_path': draft.documentPath,
        if (draft.documentName != null)
          'document_original_name': draft.documentName,
        if (draft.documentMime != null)
          'document_mime_type': draft.documentMime,
        if (draft.documentSize != null)
          'document_size_bytes': draft.documentSize,
      });
    }

    if (items.isEmpty && costs.isEmpty && payments.isEmpty && notuls.isEmpty) {
      showErrorDialog(
        context,
        'Isi minimal satu nilai realisasi sebelum menyimpan.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.receive(
        importId,
        items: items,
        costs: costs,
        payments: payments,
        notuls: notuls,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Realisasi tersimpan.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
