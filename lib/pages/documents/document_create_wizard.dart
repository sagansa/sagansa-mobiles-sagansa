import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/document/document_models.dart';
import '../../services/document/document_service.dart';
import '../../services/document/incoming_models.dart';
import '../../services/document/quill_html_codec.dart';
import '../../theme/app_button_style.dart';
import '../../theme/app_spacing.dart';
import '../../utils/error_utils.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_page_scaffold.dart';
import '../../widgets/app_snackbar.dart';
import 'document_detail_page.dart';
import 'document_upload_page.dart';
import 'step_attachments.dart';
import 'step_editor.dart';
import 'step_form.dart';
import 'step_preview.dart';
import 'step_signers.dart';
import 'step_type_template.dart';

/// Wizard "Buat Surat" (Mode A) — 6 langkah:
///
/// 1. Jenis & sumber (template / salin surat lama)
/// 2. Formulir (unit, perihal, tanggal, penerima, field khusus KUA)
/// 3. Isi surat (editor kaya, Delta ↔ HTML)
/// 4. Lampiran (multi-pick, label, urutan, unggah per file)
/// 5. Penandatangan (direktur otomatis + opsi komisaris)
/// 6. Pratinjau pra-final (PDF) & terbit (QR verifikasi)
///
/// Draf dibuat (createDraft) saat pertama menyimpan langkah 2, lalu setiap
/// langkah menyimpan perubahan via updateDraft. Layout adaptif: ponsel =
/// langkah vertikal; lebar ≥700 = dua kolom (daftar langkah + konten).
///
/// Mode edit (task 22): isi [documentId] untuk membuka draf/salinan yang
/// sudah ada — wizard memuat detail (perihal/unit/tanggal/metadata +
/// bodyHtml ke editor via HtmlToDelta) dan mulai di langkah Formulir;
/// null (default) = alur buat baru task 20.
///
/// Mode balasan (Task 11 fase 1b): isi [replyTo] dengan surat masuk yang
/// dibalas — wizard menampilkan banner "Membalas: …", melakukan prefill
/// langkah 2 (penerima = pengirim surat, perihal `Re: …`), menyisipkan
/// paragraf pembuka "Menanggapi surat Saudara …" DI DEPAN isi template
/// (langkah 3), dan mengirim `in_reply_to` saat createDraft. Jenis surat
/// tetap dipilih pengguna (tidak di-auto).
///
/// [service] seam test — produksi memakai `DocumentService()`.
/// [fetchUrl] seam unduh pratinjau pra-final (produksi: http.get tanpa
/// bearer, URL signed) — pola DocumentDetailPage.
class DocumentCreateWizard extends StatefulWidget {
  final DocumentService? service;

  /// ID draf yang diedit (dari detail page aksi "Edit"); null = draf baru.
  final String? documentId;

  /// Surat masuk yang dibalas (mode balasan); null = alur biasa.
  final IncomingLetterModel? replyTo;

  final Future<Uint8List> Function(String url)? fetchUrl;

  const DocumentCreateWizard({
    super.key,
    this.service,
    this.documentId,
    this.replyTo,
    this.fetchUrl,
  });

  @override
  State<DocumentCreateWizard> createState() => _DocumentCreateWizardState();
}

class _DocumentCreateWizardState extends State<DocumentCreateWizard> {
  static const List<String> _stepTitles = [
    'Jenis & sumber',
    'Formulir',
    'Isi surat',
    'Lampiran',
    'Penandatangan',
    'Pratinjau & terbit',
  ];

  /// Ambang layout dua kolom (tablet landscape).
  static const double _wideBreakpoint = 700;

  late final DocumentService _service = widget.service ?? DocumentService();
  late final Future<Uint8List> Function(String url) _fetchUrl =
      widget.fetchUrl ?? _fetchUrlDefault;

  int _step = 0;
  bool _saving = false;

  // ——— langkah 1: jenis & template ———
  List<LetterTypeModel> _letterTypes = [];
  bool _loadingTypes = true;
  String? _typesError;
  LetterTypeModel? _selectedType;

  List<TemplateModel> _templates = [];
  bool _loadingTemplates = false;
  TemplateModel? _selectedTemplate;
  bool _duplicating = false;

  // ——— langkah 2: formulir ———
  final TextEditingController _unitController = TextEditingController(
    text: 'DIR',
  );
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _recipientNameController =
      TextEditingController();
  final TextEditingController _recipientIdentityController =
      TextEditingController();
  final TextEditingController _recipientAddressController =
      TextEditingController();
  DateTime _date = DateTime.now();
  bool _subjectMissing = false;
  String? _pickedPartyName;
  bool _savingParty = false;

  /// Controller field khusus jenis (`specific_fields`) per key.
  Map<String, TextEditingController> _specificControllers = {};
  ValidityMode _validityMode = ValidityMode.unlimited;
  DateTime? _validityDate;

  // ——— langkah 3: editor ———
  final QuillController _quillController = QuillController.basic();
  bool _editorFromDuplicate = false;
  bool _editorUnsupported = false;
  bool _editorParseFailed = false;

  // ——— draf ———
  String? _draftId;
  bool _isDuplicate = false;

  /// Metadata yang diketahui tersimpan di server (snapshot). Dipakai untuk
  /// TIDAK mengirim key `metadata` saat form tidak berubah — penting di
  /// mode salin: PATCH metadata bersifat replace penuh, jadi mengirim
  /// nilai kosong/default akan menghapus recipient/specific salinan.
  Map<String, dynamic>? _lastSavedMetadata;

  /// Unit yang diketahui tersimpan di server. Null = tidak diketahui
  /// (mode salin: payload API tidak memuat `unit`) — jangan kirim unit di
  /// PATCH selama user tidak mengubahnya, agar unit salinan tidak tertimpa
  /// default 'DIR'.
  String? _syncedUnit;

