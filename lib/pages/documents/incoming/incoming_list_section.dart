import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/document/document_models.dart';
import '../../../services/document/document_service.dart';
import '../../../services/document/incoming_models.dart';
import '../../../services/document/incoming_service.dart';
import '../../../theme/app_button_style.dart';
import '../../../theme/app_spacing.dart';
import '../../../utils/error_utils.dart';
import '../../../widgets/documents/letter_action_sheet.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/filter_bottom_sheet.dart';
import '../../../widgets/modern_bottom_nav.dart';
import '../../../widgets/safe_bottom_bar.dart';
import '../../../widgets/status_badge.dart';
import '../document_create_wizard.dart';
import 'incoming_detail_page.dart';
import 'incoming_form_page.dart';

/// Bagian "Masuk" arsip Surat Perusahaan — buku agenda surat masuk
/// (`IncomingService.getIncoming`) dengan pola persis bagian "Keluar":
/// pencarian debounce, filter sheet (tombol tune AppBar), infinite
/// scroll, pull-to-refresh, serta state loading/error/kosong.
///
/// Menu kartu "Daftarkan sebagai balasan pihak luar" (Task 11): mendaftar
/// surat masuk BARU sebagai balasan pihak luar atas salah satu surat
/// keluar terbit — pengguna memilih surat keluarnya (sheet pencarian),
/// lalu `IncomingFormPage` mode `replyToDocument` terbuka (surat masuk
/// baru = ANAK surat keluar terpilih; edge balasan dibuat backend dari
/// `in_reply_to` dalam transaksi registrasi).
///
/// Dipakai sebagai anak `IndexedStack` di `DocumentListPage` sehingga
/// state tiap tab terpisah dan dipertahankan saat pindah tab.
///
/// [service] & [documentService] seam test — produksi memakai instance
/// default. [onSearchStateChanged] memberi tahu induk saat baris pencarian
/// dibuka/ditutup (ikon search AppBar mengikuti tab aktif).
class IncomingListSection extends StatefulWidget {
  final IncomingService? service;

  /// Surat keluar: pencarian picker balasan + prefill buku pihak form.
  final DocumentService? documentService;

  final VoidCallback? onSearchStateChanged;

  /// Dipanggil saat filter diterapkan/direset — induk me-refresh badge
  /// tombol tune di AppBar.
  final VoidCallback? onFilterChanged;

  /// Buka form "Daftarkan Surat Masuk" — dipakai ajakan di banner & state
  /// kosong agar alur "surat dari instansi lain → balas" mudah ditemukan
  /// (bukan hanya lewat tombol + di AppBar).
  final VoidCallback? onRegisterIncoming;

  const IncomingListSection({
    super.key,
    this.service,
    this.documentService,
    this.onSearchStateChanged,
    this.onFilterChanged,
    this.onRegisterIncoming,
  });

  @override
  State<IncomingListSection> createState() => IncomingListSectionState();
}

class IncomingListSectionState extends State<IncomingListSection> {
  late final IncomingService _service = widget.service ?? IncomingService();
  late final DocumentService _documentService =
      widget.documentService ?? DocumentService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormatter = DateFormat('d MMM yyyy', 'id_ID');
  Timer? _searchDebounce;

  List<IncomingLetterModel> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Filter aktif — null berarti "Semua".
  String? _status;
  String? _sifat;
  int? _year;
  String? _query;
  bool _isSearchActive = false;

  /// Ajakan "daftarkan surat dari instansi lain" bisa disembunyikan —
  /// pengguna berpengalaman tidak perlu banner berulang.
  bool _hintDismissed = false;

  /// Opsi tahun filter: Semua + 3 tahun terakhir (pola fase 1).
  late final List<int> _yearOptions = List.generate(
    3,
    (i) => DateTime.now().year - i,
  );

  static const List<String> _statusOptions = [
    'terdaftar',
    'diproses',
    'selesai',
  ];

  static const List<String> _sifatOptions = [
    'biasa',
    'segera',
    'rahasia',
  ];

  /// Baris pencarian sedang tampil (dibaca AppBar induk untuk ikon
  /// search/close).
  bool get isSearchActive => _isSearchActive;

  /// Jumlah filter aktif (badge tombol tune AppBar induk).
  int get activeFilterCount =>
      (_status != null ? 1 : 0) +
      (_sifat != null ? 1 : 0) +
      (_year != null ? 1 : 0);

