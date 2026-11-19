import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/document/document_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/safe_bottom_bar.dart';

/// Mode masa berlaku surat kuasa (KUA).
enum ValidityMode {
  untilDate('until_date'),
  untilDone('until_done'),
  unlimited('unlimited');

  const ValidityMode(this.value);
  final String value;

  String get label => switch (this) {
        ValidityMode.untilDate => 'Hingga tanggal',
        ValidityMode.untilDone => 'Selesai urusan',
        ValidityMode.unlimited => 'Tanpa batas',
      };
}

/// Langkah 2 wizard — formulir: unit, perihal, tanggal, penerima
/// (buku pihak / ketik bebas + simpan ke buku pihak), field khusus jenis
/// (`specific_fields`) dan masa berlaku KUA.
///
/// Controller dimiliki wizard agar nilai bertahan antar langkah; pencarian
/// buku pihak lewat callback [searchParties] agar teruji dengan fake.
class StepForm extends StatelessWidget {
  final TextEditingController unitController;
  final TextEditingController subjectController;
  final DateTime date;
  final VoidCallback onPickDate;
  final bool subjectMissing;

  // Penerima.
  final TextEditingController recipientNameController;
  final TextEditingController recipientIdentityController;
  final TextEditingController recipientTitleController;
  final TextEditingController recipientAddressController;
  final Future<PaginatedResult<PartyModel>> Function(String query)?
      searchParties;
  final bool savingParty;
  final VoidCallback? onSaveParty; // null = tak perlu tawarkan simpan.

  // Klasifikasi surat — 'umum' | 'rahasia' (kosong = umum).
  final String classification;
  final ValueChanged<String> onClassificationChanged;

  // Field khusus jenis (key → controller).
  final List<LetterSpecificField> specificFields;
  final Map<String, TextEditingController> specificControllers;

  // Masa berlaku — gating dari wizard (Fix I1): jenis KUA atau
  // specific_fields memuat key `masa_berlaku` (bukan sekadar "ada field
  // khusus apa pun", supaya tak bergantung shape object lama).
  final bool validityRelevant;
  final ValidityMode validityMode;
  final ValueChanged<ValidityMode> onValidityModeChanged;
  final DateTime? validityDate;
  final VoidCallback? onPickValidityDate;