  /// User pernah mengubah field unit sejak draf/salin terakhir — satu-satunya
  /// sinyal andal saat `_syncedUnit` tidak diketahui (mode salin).
  bool _unitEdited = false;

  // ——— langkah 4: lampiran ———
  final List<PendingAttachment> _pending = [];
  bool _picking = false;
  List<AttachmentModel> _attachments = [];
  final Set<String> _busyAttachmentIds = {};

  // ——— langkah 5: penandatangan ———
  SignerModel? _creatorSigner;
  List<SignerModel> _commissionerCandidates = [];
  bool _loadingSigners = false;
  String? _signersError;
  bool _needCommissioner = false;
  SignerModel? _selectedCommissioner;
  bool _signingRequested = false;

  // ——— langkah 6: pratinjau ———
  Uint8List? _previewBytes;
  bool _building = false;
  String? _buildError;
  bool _finalizing = false;

  /// Nomor yang dipesan (reserveNumber) sebelum pra-final pertama —
  /// Fix C1: nomor tercetak di PDF & tampil sejak pratinjau.
  String? _reservedNumber;

  @override
  void initState() {
    super.initState();
    _unitController.addListener(_onUnitChanged);
    _subjectController.addListener(_notify);
    _recipientNameController.addListener(_notify);
    _typesLoading = _loadLetterTypes();
    final editId = widget.documentId;
    if (editId != null) _loadExistingDraft(editId);
    final reply = widget.replyTo;
    if (reply != null) {
      // Prefill balasan (Task 11): perihal "Re: …" + penerima = pengirim
      // surat masuk (resolve exact-match buku pihak agar party dikenal —
      // tawaran "Simpan ke buku pihak" tidak muncul bila sudah terdaftar).
      _subjectController.text = 'Re: ${reply.subject}';
      final senderName = reply.senderParty?.name ?? '';
      if (senderName.isNotEmpty) {
        _recipientNameController.text = senderName;
        _resolveReplyParty(senderName);
      }
    }
  }

  /// Best-effort cocokkan nama penerima prefill ke buku pihak (exact-match
  /// case-insensitive, pola IncomingFormPage._resolveReplyParty) — cocok →
  /// tandai sebagai hasil pilihan buku pihak; gagal/tidak ada → tetap nama
  /// bebas (tawaran simpan buku pihak muncul saat menyimpan formulir).
  Future<void> _resolveReplyParty(String name) async {
    try {
      final page = await _service.getParties(query: name);
      if (!mounted) return;
      final match = page.items
          .where((party) => party.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (match != null && _recipientNameController.text.trim() == name) {
        setState(() => _pickedPartyName = match.name);
      }
    } catch (_) {
      // Buku pihak tak terjangkau → biarkan nama bebas.
    }
  }

  /// Payload `in_reply_to` createDraft mode balasan — null di alur biasa.
  Map<String, dynamic>? get _inReplyToPayload {
    final reply = widget.replyTo;
    if (reply == null) return null;
    return {
      'type': 'incoming_letter',
      'id': reply.id,
      'relation': 'balasan',
    };
  }

  /// Paragraf pembuka balasan (HTML) — disisipkan PALING DEPAN isi editor,
  /// sebelum konten template. Null di alur biasa.
  String? get _replyOpeningHtml {
    final reply = widget.replyTo;
    if (reply == null) return null;
    final number =
        reply.numberExternal ?? reply.agendaNumber;
    final datePart = reply.letterDate == null
        ? ''
        : ' tanggal ${DateFormat('d MMMM yyyy', 'id_ID').format(reply.letterDate!)}';
    return '<p>Menanggapi surat Saudara nomor ${_escapeHtml(number)}'
        '$datePart, perihal ${_escapeHtml(reply.subject)}, '
        'dengan ini kami sampaikan hal-hal sebagai berikut:</p>';
  }

  static String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Unduh pratinjau pra-final dari URL signed (tanpa bearer) — produksi.
  Future<Uint8List> _fetchUrlDefault(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh pratinjau (${response.statusCode}).');
    }
    return response.bodyBytes;
  }

  /// Future pemuatan jenis surat (dipakai mode edit menunggu daftar jenis
  /// lengkap — specific_fields diperlukan membangun field khusus).
  Future<void>? _typesLoading;