  /// Buka sheet filter — pola `FilterBottomSheet` standar arsip
  /// (supplier/dll): status, sifat, tahun. Bukan baris chip inline.
  void openFilterSheet(BuildContext context) {
    FilterBottomSheet.show(
      context,
      title: 'Filter Surat Masuk',
      fields: [
        DropdownFilterField<String?>(
          label: 'Status',
          value: _status,
          options: [
            (null, 'Semua'),
            for (final status in _statusOptions)
              (status, IncomingLetterModel.statusLabelOf(status)),
          ],
        ),
        DropdownFilterField<String?>(
          label: 'Sifat',
          value: _sifat,
          options: [
            (null, 'Semua'),
            for (final sifat in _sifatOptions)
              (sifat, IncomingLetterModel.sifatLabelOf(sifat)),
          ],
        ),
        DropdownFilterField<int?>(
          label: 'Tahun',
          value: _year,
          options: [
            (null, 'Semua'),
            for (final year in _yearOptions) (year, year.toString()),
          ],
        ),
      ],
      onApply: (values) {
        setState(() {
          _status = values['Status'] as String?;
          _sifat = values['Sifat'] as String?;
          _year = values['Tahun'] as int?;
        });
        widget.onFilterChanged?.call();
        _fetch();
      },
      onReset: () {
        setState(() {
          _status = null;
          _sifat = null;
          _year = null;
        });
        widget.onFilterChanged?.call();
        _fetch();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Buka/tutup baris pencarian — dipanggil ikon search di AppBar induk
  /// untuk tab aktif.
  void toggleSearch() {
    if (_isSearchActive) {
      _closeSearch();
    } else {
      setState(() => _isSearchActive = true);
      widget.onSearchStateChanged?.call();
    }
  }

  /// Muat ulang daftar dari halaman pertama — dipanggil induk setelah
  /// kembali dari form pendaftaran (Task 9).
  void refresh() => _fetch();

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = 1;
      _items = [];
      _hasMore = true;
    });
    try {
      final result = await _service.getIncoming(
        status: _status,
        sifat: _sifat,
        year: _year,
        query: _query,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items.toList();
        _hasMore = result.hasMore;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorUtils.sanitize(e);
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.getIncoming(
        status: _status,
        sifat: _sifat,
        year: _year,
        query: _query,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  /// Pencarian dengan debounce 400 ms (pola fase 1) — request dikirim
  /// lewat field `q` backend.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = value.trim().isEmpty ? null : value.trim();
      if (q == _query) return;
      _query = q;
      _fetch();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _isSearchActive = false;
      _query = null;
    });
    widget.onSearchStateChanged?.call();
    _fetch();
  }

  /// Buka detail surat masuk penuh (Task 10). Sekembali dari detail,
  /// buku agenda di-refresh — status/disposisi bisa berubah di sana.
  Future<void> _openDetail(IncomingLetterModel letter) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingDetailPage(
          letterId: letter.id,
          service: _service,
        ),
      ),
    );
    if (mounted) refresh();
  }

  /// Menu kartu "Daftarkan sebagai balasan pihak luar" (Task 11): pilih
  /// surat keluar terbit yang dibalas (sheet pencarian) → `IncomingFormPage`
  /// mode balasan eksternal. Surat masuk baru adalah ANAK surat keluar
  /// terpilih (parent=document, child=incoming, relation=balasan — arah
  /// link benar, dibuat backend Task 9 dari `in_reply_to`). Prefill
  /// pengirim = penerima surat keluar (metadata detail, best-effort —
  /// payload list tidak memuatnya; gagal → ketik bebas).
  Future<void> _registerAsExternalReply(IncomingLetterModel letter) async {
    final document = await showModalBottomSheet<DocumentModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _OutgoingPickerSheet(
        onSearch: (query) async {
          final page = await _documentService.getDocuments(
            status: 'terbit',
            query: query.isEmpty ? null : query,
          );
          return page.items;
        },
      ),
    );
    if (document == null || !mounted) return;

    // Best-effort prefill pengirim = penerima surat keluar (metadata
    // hanya ada di detail, bukan payload list).
    var partyName = '';
    try {
      final detail = await _documentService.getDetail(document.id);
      final recipient = detail.metadata?['recipient'];
      if (recipient is Map) {
        partyName = recipient['name']?.toString() ?? '';
      }
    } catch (_) {
      // Detail tak terjangkau → pengirim diketik/pilih di form.
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingFormPage(
          service: _service,
          documentService: _documentService,
          replyToDocument: ReplyToDocument(
            id: document.id,
            partyName: partyName,
            subject: document.subject,
            number: document.number,
          ),
        ),
      ),
    );
    if (mounted) refresh(); // balasan terdaftar → buku agenda bertambah.
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_isSearchActive) _buildSearchRow(colorScheme),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: _errorMessage!,
                      subtitle: 'Terjadi kesalahan saat memuat data',
                      action: ElevatedButton.icon(
                        onPressed: _fetch,
                        style: AppButtonStyle.elevated(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                      ),
                    )
                  : !_hasLoaded
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? EmptyState(
                              icon: Icons.inbox_outlined,
                              title: _query != null
                                  ? 'Tidak ada surat masuk yang cocok dengan pencarian.'
                                  : 'Belum ada surat masuk.',
                              subtitle: _query != null
                                  ? 'Coba kata kunci lain atau hapus filter.'
                                  : 'Punya surat dari instansi atau perusahaan '
                                      'lain? Daftarkan scan-nya di sini, lalu '
                                      'buat surat balasan dari detailnya.',
                              action: widget.onRegisterIncoming == null
                                  ? null
                                  : FilledButton.icon(
                                      onPressed: widget.onRegisterIncoming,
                                      icon:
                                          const Icon(Icons.upload_file_rounded),
                                      label:
                                          const Text('Daftarkan Surat Masuk'),
                                    ),
                            )
                          : _buildList(),
        ),
      ],
    );
  }

  Widget _buildSearchRow(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Cari agenda / nomor / perihal...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear_rounded),
            tooltip: 'Bersihkan pencarian',
            onPressed: () {
              _searchController.clear();
              if (_query != null) {
                setState(() => _query = null);
                _fetch();
              }
            },
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  Widget _buildList() {
    final showHint =
        !_hintDismissed && widget.onRegisterIncoming != null && _query == null;
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.md,
          ModernBottomNav.clearance(context),
        ),
        children: [
          if (showHint)
            _IncomingRegisterHint(
              onRegister: widget.onRegisterIncoming!,
              onDismiss: () => setState(() => _hintDismissed = true),
            ),
          for (final letter in _items) _buildCard(letter),
          if (_hasMore)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(IncomingLetterModel letter) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final senderName = letter.senderParty?.name;
    final accent = switch (letter.sifat) {
      'rahasia' => colorScheme.error,
      'segera' => Colors.amber.shade700,
      _ => colorScheme.outlineVariant,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusLG,
        child: InkWell(
          onTap: () => _openDetail(letter),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rail sifat surat: rahasia merah, segera amber, biasa netral.
                Container(width: 3, color: accent),
                Expanded(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Baris 1: nomor agenda + aksi per kartu.
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer
                                    .withValues(alpha: 0.6),
                                borderRadius: AppSpacing.borderRadiusXS,
                              ),
                              child: Text(
                                'MASUK',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                letter.agendaNumber,
                                style: textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            LetterActionMenuButton(
                              tooltip: 'Aksi Surat Masuk',
                              onTap: () => _openIncomingActions(letter),
                            ),
                          ],
                        ),
                        // Baris 2: perihal — judul kartu.
                        const SizedBox(height: AppSpacing.xs + 2),
                        Text(
                          letter.subject,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Baris 3: nomor surat pengirim (sekunder, bila ada).
                        if (letter.numberExternal != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'No. eksternal: ${letter.numberExternal}',
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        // Baris 4: badge sifat + badge status.
                        Row(
                          children: [
                            _buildSifatBadge(letter),
                            const SizedBox(width: AppSpacing.sm),
                            _buildStatusBadge(letter),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Baris 5: pengirim • tanggal diterima.
                        Row(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 13, color: colorScheme.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                [
                                  senderName ?? 'Pengirim tidak diketahui',
                                  letter.receivedAt != null
                                      ? 'Diterima ${_dateFormatter.format(letter.receivedAt!)}'
                                      : 'Tanpa tanggal terima',
                                ].join(' • '),
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Menu ⋮ kartu surat masuk — bottom sheet aksi dengan ikon & keterangan.
  Future<void> _openIncomingActions(IncomingLetterModel letter) async {
    final value = await showLetterActionSheet(
      context,
      title: letter.agendaNumber,
      subtitle: letter.subject,
      actions: [
        const LetterAction(
          value: 'open',
          label: 'Buka detail surat',
          description: 'Lihat isi scan, disposisi, dan runutan surat.',
          icon: Icons.open_in_new_rounded,
        ),
        const LetterAction(
          value: 'reply_out',
          label: 'Buat surat balasan',
          description: 'Susun surat keluar sebagai balasan surat masuk ini.',
          icon: Icons.reply_rounded,
        ),
        const LetterAction(
          value: 'reply_external',
          label: 'Daftarkan sebagai balasan pihak luar',
          description:
              'Catat surat masuk ini sebagai balasan salah satu surat keluar.',
          icon: Icons.south_west_rounded,
        ),
      ],
    );
    if (!mounted || value == null) return;

    switch (value) {
      case 'open':
        await _openDetail(letter);
      case 'reply_out':
        await _openReplyWizard(letter);
      case 'reply_external':
        await _registerAsExternalReply(letter);
    }
  }

  /// Wizard surat keluar mode balasan (prefill penerima & perihal) — alur
  /// utama "surat datang → balas" kini bisa dimulai langsung dari kartu.
  Future<void> _openReplyWizard(IncomingLetterModel letter) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCreateWizard(
          service: _documentService,
          replyTo: letter,
        ),
      ),
    );
    if (mounted) refresh();
  }

  /// Badge sifat: rahasia merah (error), segera amber (warning), biasa
  /// netral — konsisten pemetaan warna `DocumentStatusBadge` fase 1.
  Widget _buildSifatBadge(IncomingLetterModel letter) {
    final type = switch (letter.sifat) {
      'rahasia' => StatusType.error,
      'segera' => StatusType.warning,
      _ => StatusType.neutral,
    };
    return StatusBadge(label: letter.sifatLabel, type: type);
  }

  /// Badge status: terdaftar netral (abu, seperti draf), diproses amber
  /// (seperti menunggu_ttd), selesai hijau (seperti terbit).
  Widget _buildStatusBadge(IncomingLetterModel letter) {
    final type = switch (letter.status) {
      'selesai' => StatusType.success,
      'diproses' => StatusType.warning,
      _ => StatusType.neutral,
    };
    return StatusBadge(label: letter.statusLabel, type: type);
  }
}

/// Ajakan "daftarkan surat dari instansi lain" di atas daftar surat masuk —
/// membuat alur "scan surat masuk → buat balasan" bisa ditemukan tanpa
/// harus menekan tombol + di AppBar. Bisa ditutup (disembunyikan sampai
/// sesi halaman berakhir).
class _IncomingRegisterHint extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onDismiss;

  const _IncomingRegisterHint({
    required this.onRegister,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + AppSpacing.xs),
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                size: 20,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Punya surat dari instansi lain?',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tutup ajakan',
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          Text(
            'Daftarkan scan surat masuk di sini, lalu buat surat balasannya '
            'langsung dari detail surat masuk tersebut.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onRegister,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Daftarkan Surat Masuk'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet pilih surat keluar terbit untuk mode "balasan pihak luar" —
/// pencarian debounce 400 ms (pola `_SenderPartySheet`/`_PartySheet`);
/// memilih mem-pop [DocumentModel].
class _OutgoingPickerSheet extends StatefulWidget {
  final Future<List<DocumentModel>> Function(String query) onSearch;

  const _OutgoingPickerSheet({required this.onSearch});

  @override
  State<_OutgoingPickerSheet> createState() => _OutgoingPickerSheetState();
}

class _OutgoingPickerSheetState extends State<_OutgoingPickerSheet> {
  static const _sheetHeightFactor = 0.7;

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
        _error = ErrorUtils.sanitize(e);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Surat keluar yang dibalas pihak luar',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Surat masuk baru akan terautkan sebagai balasan surat '
                    'keluar terpilih.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Cari nomor / perihal surat keluar…',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
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
                          ? const Center(
                              child: Text('Tidak ada surat keluar yang cocok.'),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final document = _results[index];
                                return ListTile(
                                  leading: const Icon(Icons.north_east_rounded),
                                  title:
                                      Text(document.number ?? 'Belum bernomor'),
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
