import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/document/document_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/safe_bottom_bar.dart';

/// Langkah 1 wizard — jenis surat, template, atau salin surat lama.
///
/// Widget UI murni: semua panggilan API (getLetterTypes/getTemplates/
/// duplicateFrom/getDocuments arsip/createLetterType) di-orkestrasi lewat
/// callback oleh `DocumentCreateWizard`; sheet pencarian arsip memakai
/// [searchArchive] agar tetap bisa diuji dengan fake.
///
/// [locked] — draf sudah dibuat: jenis surat bersifat final di server
/// (PATCH tidak mengubah letter_type), sehingga semua pilihan dinonaktifkan
/// dengan penjelasan; mengubah jenis = buat surat baru.
///
/// [replyMode] menampilkan anjuran jenis "Surat Tanggapan (STG)" untuk
/// balasan SP2DK/teguran/permintaan penjelasan dari instansi lain. Anjuran
/// bersifat visual — pengguna tetap memilih sendiri (kontrak test lama).
class StepTypeTemplate extends StatefulWidget {
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

  /// Mode balasan surat masuk — tampilkan anjuran STG.
  final bool replyMode;

  /// Tambah jenis surat manual (POST /letter-types). Null = fitur
  /// disembunyikan (mis. seam test lama tanpa endpoint).
  final Future<LetterTypeModel?> Function(String name, String? code)?
      onCreateType;

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
    this.replyMode = false,
    this.onCreateType,
  });

  @override
  State<StepTypeTemplate> createState() => _StepTypeTemplateState();
}

class _StepTypeTemplateState extends State<StepTypeTemplate> {
  static const String _recommendedReplyCode = 'STG';

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LetterTypeModel? get _recommendedReplyType => widget.letterTypes
      .where((type) => type.code == _recommendedReplyCode)
      .firstOrNull;

  List<LetterTypeModel> get _filteredTypes {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.letterTypes;
    return widget.letterTypes
        .where((type) =>
            type.name.toLowerCase().contains(query) ||
            type.code.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.loadingTypes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.typesError != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: widget.typesError!,
        subtitle: 'Terjadi kesalahan saat memuat jenis surat',
        action: ElevatedButton.icon(
          onPressed: widget.onRetryTypes,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba Lagi'),
        ),
      );
    }

