import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/document/document_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

/// Langkah 1 wizard — jenis surat, template, atau salin surat lama.
///
/// Widget UI murni: semua panggilan API (getLetterTypes/getTemplates/
/// duplicateFrom/getDocuments arsip) di-orkestrasi lewat callback oleh
/// `DocumentCreateWizard`; sheet pencarian arsip memakai [searchArchive]
/// agar tetap bisa diuji dengan fake.
///
/// [locked] — draf sudah dibuat: jenis surat bersifat final di server
/// (PATCH tidak mengubah letter_type), sehingga semua pilihan dinonaktifkan
/// dengan penjelasan; mengubah jenis = buat surat baru.
class StepTypeTemplate extends StatelessWidget {
  final bool locked;
  final List<LetterTypeModel> letterTypes;
  final bool loadingTypes;
  final String? typesError;
  final VoidCallback onRetryTypes;

  final LetterTypeModel? selectedType;
  final ValueChanged<LetterTypeModel> onSelectType;

  final List<TemplateModel> templates;
  final bool loadingTemplates;
  final TemplateModel? selectedTemplate;
  final ValueChanged<TemplateModel?> onSelectTemplate;

  /// Pencarian arsip terbit — signature `getDocuments(status: terbit)`.
  final Future<PaginatedResult<DocumentModel>> Function(String query)?
      searchArchive;
  final bool duplicating;
  final ValueChanged<DocumentModel> onPickDuplicateSource;

  /// Task 21: buka alur "Upload dokumen sendiri (PDF)" (Mode B/C/D) —
  /// null = tombol disembunyikan; dinonaktifkan saat [locked].
  final VoidCallback? onUploadOwnDocument;

  const StepTypeTemplate({
    super.key,
    required this.locked,
    required this.letterTypes,
    required this.loadingTypes,
    required this.typesError,
    required this.onRetryTypes,
    required this.selectedType,
    required this.onSelectType,
    required this.templates,
    required this.loadingTemplates,
    required this.selectedTemplate,
    required this.onSelectTemplate,
    this.searchArchive,
    required this.duplicating,
    required this.onPickDuplicateSource,
    this.onUploadOwnDocument,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (loadingTypes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (typesError != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: typesError!,
        subtitle: 'Terjadi kesalahan saat memuat jenis surat',
        action: ElevatedButton.icon(
          onPressed: onRetryTypes,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba Lagi'),
        ),
      );
    }

    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        if (locked)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _LockedBanner(
              message: 'Jenis terkunci setelah draft dibuat — batalkan dan '
                  'buat surat baru bila perlu mengganti jenis.',
            ),
          ),
        Text('Pilih jenis surat',
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        if (letterTypes.isEmpty)
          const Text('Belum ada jenis surat aktif.'),
        _buildTypeGrid(context),
        const SizedBox(height: AppSpacing.lg),
        Text('Pilih template isi',
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Template mengisi awal isi surat — bisa diedit di langkah 3.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildTemplateList(context),
        const SizedBox(height: AppSpacing.lg),
        _buildDuplicateButton(context),
        if (onUploadOwnDocument != null) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: locked ? null : onUploadOwnDocument,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload dokumen sendiri (PDF)'),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeGrid(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.8,
        ),
        itemCount: letterTypes.length,
        itemBuilder: (context, index) =>
            _buildTypeCard(context, letterTypes[index]),
      );
    });
  }

  Widget _buildTypeCard(BuildContext context, LetterTypeModel type) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = selectedType?.code == type.code;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        side: selected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMD,
        onTap: locked ? null : () => onSelectType(type),
        child: Padding(
          padding: AppSpacing.paddingSM,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                type.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: selected ? FontWeight.bold : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (selectedType == null) {
      return Text(
        'Pilih jenis surat dulu untuk melihat template.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      );
    }
    if (loadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }
    if (templates.isEmpty) {
      return Text(
        'Tidak ada template untuk jenis ini — isi surat ditulis manual '
        'di langkah 3.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Column(
      children: [
        for (final template in templates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _TemplateCard(
              template: template,
              selected: selectedTemplate?.id == template.id,
              enabled: !locked,
              onTap: () => onSelectTemplate(template),
            ),
          ),
      ],
    );
  }

  Widget _buildDuplicateButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: duplicating || locked || searchArchive == null
          ? null
          : () => _openArchiveSheet(context),
      icon: duplicating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.content_copy_rounded),
      label: const Text('Salin surat lama'),
    );
  }

  /// Bottom sheet pencarian arsip surat `terbit`; memilih sumber
  /// memanggil [onPickDuplicateSource] (wizard mengeksekusi duplicateFrom).
  Future<void> _openArchiveSheet(BuildContext context) async {
    final search = searchArchive;
    if (search == null) return;

    final result = await showModalBottomSheet<DocumentModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _ArchiveSheet(
          onSearch: (query) async {
            final page = await search(query);
            return page.items;
          },
        );
      },
    );
    if (result != null) onPickDuplicateSource(result);
  }
}

/// Banner penjelas saat pilihan jenis/template terkunci (draf sudah ada).
class _LockedBanner extends StatelessWidget {
  final String message;

  const _LockedBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingSM,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 18, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu pilihan template — nama, penanda default, centang bila terpilih.
class _TemplateCard extends StatelessWidget {
  final TemplateModel template;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        side: selected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMD,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: AppSpacing.paddingSM,
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color:
                    selected ? colorScheme.primary : colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  template.name,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
              ),
              if (template.isDefault)
                Chip(
                  label: const Text('Default'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isi sheet arsip: search field + hasil live (state internal).
///
/// Controller search dimiliki DI SINI (bukan pemanggil): mem-dispose saat
/// route masih dianimasikan keluar menyebabkan "used after disposed".
class _ArchiveSheet extends StatefulWidget {
  final Future<List<DocumentModel>> Function(String query) onSearch;

  const _ArchiveSheet({required this.onSearch});

  @override
  State<_ArchiveSheet> createState() => _ArchiveSheetState();
}

class _ArchiveSheetState extends State<_ArchiveSheet> {
  static const _sheetHeightFactor = 0.75;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<DocumentModel> _results = [];
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
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * _sheetHeightFactor,
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.paddingMD,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Cari nomor / perihal arsip…',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _results.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Tidak ada surat terbit yang cocok.',
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final document = _results[index];
                                return ListTile(
                                  leading: const Icon(
                                      Icons.description_outlined),
                                  title: Text(
                                    document.number ?? 'Tanpa nomor',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    document.subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => Navigator.of(context)
                                      .pop(document),
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