  const StepForm({
    super.key,
    required this.unitController,
    required this.subjectController,
    required this.date,
    required this.onPickDate,
    required this.subjectMissing,
    required this.recipientNameController,
    required this.recipientIdentityController,
    required this.recipientTitleController,
    required this.recipientAddressController,
    this.searchParties,
    required this.savingParty,
    this.onSaveParty,
    required this.classification,
    required this.onClassificationChanged,
    required this.specificFields,
    required this.specificControllers,
    required this.validityRelevant,
    required this.validityMode,
    required this.onValidityModeChanged,
    required this.validityDate,
    required this.onPickValidityDate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        _section(context, 'Unit & perihal'),
        TextField(
          controller: unitController,
          decoration: const InputDecoration(
            labelText: 'Unit',
            helperText: 'Mis. DIR (Dewan Direktur)',
            isDense: true,
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: subjectController,
          decoration: InputDecoration(
            labelText: 'Perihal *',
            errorText: subjectMissing ? 'Perihal wajib diisi.' : null,
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        _dateField(context),
        const SizedBox(height: AppSpacing.md),
        _classificationSection(context),
        const SizedBox(height: AppSpacing.lg),
        _recipientSection(context),
        if (specificFields.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _specificSection(context),
        ],
        if (validityRelevant) ...[
          const SizedBox(height: AppSpacing.md),
          _validitySection(context),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

  Widget _dateField(BuildContext context) {
    final formatter = DateFormat('d MMMM yyyy', 'id_ID');
    return InkWell(
      onTap: onPickDate,
      borderRadius: AppSpacing.borderRadiusMD,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tanggal surat',
          prefixIcon: Icon(Icons.event_rounded),
          isDense: true,
        ),
        child: Text(formatter.format(date)),
      ),
    );
  }

  /// Pilihan klasifikasi surat — Umum (default) / Rahasia. Surat rahasia
  /// dicap "RAHASIA" di PDF; surat pribadi/korporat boleh dibiarkan Umum
  /// (pilihan opsional, bukan wajib).
  Widget _classificationSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context, 'Sifat surat'),
        Row(
          children: [
            Expanded(
              child: _classificationChip(
                context,
                value: 'umum',
                label: 'Umum',
                icon: Icons.work_outline_rounded,
                selectedColor: colorScheme.primaryContainer,
                onSelectedColor: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _classificationChip(
                context,
                value: 'rahasia',
                label: 'Rahasia',
                icon: Icons.lock_outline_rounded,
                selectedColor: colorScheme.errorContainer,
                onSelectedColor: colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _classificationChip(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    required Color selectedColor,
    required Color onSelectedColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = classification == value;
    return InkWell(
      onTap: () => onClassificationChanged(value),
      borderRadius: AppSpacing.borderRadiusMD,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedColor : colorScheme.surfaceContainerHighest,
          borderRadius: AppSpacing.borderRadiusMD,
          border: selected
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? onSelectedColor
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? onSelectedColor : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipientSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _section(context, 'Penerima')),
            if (searchParties != null)
              TextButton.icon(
                onPressed: () => _openPartySheet(context),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('Buku pihak'),
              ),
          ],
        ),
        TextField(
          controller: recipientNameController,
          decoration: const InputDecoration(
            labelText: 'Nama penerima',
            helperText: 'Ketik bebas atau pilih dari buku pihak.',
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: recipientIdentityController,
          decoration: const InputDecoration(
            labelText: 'NIK / identitas (opsional)',
            isDense: true,
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: recipientTitleController,
          decoration: const InputDecoration(
            labelText: 'Jabatan / instansi (opsional)',
            helperText: 'Dicetak di blok "Yth." pada surat.',
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: recipientAddressController,
          decoration: const InputDecoration(
            labelText: 'Alamat (opsional)',
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        if (onSaveParty != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: savingParty ? null : onSaveParty,
              icon: savingParty
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_rounded, size: 18),
              label: const Text('Simpan ke buku pihak'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _specificSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context, 'Field khusus jenis surat'),
        for (final field in specificFields) ...[
          TextField(
            controller: specificControllers[field.key],
            decoration: InputDecoration(
              labelText: field.label,
              isDense: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _validitySection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context, 'Masa berlaku'),
        SegmentedButton<ValidityMode>(
          segments: [
            for (final mode in ValidityMode.values)
              ButtonSegment(value: mode, label: Text(mode.label)),
          ],
          selected: {validityMode},
          onSelectionChanged: (selection) =>
              onValidityModeChanged(selection.first),
        ),
        if (validityMode == ValidityMode.untilDate) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onPickValidityDate,
            borderRadius: AppSpacing.borderRadiusMD,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Berlaku hingga tanggal',
                prefixIcon: Icon(Icons.event_available_rounded),
                isDense: true,
              ),
              child: Text(
                validityDate == null
                    ? 'Pilih tanggal'
                    : DateFormat('d MMMM yyyy', 'id_ID').format(validityDate!),
                style: validityDate == null
                    ? TextStyle(color: colorScheme.error)
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Sheet pencarian buku pihak — memilih mengisi field penerima.
  Future<void> _openPartySheet(BuildContext context) async {
    final search = searchParties;
    if (search == null) return;

    final party = await showModalBottomSheet<PartyModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _PartySheet(
        onSearch: (query) async {
          final page = await search(query);
          return page.items;
        },
      ),
    );

    if (party != null) {
      recipientNameController.text = party.name;
      if (party.identityNo != null &&
          recipientIdentityController.text.isEmpty) {
        recipientIdentityController.text = party.identityNo!;
      }
      if (party.address != null && recipientAddressController.text.isEmpty) {
        recipientAddressController.text = party.address!;
      }
    }
  }
}

/// Isi sheet buku pihak: search + daftar hasil live.
///
/// Controller search dimiliki DI SINI (bukan pemanggil): mem-dispose saat
/// route masih dianimasikan keluar menyebabkan "used after disposed".
class _PartySheet extends StatefulWidget {
  final Future<List<PartyModel>> Function(String query) onSearch;

  const _PartySheet({required this.onSearch});

  @override
  State<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends State<_PartySheet> {
  static const _sheetHeightFactor = 0.7;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<PartyModel> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSearch();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.onSearch(_controller.text.trim());
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      // Keyboard + inset sistem bawah (home indicator / gesture bar).
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + context.systemBottomInset,
      ),
      child: SizedBox(
        height: mediaQuery.size.height * _sheetHeightFactor,
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.paddingMD,
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cari nama / NIK di buku pihak…',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _results.isEmpty
                          ? const Center(
                              child: Text('Tidak ada pihak yang cocok.'),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final party = _results[index];
                                return ListTile(
                                  leading:
                                      const Icon(Icons.person_outline_rounded),
                                  title: Text(party.name),
                                  subtitle: party.identityNo != null
                                      ? Text('NIK ${party.identityNo}')
                                      : null,
                                  onTap: () => Navigator.of(context).pop(party),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
