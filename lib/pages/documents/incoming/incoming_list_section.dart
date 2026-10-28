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
import '../../../widgets/empty_state.dart';
import '../../../widgets/filter_chip_row.dart';
import '../../../widgets/modern_bottom_nav.dart';
import '../../../widgets/status_badge.dart';
import 'incoming_detail_page.dart';
import 'incoming_form_page.dart';

/// Bagian "Masuk" arsip Surat Perusahaan — buku agenda surat masuk
/// (`IncomingService.getIncoming`) dengan pola persis bagian "Keluar"
/// fase 1: pencarian debounce, chip filter, infinite scroll,
/// pull-to-refresh, serta state loading/error/kosong.
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

  const IncomingListSection({
    super.key,
    this.service,
    this.documentService,
    this.onSearchStateChanged,
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
        _buildFilterRows(colorScheme),
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
                                  : 'Surat masuk yang didaftarkan akan tampil di sini.',
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

  /// Baris chip filter: status + sifat + tahun (pola fase 1; label dari
  /// `IncomingLetterModel` bahasa Indonesia).
  Widget _buildFilterRows(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChipRow<String?>(
            options: const [null, ..._statusOptions],
            selected: _status,
            onSelected: (value) {
              setState(() => _status = value);
              _fetch();
            },
            getLabel: (status) => status == null
                ? 'Semua'
                : IncomingLetterModel.statusLabelOf(status),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilterChipRow<String?>(
            options: const [null, ..._sifatOptions],
            selected: _sifat,
            onSelected: (value) {
              setState(() => _sifat = value);
              _fetch();
            },
            getLabel: (sifat) => sifat == null
                ? 'Semua'
                : IncomingLetterModel.sifatLabelOf(sifat),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilterChipRow<int?>(
            options: [null, ..._yearOptions],
            selected: _year,
            onSelected: (value) {
              setState(() => _year = value);
              _fetch();
            },
            getLabel: (year) => year == null ? 'Semua' : year.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.md,
          ModernBottomNav.clearance(context),
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildCard(_items[idx]);
        },
      ),
    );
  }

  Widget _buildCard(IncomingLetterModel letter) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final senderName = letter.senderParty?.name;

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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusLG,
        onTap: () => _openDetail(letter),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Baris 1: nomor agenda + aksi per kartu.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            letter.agendaNumber,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Aksi Surat Masuk',
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'reply_external') {
                              _registerAsExternalReply(letter);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'reply_external',
                              child: Text(
                                  'Daftarkan sebagai balasan pihak luar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Baris 2: nomor surat pengirim (sekunder, bila ada).
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
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 3: badge sifat + badge status.
                    Row(
                      children: [
                        _buildSifatBadge(letter),
                        const SizedBox(width: AppSpacing.sm),
                        _buildStatusBadge(letter),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Baris 4: perihal.
                    Text(
                      letter.subject,
                      style: textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
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
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
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
                                  leading: const Icon(
                                      Icons.north_east_rounded),
                                  title: Text(
                                      document.number ?? 'Belum bernomor'),
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