    return ListView(
      padding: AppSpacing.paddingMD,
      children: [
        if (widget.locked)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _LockedBanner(
              message: 'Jenis terkunci setelah draft dibuat — batalkan dan '
                  'buat surat baru bila perlu mengganti jenis.',
            ),
          ),
        if (widget.replyMode) ...[
          _buildReplyRecommendation(context),
          const SizedBox(height: AppSpacing.md),
        ] else ...[
          _buildSp2dkHint(context),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilih jenis surat',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Jenis menentukan template & field khusus.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (widget.onCreateType != null)
              Tooltip(
                message: 'Tambah jenis surat',
                child: IconButton(
                  onPressed:
                      widget.locked ? null : () => _openAddTypeDialog(context),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.letterTypes.length > 4)
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Cari jenis surat…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Bersihkan pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        if (widget.letterTypes.length > 4)
          const SizedBox(height: AppSpacing.sm),
        _buildTypeList(context),
        const SizedBox(height: AppSpacing.md),
        Text('Pilih template isi',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Bisa diedit di langkah isi.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildTemplateList(context),
        const SizedBox(height: AppSpacing.md),
        _buildDuplicateButton(context),
        if (widget.onUploadOwnDocument != null) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: widget.locked ? null : widget.onUploadOwnDocument,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload dokumen sendiri (PDF)'),
          ),
        ],
      ],
    );
  }

  /// Anjuran jenis untuk balasan: menjelaskan secara kategoris bahwa
  /// tanggapan SP2DK/teguran/permintaan penjelasan masuk ke "Surat
  /// Tanggapan" (STG). Bila STG belum ada di daftar, arahkan ke tombol
  /// tambah jenis surat.
  Widget _buildReplyRecommendation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final recommended = _recommendedReplyType;
    final selected =
        recommended != null && widget.selectedType?.code == recommended.code;

    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply_all_rounded,
                size: 20,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Membalas surat dari instansi lain',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Untuk SP2DK, teguran, atau permintaan penjelasan dari DJP dan '
            'instansi lain, gunakan jenis Surat Tanggapan (STG) — template '
            'resminya sudah disiapkan untuk menanggapi surat tersebut.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (recommended == null)
            Text(
              'Jenis Surat Tanggapan (STG) belum tersedia. Tambahkan lewat '
              'tombol Tambah di kanan atas daftar jenis.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (!widget.locked)
            FilledButton.tonalIcon(
              onPressed:
                  selected ? null : () => widget.onSelectType(recommended),
              icon: Icon(
                selected ? Icons.check_circle_rounded : Icons.touch_app_rounded,
                size: 18,
              ),
              label: Text(
                selected ? 'Surat Tanggapan dipilih' : 'Pilih Surat Tanggapan',
              ),
            ),
        ],
      ),
    );
  }

  /// Petunjuk kategori untuk surat balasan (mis. SP2DK DJP, klarifikasi, teguran).
  Widget _buildSp2dkHint(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membalas SP2DK dari DJP atau surat instansi lain?',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gunakan jenis "Surat Tanggapan (STG)" atau buat jenis baru secara manual bila instansi memerlukan judul khusus.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeList(BuildContext context) {
    final types = _filteredTypes;
    final colorScheme = Theme.of(context).colorScheme;
    final canCreate = widget.onCreateType != null && !widget.locked;

    if (types.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _query.trim().isEmpty
                  ? 'Belum ada jenis surat aktif.'
                  : 'Tidak ada jenis surat yang cocok dengan "$_query".',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (canCreate) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: () => _openAddTypeDialog(
                  context,
                  initialName: _query.trim().isNotEmpty ? _query.trim() : null,
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _query.trim().isNotEmpty
                      ? 'Tambah jenis "$_query"'
                      : 'Tambah jenis surat baru',
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final type in types)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
            child: _buildTypeRow(context, type),
          ),
        if (canCreate) ...[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => _openAddTypeDialog(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.borderRadiusLG,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah jenis surat baru (manual)'),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeRow(BuildContext context, LetterTypeModel type) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = widget.selectedType?.code == type.code;
    final isStg = type.code == _recommendedReplyCode;
    final recommended = (widget.replyMode && isStg && !selected) ||
        (!widget.replyMode && isStg);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected ? colorScheme.primaryContainer : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: selected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: widget.locked ? null : () => widget.onSelectType(type),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: AppSpacing.borderRadiusSM,
                ),
                child: Text(
                  type.code,
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.rowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (isStg) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Cocok untuk Balasan SP2DK DJP / Teguran Resmi',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else if (recommended) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Disarankan untuk balasan',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else if ((type.specificFields ?? const [])
                        .isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${type.specificFields!.length} field khusus',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddTypeDialog(BuildContext context,
      {String? initialName}) async {
    final onCreateType = widget.onCreateType;
    if (onCreateType == null) return;
    final result = await showDialog<_NewLetterType>(
      context: context,
      builder: (_) => _AddLetterTypeDialog(initialName: initialName),
    );
    if (result == null) return;
    final created = await onCreateType(result.name, result.code);
    if (!mounted || created == null) return;
    // Bersihkan pencarian agar jenis baru langsung terlihat & terpilih.
    _searchController.clear();
    setState(() => _query = '');
  }

  Widget _buildTemplateList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.selectedType == null) {
      return Text(
        'Pilih jenis surat dulu untuk melihat template.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      );
    }
    if (widget.loadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.templates.isEmpty) {
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
        for (final template in widget.templates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _TemplateCard(
              template: template,
              selected: widget.selectedTemplate?.id == template.id,
              enabled: !widget.locked,
              onTap: () => widget.onSelectTemplate(template),
            ),
          ),
      ],
    );
  }

  Widget _buildDuplicateButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed:
          widget.duplicating || widget.locked || widget.searchArchive == null
              ? null
              : () => _openArchiveSheet(context),
      icon: widget.duplicating
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
    final search = widget.searchArchive;
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
    if (result != null) widget.onPickDuplicateSource(result);
  }
}

/// Nilai dialog tambah jenis surat.
class _NewLetterType {
  final String name;
  final String? code;

  const _NewLetterType({required this.name, this.code});
}

/// Dialog "Tambah jenis surat" — nama wajib, kode opsional (huruf/angka,
/// maks 8) yang bila kosong diturunkan backend dari nama.
class _AddLetterTypeDialog extends StatefulWidget {
  final String? initialName;

  const _AddLetterTypeDialog({this.initialName});

  @override
  State<_AddLetterTypeDialog> createState() => _AddLetterTypeDialogState();
}

class _AddLetterTypeDialogState extends State<_AddLetterTypeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    Navigator.of(context).pop(
      _NewLetterType(
        name: name,
        code: code.isEmpty ? null : code.toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Tambah jenis surat'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dipakai bila jenis surat yang Anda butuhkan belum ada di '
              'daftar. Jenis baru langsung bisa dipilih untuk surat ini.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama jenis surat',
                hintText: 'Mis. Surat Tanggapan',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Nama jenis surat wajib diisi.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Kode (opsional)',
                hintText: 'STG',
                helperText: 'Huruf/angka, maks. 8. Kosongkan untuk otomatis.',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              validator: (value) {
                final code = (value ?? '').trim();
                if (code.isEmpty) return null;
                if (!RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(code)) {
                  return 'Kode hanya huruf/angka, maks. 8 karakter.';
                }
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
        FilledButton(
          onPressed: _submit,
          child: const Text('Tambah'),
        ),
      ],
    );
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
      color: selected ? colorScheme.primaryContainer : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: selected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colorScheme.primary : colorScheme.outline,
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
      // Keyboard (viewInsets) + inset sistem bawah (home indicator /
      // gesture bar) — tanpa inset sistem, hasil terakhir tertutup.
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + context.systemBottomInset,
      ),
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
                                  leading:
                                      const Icon(Icons.description_outlined),
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
                                  onTap: () =>
                                      Navigator.of(context).pop(document),
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
