import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/import_model.dart';
import '../services/import_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/modern_text_field.dart';
import '../widgets/section_card.dart';

/// Input penerimaan: jumlah benar-benar diterima per produk (setelah
/// sortir/susut) dan realisasi nominal biaya. Dipakai pada tahap arrival /
/// receiving; hasilnya jadi dasar HPP realisasi saat finalisasi.
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.detail.importPurchase.items) {
      _qtyReceivedCtrls[item.id] = TextEditingController(
        text: item.quantityReceived == null
            ? ''
            : item.quantityReceived.toString(),
      );
    }
    for (final cost in widget.detail.importPurchase.costs) {
      _amountRealCtrls[cost.id] = TextEditingController(
        text: cost.amountReal == null ? '' : cost.amountReal.toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _qtyReceivedCtrls.values) {
      c.dispose();
    }
    for (final c in _amountRealCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final import = widget.detail.importPurchase;

    return AppPageScaffold(
      titleText: 'Penerimaan Impor #${import.id}',
      body: ListView(
        children: [
          SectionCard(
            title: 'Jumlah Diterima per Produk',
            icon: Icons.scale_outlined,
            child: Column(
              children: [
                for (final item in import.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Dibeli: ${item.quantity} ${item.unitName}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapHorizontalMD,
                        Expanded(
                          child: ModernTextField(
                            labelText: 'Diterima',
                            controller: _qtyReceivedCtrls[item.id]!,
                            prefixIcon: Icons.download_done_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.gapVerticalMD,
          SectionCard(
            title: 'Realisasi Biaya (opsional per baris)',
            icon: Icons.request_quote_outlined,
            child: import.costs.isEmpty
                ? Text(
                    'Tidak ada baris biaya.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Column(
                    children: [
                      for (final cost in import.costs)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cost.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Estimasi: ${cost.amountEstimate}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.gapHorizontalMD,
                              Expanded(
                                child: ModernTextField(
                                  labelText: 'Real (Rp)',
                                  controller: _amountRealCtrls[cost.id]!,
                                  prefixIcon: Icons.payments_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          AppSpacing.gapVerticalXL,
        ],
      ),
      bottomAction: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan Penerimaan'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final items = <Map<String, dynamic>>[];
    for (final entry in _qtyReceivedCtrls.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value == null || value < 0) {
        showErrorDialog(context, 'Nilai diterima tidak valid.');
        return;
      }
      items.add({'id': entry.key, 'quantity_received': value});
    }
    if (items.length < _qtyReceivedCtrls.length) {
      showErrorDialog(
        context,
        'Semua produk wajib mengisi jumlah diterima '
        '(isi 0 bila benar-benar tidak diterima).',
      );
      return;
    }

    final costs = <Map<String, dynamic>>[];
    for (final entry in _amountRealCtrls.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value == null) continue;
      costs.add({'id': entry.key, 'amount_real': value});
    }

    setState(() => _saving = true);
    try {
      await _service.receive(
        widget.detail.importPurchase.id,
        items: items,
        costs: costs,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