  /// Mode edit: init state wizard dari draf existing (task 22) — TANPA
  /// mengubah struktur alur; langkah/jenis/template tetap terkunci karena
  /// `_draftId` terisi sejak awal.
  Future<void> _loadExistingDraft(String id) async {
    try {
      final detail = await _service.getDetail(id);
      await _typesLoading; // jenis surat harus lengkap (specific_fields).
      if (!mounted) return;

      final code = detail.letterType?.code;
      final fullType = code == null
          ? null
          : _letterTypes.where((type) => type.code == code).firstOrNull;
      if (fullType == null) {
        showErrorSnackBar(context,
            'Jenis surat draf (${code ?? "?"}) tidak dikenal; edit tidak tersedia.');
        return;
      }

      // Prefill editor dari bodyHtml (kini diekspos backend untuk
      // draft|menunggu_ttd) — bila gagal diparse, editor kosong + banner
      // (isi tersimpan tidak berubah sampai disimpan).
      final bodyHtml = detail.bodyHtml;
      final delta = bodyHtml == null || bodyHtml.trim().isEmpty
          ? null
          : QuillHtmlCodec.tryHtmlToDelta(bodyHtml);

      setState(() {
        _draftId = detail.id;
        _isDuplicate = false;
        _selectedType = fullType;
        _selectedTemplate = null;
        _rebuildSpecificControllers(fullType);
        _subjectController.text = detail.subject;
        _date = detail.date ?? DateTime.now();
        // Unit kini ikut payload detail → prefill akurat + PATCH hanya
        // mengirim bila user mengubah (semantik _syncedUnit).
        _unitController.text = detail.unit ?? '';
        _syncedUnit = detail.unit;
        _unitEdited = false;
        _validityMode = ValidityMode.unlimited;
        _validityDate = null;
        _prefillFormFromMetadata(detail.metadata);
        _lastSavedMetadata = detail.metadata == null
            ? null
            : Map<String, dynamic>.from(detail.metadata!);
        _editorFromDuplicate = false;
        _editorUnsupported =
            bodyHtml != null && QuillHtmlCodec.hasUnsupportedHtml(bodyHtml);
        _editorParseFailed = bodyHtml != null && bodyHtml.trim().isNotEmpty
            ? delta == null
            : false;
        if (delta != null) {
          _quillController.document = Document.fromDelta(delta);
        } else {
          _quillController.clear();
        }
        // Tanda tangan yang sudah diajukan tidak diulang (guard backend
        // ALREADY_SIGNED).
        _signingRequested = detail.signingRequests.isNotEmpty;
        _step = 1; // mulai di Formulir — jenis & sumber terkunci.
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  void dispose() {
    _unitController.dispose();
    _subjectController.dispose();
    _recipientNameController.dispose();
    _recipientIdentityController.dispose();
    _recipientAddressController.dispose();
    _quillController.dispose();
    for (final controller in _specificControllers.values) {
      controller.dispose();
    }
    for (final item in _pending) {
      item.labelController.dispose();
    }
    super.dispose();
  }

  void _notify() => setState(() {});

  /// Tandai unit pernah diedit user (dipakai keputusan kirim unit di PATCH).
  void _onUnitChanged() {
    _unitEdited = true;
    _notify();
  }

  // ——— langkah 1 ———

  /// Task 21: "Upload dokumen sendiri (PDF)" — jenis WAJIB dipilih dulu
  /// (bottom sheet) karena createDraft butuh letter_type; draf minimal
  /// dibuat (perihal "Surat {jenis}", editable nanti) lalu DocumentUploadPage
  /// dibuka untuk Mode B/C/D. Kembali dari sana wizard ditutup — state
  /// wizard (tanpa draf) basi dan daftar arsip pemanggil di-refresh.
  Future<void> _uploadOwnDocument() async {
    if (_saving || _duplicating) return;
    if (_letterTypes.isEmpty) {
      showErrorSnackBar(
          context, 'Jenis surat belum tersedia; coba lagi sebentar.');
      return;
    }
    final type = await showModalBottomSheet<LetterTypeModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: AppSpacing.paddingMD,
                child: Text(
                  'Pilih jenis surat untuk dokumen Anda',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final type in _letterTypes)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(type.name),
                  subtitle: Text(type.code),
                  onTap: () => Navigator.of(sheetContext).pop(type),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final draft = await _service.createDraft(
        letterTypeCode: type.code,
        unit: 'DIR',
        subject: 'Surat ${type.name}',
        date: DateTime.now(),
        // Mode balasan + unggah sendiri: tautan tetap terjaga.
        inReplyTo: _inReplyToPayload,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentUploadPage(
            documentId: draft.id,
            documentSubject: draft.subject,
            mode: DocumentUploadMode.uploadDraft,
            service: _service,
          ),
        ),
      );
      // Tutup wizard ke pemanggil (list arsip refresh saat kembali).
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadLetterTypes() async {
    setState(() {
      _loadingTypes = true;
      _typesError = null;
    });
    try {
      final types = await _service.getLetterTypes();
      if (!mounted) return;
      setState(() {
        _letterTypes = types;
        _loadingTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _typesError = ErrorUtils.sanitize(e, fallback: 'Gagal memuat jenis surat.');
        _loadingTypes = false;
      });
    }
  }

  Future<void> _selectType(LetterTypeModel type) async {
    // Fix review: setelah draf ada jenis terkunci — mengganti jenis di UI
    // tanpa mengubah draf server hanya menyesatkan. Lihat banner langkah 1.
    if (_draftId != null) return;
    if (_selectedType?.code == type.code) return;
    setState(() {
      _selectedType = type;
      _selectedTemplate = null;
      _templates = [];
      _editorUnsupported = false;
      _editorParseFailed = false;
      _editorFromDuplicate = false;
      _rebuildSpecificControllers(type);
    });
    await _loadTemplatesFor(type, autoSelectDefault: true);
  }

  /// Muat template jenis terpilih. [autoSelectDefault] false dipakai mode
  /// salin (draf sudah punya isi — template hanya ditampilkan, tak dipilih).
  Future<void> _loadTemplatesFor(
    LetterTypeModel type, {
    required bool autoSelectDefault,
  }) async {
    setState(() => _loadingTemplates = true);
    try {
      final templates = await _service.getTemplates(type.code);
      if (!mounted || _selectedType?.code != type.code) return;
      final defaultTemplate = autoSelectDefault
          ? templates.where((t) => t.isDefault).firstOrNull ??
              templates.firstOrNull
          : null;
      setState(() {
        _templates = templates;
        if (autoSelectDefault) _selectedTemplate = defaultTemplate;
        _loadingTemplates = false;
      });
      if (autoSelectDefault) _applyTemplateToEditor(defaultTemplate);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTemplates = false);
      // Mode balasan: template gagal dimuat tidak boleh ikut menghilangkan
      // paragraf pembuka "Menanggapi surat Saudara …" (Task 11) — editor
      // diisi pembuka saja; template menyusul bila user memuat ulang.
      if (widget.replyTo != null) _applyTemplateToEditor(null);
      showErrorSnackBar(context, e);
    }
  }

  void _rebuildSpecificControllers(LetterTypeModel type) {
    for (final controller in _specificControllers.values) {
      controller.dispose();
    }
    _specificControllers = {
      for (final field in type.specificFields ?? const <LetterSpecificField>[])
        field.key: TextEditingController(),
    };
  }

  /// Prefill editor dari body template (HTML → Delta). Mode balasan:
  /// paragraf pembuka "Menanggapi surat Saudara …" disisipkan PALING
  /// DEPAN, sebelum konten template (Task 11 — paragraf duluan, template
  /// menyusul). Tanpa template, editor tetap berisi paragraf pembuka.
  ///
  /// Template yang gagal dikonversi TIDAK boleh menelan paragraf pembuka:
  /// konversi dicoba ulang untuk pembuka saja (banner peringatan template
  /// tetap tampil).
  void _applyTemplateToEditor(TemplateModel? template) {
    final replyOpening = _replyOpeningHtml;
    final templateHtml = template?.bodyHtml;
    final html = (replyOpening ?? '') + (templateHtml ?? '');
    if (html.trim().isEmpty) {
      _quillController.clear();
      return;
    }
    var delta = QuillHtmlCodec.tryHtmlToDelta(html);
    final openingOnlyFallback = delta == null && replyOpening != null;
    if (openingOnlyFallback) {
      delta = QuillHtmlCodec.tryHtmlToDelta(replyOpening);
    }
    setState(() {
      _editorUnsupported = QuillHtmlCodec.hasUnsupportedHtml(html);
      _editorParseFailed = delta == null;
      if (delta != null) {
        _quillController.document = Document.fromDelta(delta);
      } else {
        _quillController.clear();
      }
    });
  }

  void _selectTemplate(TemplateModel? template) {
    // Fix review: pilihan template juga terkunci setelah draf ada.
    if (_draftId != null) return;
    setState(() => _selectedTemplate = template);
    _applyTemplateToEditor(template);
  }

  /// "Salin surat lama" — duplicateFrom lalu lompat ke langkah 2.
  Future<void> _duplicateFrom(DocumentModel source) async {
    final code = source.letterType?.code ?? '';
    if (code.isEmpty) {
      showErrorSnackBar(
          context, 'Jenis surat sumber tidak diketahui; tidak dapat disalin.');
      return;
    }
    setState(() => _duplicating = true);
    try {
      final draft = await _service.duplicateFrom(
        source.id,
        letterTypeCode: code,
        subject: 'Salinan — ${source.subject}',
        date: _date,
        // Mode balasan + salin: isi disalin dari sumber, tautan balasan
        // tetap dikirim agar runutan tersambung.
        inReplyTo: _inReplyToPayload,
      );
      if (!mounted) return;

      // letter_type di payload surat hanya {code, name} — pakai tipe penuh
      // dari daftar agar specific_fields ikut.
      final fullType =
          _letterTypes.where((type) => type.code == code).firstOrNull;
      if (fullType == null) {
        throw Exception('Jenis surat $code tidak dikenal.');
      }

      setState(() {
        _draftId = draft.id;
        _isDuplicate = true;
        _selectedType = fullType;
        _selectedTemplate = null;
        _subjectController.text = 'Salinan — ${source.subject}';
        _editorFromDuplicate = true;
        _editorUnsupported = false;
        _editorParseFailed = false;
        _quillController.clear();
        _rebuildSpecificControllers(fullType);
        // Fix review: backend menyalin metadata + unit sumber — prefill form
        // dari metadata salinan agar PATCH berikutnya TIDAK mendorong nilai
        // kosong/default yang menghapus isi salinan (replace penuh).
        _validityMode = ValidityMode.unlimited;
        _validityDate = null;
        _prefillFormFromMetadata(draft.metadata);
        _lastSavedMetadata = draft.metadata == null
            ? null
            : Map<String, dynamic>.from(draft.metadata!);
        // Payload API tidak memuat `unit` → nilai tersimpan tidak diketahui;
        // draf baru — penanda edit unit dimulai bersih.
        _syncedUnit = null;
        _unitEdited = false;
        _step = 1;
      });
      // Template hanya ditampilkan (locked) — draf salinan sudah berisi.
      unawaited(_loadTemplatesFor(fullType, autoSelectDefault: false));
      showSuccessSnackBar(context, 'Draf salinan dibuat — lanjutkan formulir.');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  // ——— langkah 2 ———

  /// Prefill field formulir dari metadata salinan (backend menyalin
  /// metadata sumber saat duplicateFrom) — bagian Fix review #1.
  void _prefillFormFromMetadata(Map<String, dynamic>? metadata) {
    final recipient = metadata?['recipient'];
    if (recipient is Map) {
      _recipientNameController.text = recipient['name']?.toString() ?? '';
      _recipientIdentityController.text =
          recipient['identity_no']?.toString() ?? '';
      _recipientAddressController.text =
          recipient['address']?.toString() ?? '';
      _pickedPartyName = _recipientNameController.text.trim().isEmpty
          ? null
          : _recipientNameController.text.trim();
    }
    final specific = metadata?['specific'];
    if (specific is Map) {
      specific.forEach((key, value) {
        final controller = _specificControllers[key.toString()];
        if (controller != null) controller.text = value?.toString() ?? '';
      });
    }
    final validity = metadata?['validity'];
    if (validity is Map) {
      final mode = validity['mode']?.toString();
      _validityMode = ValidityMode.values.firstWhere(
        (candidate) => candidate.value == mode,
        orElse: () => ValidityMode.unlimited,
      );
      final untilDate = validity['until_date']?.toString();
      if (untilDate != null) _validityDate = DateTime.tryParse(untilDate);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickValidityDate() async {
    final initial = _validityDate ??
        DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _validityDate = picked);
  }

  /// Fix I1 — gating masa berlaku TIDAK bergantung shape `specific_fields`:
  /// jenis KUA (kontrak domain) ATAU specific_fields memuat key
  /// `masa_berlaku` (bentuk kanonik seeder `[{key,label}]`; dulu object
  /// bersarang → parser mobile menghasilkan null → validity tak tersimpan).
  bool get _validityRelevant =>
      _selectedType?.code == 'KUA' ||
      (_selectedType?.specificFields ?? const <LetterSpecificField>[])
          .any((field) => field.key == 'masa_berlaku');

  /// Metadata penerima + field khusus + masa berlaku (hanya yang terisi).
  ///
  /// `validity` hanya disertakan bila ada isian relevan — mengirim
  /// `{mode: unlimited}` polos pada draf salinan akan menghapus masa
  /// berlaku asli (PATCH metadata = replace penuh).
  Map<String, dynamic>? _buildMetadata() {
    final name = _recipientNameController.text.trim();
    final identity = _recipientIdentityController.text.trim();
    final address = _recipientAddressController.text.trim();

    final specific = <String, String>{};
    _specificControllers.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) specific[key] = value;
    });

    final validityRelevant = _validityRelevant &&
        (specific.isNotEmpty ||
            _validityMode != ValidityMode.unlimited ||
            _validityDate != null);

    final metadata = <String, dynamic>{
      if (name.isNotEmpty)
        'recipient': {
          'name': name,
          if (identity.isNotEmpty) 'identity_no': identity,
          if (address.isNotEmpty) 'address': address,
        },
      if (specific.isNotEmpty) 'specific': specific,
      if (validityRelevant)
        'validity': {
          'mode': _validityMode.value,
          if (_validityMode == ValidityMode.untilDate && _validityDate != null)
            'until_date': _formatDate(_validityDate!),
        },
    };
    return metadata.isEmpty ? null : metadata;
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Simpan formulir — createDraft pertama kali, selanjutnya updateDraft.
  ///
  /// Fix review #1 (dua lapis): metadata hanya di-PATCH bila berbeda dari
  /// snapshot server (`_lastSavedMetadata`), dan unit hanya dikirim bila
  /// diubah dari nilai yang diketahui tersimpan (`_syncedUnit`) — di mode
  /// salin form kosong/tersentuh sedikit tidak akan menimpa metadata & unit
  /// salinan (PATCH = replace penuh).
  Future<bool> _saveForm() async {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      setState(() => _subjectMissing = true);
      return false;
    }
    final unit = _unitController.text.trim();
    final metadata = _buildMetadata();
    final metadataChanged =
        metadata != null && !_jsonDeepEquals(metadata, _lastSavedMetadata);
    // Unit dikirim hanya bila berbeda dari nilai yang diketahui tersimpan.
    // Mode salin: nilai server TIDAK diketahui (payload API tanpa unit)
    // → satu-satunya sinyal aman adalah user mengedit field-nya, agar
    // default 'DIR' tidak tertukar dengan unit sumber salinan.
    final bool unitChanged;
    if (_draftId == null) {
      unitChanged = false; // create selalu mengirim unit apa adanya.
    } else if (_syncedUnit == null) {
      unitChanged = _unitEdited && unit.isNotEmpty;
    } else {
      unitChanged = _unitEdited || (unit != _syncedUnit && unit.isNotEmpty);
    }

    setState(() => _saving = true);
    try {
      if (_draftId == null) {
        final template = _isDuplicate ? null : _selectedTemplate;
        final draft = await _service.createDraft(
          letterTypeCode: _selectedType!.code,
          unit: unit.isEmpty ? null : unit,
          subject: subject,
          date: _date,
          metadata: metadata,
          templateId: template?.id,
          // Template flow: body template langsung tersimpan sebagai awal
          // isi (editor prefill darinya — termasuk paragraf pembuka
          // balasan yang menyertainya). Duplicate flow: backend menyalin.
          bodyHtml: template == null ? null : (_replyOpeningHtml ?? '') + (template.bodyHtml ?? ''),
          // Mode balasan: tautkan draf sebagai balasan surat masuk (edge
          // letter_links dibuat backend dalam transaksi create).
          inReplyTo: _inReplyToPayload,
        );
        _draftId = draft.id;
        _syncedUnit = unit.isEmpty ? null : unit;
        _unitEdited = false;
        _lastSavedMetadata = metadata;
      } else {
        await _service.updateDraft(
          _draftId!,
          unit: unitChanged ? unit : null,
          subject: subject,
          date: _date,
          metadata: metadataChanged ? metadata : null,
        );
        if (unitChanged) {
          _syncedUnit = unit;
          _unitEdited = false;
        }
        if (metadataChanged) _lastSavedMetadata = metadata;
      }
      if (!mounted) return false;
      showSuccessSnackBar(context, 'Draf tersimpan.');
      return true;
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Tawaran simpan penerima ke buku pihak (createParty).
  Future<void> _saveParty() async {
    final name = _recipientNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingParty = true);
    try {
      await _service.createParty(
        name: name,
        identityNo: _recipientIdentityController.text.trim().isNotEmpty
            ? _recipientIdentityController.text.trim()
            : null,
        address: _recipientAddressController.text.trim().isNotEmpty
            ? _recipientAddressController.text.trim()
            : null,
      );
      if (!mounted) return;
      setState(() => _pickedPartyName = name);
      showSuccessSnackBar(context, 'Penerima disimpan ke buku pihak.');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _savingParty = false);
    }
  }

  // ——— langkah 3 ———

  /// Simpan isi surat (body_html) — dilewati bila editor kosong agar isi
  /// salinan/template di server tidak tertimpa.
  Future<bool> _saveBody() async {
    if (_draftId == null) return true;
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isEmpty) return true;

    setState(() => _saving = true);
    try {
      final html =
          QuillHtmlCodec.deltaToHtml(_quillController.document.toDelta());
      await _service.updateDraft(_draftId!, bodyHtml: html);
      return true;
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ——— langkah 4 ———

  Future<void> _loadDetail() async {
    final id = _draftId;
    if (id == null) return;
    try {
      final detail = await _service.getDetail(id);
      if (!mounted) return;
      setState(() {
        _attachments = detail.attachments.toList()
          ..sort((a, b) => a.sort != b.sort
              ? a.sort.compareTo(b.sort)
              : a.id.compareTo(b.id));
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _pickFiles() async {
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'xlsx'],
      );
      if (files.isNotEmpty) {
        setState(() {
          for (final file in files) {
            final path = file.path;
            if (path == null) continue;
            final name = file.name.isNotEmpty ? file.name : path;
            final label = name.contains('.')
                ? name.substring(0, name.lastIndexOf('.'))
                : name;
            _pending.add(PendingAttachment(
              file: File(path),
              initialLabel: label,
            ));
          }
        });
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePending(int index) {
    setState(() {
      final item = _pending.removeAt(index);
      item.labelController.dispose();
    });
  }

  void _movePending(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _pending.length) return;
    setState(() {
      final item = _pending.removeAt(index);
      _pending.insert(target, item);
    });
  }

  Future<void> _uploadPending(int index) async {
    if (_draftId == null || index >= _pending.length) return;
    final item = _pending[index];
    final label = item.labelController.text.trim();
    try {
      final attachment = await _service.uploadAttachment(
        _draftId!,
        item.file,
        label: label.isEmpty ? item.fileName : label,
        // Urutan antrean = sort; lampiran terunggah lama mendahului.
        sort: _attachments.length + index,
      );
      if (!mounted) return;
      setState(() {
        _pending.removeAt(index);
        item.labelController.dispose();
        _attachments.add(attachment);
      });
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _deleteAttachment(AttachmentModel attachment) async {
    if (_draftId == null) return;
    setState(() => _busyAttachmentIds.add(attachment.id));
    try {
      await _service.deleteAttachment(_draftId!, attachment.id);
      if (!mounted) return;
      setState(() => _attachments.removeWhere((a) => a.id == attachment.id));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _busyAttachmentIds.remove(attachment.id));
      }
    }
  }

  // ——— langkah 5 ———

  Future<void> _loadSigners() async {
    setState(() {
      _loadingSigners = true;
      _signersError = null;
    });
    try {
      final results = await Future.wait([
        _service.getMySigners(),
        _service.getSigners(),
      ]);
      if (!mounted) return;
      final mine = results[0];
      final all = results[1];

      final creator =
          mine.where((s) => s.role == 'direktur').firstOrNull ?? mine.firstOrNull;
      setState(() {
        _creatorSigner = creator;
        _commissionerCandidates = all
            .where((s) =>
                s.role == 'komisaris' &&
                (creator == null || s.id != creator.id))
            .toList(growable: false);
        _loadingSigners = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signersError = ErrorUtils.sanitize(e, fallback: 'Gagal memuat penandatangan.');
        _loadingSigners = false;
      });
    }
  }

  /// Ajukan tanda tangan komisaris bila diminta (draft → menunggu_ttd).
  Future<bool> _maybeRequestSigning() async {
    if (!_needCommissioner ||
        _selectedCommissioner == null ||
        _signingRequested ||
        _draftId == null) {
      return true;
    }
    setState(() => _saving = true);
    try {
      await _service.requestSigning(_draftId!, _selectedCommissioner!.id);
      if (!mounted) return false;
      setState(() => _signingRequested = true);
      showSuccessSnackBar(
          context, 'Tanda tangan ${_selectedCommissioner!.displayName} diajukan.');
      return true;
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ——— langkah 6 ———

  /// Pesan nomor SEBELUM pra-final pertama (Fix C1) — nomor tercetak di
  /// PDF pra-final/final. Error diabaikan: endpoint idempoten (nomor
  /// sudah ada → 200) dan finalize tetap mencadangkan lewat ensureReserved
  /// bila reserve di sini gagal (mis. jaringan putus sesaat).
  Future<void> _reserveNumberOnce() async {
    if (_draftId == null || _reservedNumber != null) return;
    try {
      final result = await _service.reserveNumber(_draftId!);
      final number = result['number']?.toString();
      if (number != null && number.isNotEmpty) {
        _reservedNumber = number;
      }
    } catch (_) {
      // Nomor menyusul via preFinal/finalize backend.
    }
  }

  /// pre-final (mode a) → unduh bytes PDF dari URL signed (tanpa bearer).
  Future<void> _buildPreview() async {
    if (_draftId == null) return;
    setState(() {
      _building = true;
      _buildError = null;
    });
    try {
      await _reserveNumberOnce();
      if (!mounted) return;
      setState(() {}); // tampilkan nomor yang baru dipesan di header.
      final result = await _service.preFinal(_draftId!, mode: 'a');
      final url = result['download_url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('URL pratinjau tidak tersedia.');
      }
      final bytes = await _fetchUrl(url);
      if (!mounted) return;
      setState(() => _previewBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _buildError = ErrorUtils.sanitize(e, fallback: 'Gagal memuat pratinjau.'));
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  /// Finalize metode a (render server) → dialog sukses + QR verifikasi.
  /// Mode balasan: dialog menawarkan "Lihat runutan" → detail surat keluar
  /// baru (tab Runutan memuat thread balasan) MENGGANTIKAN wizard di
  /// tumpukan — kembali dari detail langsung ke pemanggil wizard.
  Future<void> _finalizeLetter() async {
    if (_draftId == null || _finalizing) return;
    setState(() => _finalizing = true);
    try {
      final result = await _service.finalize(_draftId!, method: 'a');
      final fromResponse = result['number']?.toString();
      final number = (fromResponse != null && fromResponse.isNotEmpty)
          ? fromResponse
          : (_reservedNumber ?? '');
      final verifyUrl = result['verify_url']?.toString() ?? '';
      if (!mounted) return;
      final draftId = _draftId!;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _PublishSuccessDialog(
          number: number,
          verifyUrl: verifyUrl,
          onViewArchive: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop();
          },
          onViewThread: widget.replyTo != null
              ? () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => DocumentDetailPage(
                        documentId: draftId,
                        service: _service,
                      ),
                    ),
                  );
                }
              : null,
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  // ——— navigasi langkah ———

  bool get _isLastStep => _step == _stepTitles.length - 1;

  /// Validasi langkah aktif — Lanjut aktif bila null.
  String? get _stepBlockedMessage {
    switch (_step) {
      case 0:
        return _selectedType == null ? 'Pilih jenis surat dulu.' : null;
      case 1:
        if (_subjectController.text.trim().isEmpty) {
          return 'Perihal wajib diisi.';
        }
        if (_draftId == null && _unitController.text.trim().isEmpty) {
          // Backend wajib unit saat create (tanpa duplicate_from_id).
          return 'Unit wajib diisi (mis. DIR).';
        }
        if (_validityRelevant &&
            _validityMode == ValidityMode.untilDate &&
            _validityDate == null) {
          return 'Pilih tanggal berakhir masa berlaku.';
        }
        return null;
      case 2:
      case 3:
        return null;
      case 4:
        if (_needCommissioner && _selectedCommissioner == null) {
          return 'Pilih komisaris penandatangan.';
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> _goNext() async {
    if (_stepBlockedMessage != null || _saving) return;
    switch (_step) {
      case 0:
        setState(() => _step = 1);
        break;
      case 1:
        if (await _saveForm()) {
          setState(() {
            _step = 2;
            _subjectMissing = false;
          });
        }
        break;
      case 2:
        if (await _saveBody()) {
          setState(() => _step = 3);
          _loadDetail();
        }
        break;
      case 3:
        setState(() => _step = 4);
        _loadSigners();
        _loadDetail();
        break;
      case 4:
        if (await _maybeRequestSigning()) {
          setState(() => _step = 5);
          _buildPreview();
        }
        break;
    }
  }

  void _goBack() {
    if (_step > 0) setState(() => _step -= 1);
  }

  Future<void> _confirmExit() async {
    final navigator = Navigator.of(context);
    if (_draftId == null) {
      navigator.pop();
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: 'Keluar dari wizard?',
      content:
          'Draf yang sudah dibuat tetap tersimpan di arsip surat dan bisa '
          'dilanjutkan lagi dari sana.',
      confirmText: 'Keluar',
    );
    if (leave && mounted) navigator.pop();
  }

  // ——— build ———

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: AppPageScaffold(
        titleText: 'Buat Surat',
        bodyPadding: EdgeInsets.zero,
        body: SafeArea(
          top: true,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              return Column(
                children: [
                  if (widget.replyTo != null) _buildReplyBanner(context),
                  _buildStepHeader(context, wide),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStepRail(context),
                              VerticalDivider(
                                width: 1,
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                              Expanded(child: _buildStepContent()),
                            ],
                          )
                        : _buildStepContent(),
                  ),
                  _buildBottomBar(context, textTheme),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Banner mode balasan — tampil di semua langkah: "Membalas: {agenda} —
  /// {pengirim}" (wadah secondaryContainer, pola banner IncomingFormPage).
  Widget _buildReplyBanner(BuildContext context) {
    final reply = widget.replyTo!;
    final colorScheme = Theme.of(context).colorScheme;
    final sender = reply.senderParty?.name ?? 'pengirim tidak diketahui';
    return Container(
      width: double.infinity,
      color: colorScheme.secondaryContainer,
      padding: AppSpacing.paddingHorizontalMD.copyWith(
        top: AppSpacing.xs + 2,
        bottom: AppSpacing.xs + 2,
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded,
              size: 16, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Membalas: ${reply.agendaNumber} — $sender',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header ringkas: ponsel = judul langkah + progres; tablet disembunyikan
  /// (daftar langkah sudah ada di rail kiri).
  Widget _buildStepHeader(BuildContext context, bool wide) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (wide) {
      return Padding(
        padding: AppSpacing.paddingHorizontalMD.copyWith(
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_step + 1}. ${_stepTitles[_step]}',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (_draftId != null)
              Chip(
                label: const Text('Draf tersimpan'),
                avatar: Icon(
                  Icons.cloud_done_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingHorizontalMD.copyWith(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Langkah ${_step + 1} dari ${_stepTitles.length} — '
                  '${_stepTitles[_step]}',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (_draftId != null)
                Icon(Icons.cloud_done_outlined,
                    size: 16, color: colorScheme.primary),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (_step + 1) / _stepTitles.length,
          minHeight: 3,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  /// Rail daftar langkah (tablet) — langkah lewat tampil centang, aktif
  /// disorot; hanya bisa mundur ke langkah yang sudah dilewati.
  Widget _buildStepRail(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 260,
      child: ListView.builder(
        padding: AppSpacing.paddingSM,
        itemCount: _stepTitles.length,
        itemBuilder: (context, index) {
          final active = index == _step;
          final visited = index < _step;
          final reachable = index <= _step;
          return ListTile(
            enabled: reachable,
            selected: active,
            leading: Icon(
              visited
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: visited
                  ? colorScheme.primary
                  : active
                      ? colorScheme.primary
                      : colorScheme.outline,
            ),
            title: Text(
              '${index + 1}. ${_stepTitles[index]}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : null,
              ),
            ),
            onTap: reachable ? () => setState(() => _step = index) : null,
          );
        },
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return StepTypeTemplate(
          locked: _draftId != null,
          letterTypes: _letterTypes,
          loadingTypes: _loadingTypes,
          typesError: _typesError,
          onRetryTypes: _loadLetterTypes,
          selectedType: _selectedType,
          onSelectType: _selectType,
          templates: _templates,
          loadingTemplates: _loadingTemplates,
          selectedTemplate: _selectedTemplate,
          onSelectTemplate: _selectTemplate,
          searchArchive: (query) => _service.getDocuments(
            status: 'terbit',
            query: query.isEmpty ? null : query,
          ),
          duplicating: _duplicating,
          onPickDuplicateSource: _duplicateFrom,
          onUploadOwnDocument: _uploadOwnDocument,
        );
      case 1:
        final specific = _selectedType?.specificFields ??
            const <LetterSpecificField>[];
        return StepForm(
          unitController: _unitController,
          subjectController: _subjectController,
          date: _date,
          onPickDate: _pickDate,
          subjectMissing: _subjectMissing,
          recipientNameController: _recipientNameController,
          recipientIdentityController: _recipientIdentityController,
          recipientAddressController: _recipientAddressController,
          searchParties: (query) => _service.getParties(
            query: query.isEmpty ? null : query,
          ),
          savingParty: _savingParty,
          onSaveParty: _canOfferSaveParty ? _saveParty : null,
          specificFields: specific,
          specificControllers: _specificControllers,
          validityRelevant: _validityRelevant,
          validityMode: _validityMode,
          onValidityModeChanged: (mode) =>
              setState(() => _validityMode = mode),
          validityDate: _validityDate,
          onPickValidityDate: _pickValidityDate,
        );
      case 2:
        return StepEditor(
          controller: _quillController,
          fromDuplicate: _editorFromDuplicate,
          templateUnsupported: _editorUnsupported,
          templateParseFailed: _editorParseFailed,
        );
      case 3:
        return StepAttachments(
          pending: _pending,
          picking: _picking,
          onPickFiles: _pickFiles,
          onRemovePending: _removePending,
          onMovePending: _movePending,
          onUploadPending: _uploadPending,
          uploaded: _attachments,
          uploadingIds: _busyAttachmentIds,
          onDeleteUploaded: _deleteAttachment,
        );
      case 4:
        return StepSigners(
          creatorSigner: _creatorSigner,
          needCommissioner: _needCommissioner,
          onNeedCommissionerChanged: (value) =>
              setState(() => _needCommissioner = value),
          commissionerCandidates: _commissionerCandidates,
          selectedCommissioner: _selectedCommissioner,
          onSelectCommissioner: (signer) =>
              setState(() => _selectedCommissioner = signer),
          alreadyRequested: _signingRequested,
          loading: _loadingSigners,
          error: _signersError,
          onRetry: _loadSigners,
        );
      case 5:
        return StepPreview(
          previewBytes: _previewBytes,
          building: _building,
          buildError: _buildError,
          onBuild: _buildPreview,
          finalizing: _finalizing,
          onFinalize: _finalizeLetter,
          number: _reservedNumber,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Tawarkan simpan ke buku pihak bila nama terisi dan BUKAN hasil pilihan
  /// dari buku (atau sudah diubah setelah dipilih).
  bool get _canOfferSaveParty {
    final name = _recipientNameController.text.trim();
    return name.isNotEmpty && name != _pickedPartyName;
  }

  Widget _buildBottomBar(BuildContext context, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final blocked = _stepBlockedMessage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (blocked != null)
          Container(
            width: double.infinity,
            color: colorScheme.errorContainer.withValues(alpha: 0.4),
            padding: AppSpacing.paddingHorizontalMD.copyWith(
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: colorScheme.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    blocked,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: AppSpacing.paddingMD,
          child: Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: _saving ? null : _goBack,
                  child: const Text('Kembali'),
                ),
              const Spacer(),
              // Flexible: label panjang ('Lanjut ke pratinjau') + Kembali
              // melebihi lebar ponsel 360dp — tombol menyusut (label wrap),
              // bukan overflow tersembunyi.
              if (!_isLastStep)
                Flexible(
                  child: FilledButton.icon(
                    onPressed: blocked == null && !_saving ? _goNext : null,
                    style: AppButtonStyle.filled(),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(_step == 4 ? 'Lanjut ke pratinjau' : 'Lanjut'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Perbandingan nilai JSON-able (Map/List/primitif) secara dalam — urutan
/// key map diabaikan. Dipakai membandingkan metadata form vs snapshot server.
bool _jsonDeepEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_jsonDeepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonDeepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Dialog sukses penerbitan: nomor surat + QR verify_url + arsip. Mode
/// balasan: aksi tambahan "Lihat runutan" ([onViewThread], null = alur
/// biasa) membuka detail surat baru lengkap tab Runutan.
class _PublishSuccessDialog extends StatelessWidget {
  final String number;
  final String verifyUrl;
  final VoidCallback onViewArchive;
  final VoidCallback? onViewThread;

  const _PublishSuccessDialog({
    required this.number,
    required this.verifyUrl,
    required this.onViewArchive,
    this.onViewThread,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.verified_rounded, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Surat diterbitkan')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number.isEmpty ? 'Nomor menyusul di arsip' : number,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (verifyUrl.isNotEmpty)
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: QrImageView(
                data: verifyUrl,
                size: 168,
                backgroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pindai QR untuk membuka halaman verifikasi surat.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (onViewThread != null)
          TextButton.icon(
            onPressed: onViewThread,
            icon: const Icon(Icons.alt_route_rounded, size: 18),
            label: const Text('Lihat runutan'),
          ),
        TextButton(
          onPressed: onViewArchive,
          child: const Text('Lihat arsip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
