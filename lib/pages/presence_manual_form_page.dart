import 'package:flutter/material.dart';

import '../models/shift_store_model.dart';
import '../models/store_model.dart';
import '../services/presence_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_date_field.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/section_card.dart';

/// Form input presensi manual oleh admin untuk karyawan (role staff).
///
/// Dual-mode: [presence] == null → create; [presence] != null → edit.
///
/// Backend: `AdminPresenceController` (route `admin/presences`) — CRUD penuh.
/// Authorization backend: hanya role `admin`.
///
/// Koordinat check-in/out otomatis diisi dari toko yang dipilih (admin biasanya
/// input dari jarak jauh, jadi tidak pakai GPS). Field foto (image_in/out) tidak
/// disediakan untuk input manual (backend nullable).
class PresenceManualFormPage extends StatefulWidget {
  /// Data presensi (raw Map dari response `presences/monthly`) saat mode edit.
  /// Null = mode tambah.
  final Map<String, dynamic>? presence;

  const PresenceManualFormPage({super.key, this.presence});

  @override
  State<PresenceManualFormPage> createState() => _PresenceManualFormPageState();
}

class _PresenceManualFormPageState extends State<PresenceManualFormPage> {
  final _formKey = GlobalKey<FormState>();
  final PresenceService _presenceService = PresenceService();
  final UserService _userService = UserService();

  // Lookup data
  List<Map<String, dynamic>> _employees = [];
  List<Store> _stores = [];
  List<ShiftStore> _shiftStores = [];

  // Form state
  Map<String, dynamic>? _selectedEmployee;
  Store? _selectedStore;
  ShiftStore? _selectedShiftStore;
  DateTime? _checkInDate;
  TimeOfDay? _checkInTime;
  bool _hasCheckOut = false;
  DateTime? _checkOutDate;
  TimeOfDay? _checkOutTime;
  int _status = 1; // 1=hadir, 0=tidak hadir, 2=izin

  // UI state
  bool _isLoadingLookups = true;
  String? _lookupError;
  bool _isSaving = false;

  bool get _isEditing => widget.presence != null;

  @override
  void initState() {
    super.initState();
    _prefillFromPresence();
    _loadLookups();
  }

  void _prefillFromPresence() {
    final p = widget.presence;
    if (p == null) return;

    // Status selalu "hadir" untuk input manual; abaikan nilai dari server.
    _status = 1;

    // Check-in (format: "YYYY-MM-DD HH:mm:ss" dari formatPresence()).
    final checkInStr = p['check_in'] as String?;
    if (checkInStr != null && checkInStr.isNotEmpty) {
      final dt = DateTime.tryParse(checkInStr);
      if (dt != null) {
        _checkInDate = DateTime(dt.year, dt.month, dt.day);
        _checkInTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }

    // Check-out (opsional).
    final checkOutStr = p['check_out'] as String?;
    if (checkOutStr != null && checkOutStr.isNotEmpty) {
      final dt = DateTime.tryParse(checkOutStr);
      if (dt != null) {
        _hasCheckOut = true;
        _checkOutDate = DateTime(dt.year, dt.month, dt.day);
        _checkOutTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });
    try {
      final results = await Future.wait([
        _userService.getUsers(role: 'staff'),
        _presenceService.getStores(),
        _presenceService.getShiftStores(),
      ]);

      if (!mounted) return;
      setState(() {
        _employees = results[0] as List<Map<String, dynamic>>;
        _stores = results[1] as List<Store>;
        _shiftStores = results[2] as List<ShiftStore>;
        _isLoadingLookups = false;
      });

      // Setelah lookup dimuat, resolve relasi untuk mode edit.
      _resolveEditSelections();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupError = e.toString().replaceAll('Exception: ', '');
        _isLoadingLookups = false;
      });
    }
  }

  /// Pada mode edit, resolve object store/shift/employee dari id yang ada di
  /// data presence (response monthly hanya berisi id + label, bukan object).
  void _resolveEditSelections() {
    final p = widget.presence;
    if (p == null) return;

    final storeId = int.tryParse(p['store_id']?.toString() ?? '');
    if (storeId != null) {
      _selectedStore = _stores.cast<Store?>().firstWhere(
            (s) => s?.id == storeId,
            orElse: () => null,
          );
    }

    // Response formatPresence() tidak mengembalikan shift_store_id, hanya nama.
    // Match berdasarkan nama shift_store kalau ada.
    final shiftName = p['shift_store']?.toString();
    if (shiftName != null && shiftName.isNotEmpty) {
      try {
        _selectedShiftStore = _shiftStores.firstWhere(
          (s) => s.name == shiftName,
        );
      } catch (_) {
        // Nama shift tidak cocok — biarkan null (admin pilih manual).
      }
    }

    final createdBy = p['created_by'] ?? p['created_by_id'];
    final createdByMap = createdBy is Map<String, dynamic> ? createdBy : null;
    final employeeId = int.tryParse(
      (createdByMap?['id'] ?? p['created_by_id'])?.toString() ?? '',
    );
    if (employeeId != null) {
      try {
        _selectedEmployee = _employees.firstWhere(
          (e) => int.tryParse(e['id']?.toString() ?? '') == employeeId,
        );
      } catch (_) {
        // Employee tidak ada di list staff — biarkan null.
      }
    }

    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Time pickers (date picker built into ModernDateField)
  // ---------------------------------------------------------------------------

  Future<void> _pickCheckInTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? TimeOfDay.now(),
      helpText: 'Pilih Jam Check-in',
    );
    if (picked != null) setState(() => _checkInTime = picked);
  }

  Future<void> _pickCheckOutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkOutTime ?? TimeOfDay.now(),
      helpText: 'Pilih Jam Check-out',
    );
    if (picked != null) setState(() => _checkOutTime = picked);
  }

  String? get _checkInValidationError {
    if (_checkInDate == null || _checkInTime == null) {
      return 'Tanggal & jam check-in wajib diisi';
    }
    return null;
  }

  String? get _checkOutValidationError {
    if (!_hasCheckOut) return null;
    if (_checkOutDate == null || _checkOutTime == null) {
      return 'Tanggal & jam check-out wajib diisi';
    }
    // Check-out harus setelah check-in.
    final ci = _combineDateTime(_checkInDate, _checkInTime);
    final co = _combineDateTime(_checkOutDate, _checkOutTime);
    if (ci != null && co != null && !co.isAfter(ci)) {
      return 'Check-out harus setelah check-in';
    }
    return null;
  }

  DateTime? _combineDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    // Validasi manual (field-field pakai UI custom, bukan TextFormField).
    if (_selectedEmployee == null) {
      showErrorSnackBar(context, 'Karyawan wajib dipilih.');
      return;
    }
    if (_selectedStore == null) {
      showErrorSnackBar(context, 'Toko wajib dipilih.');
      return;
    }
    if (_selectedShiftStore == null) {
      showErrorSnackBar(context, 'Shift wajib dipilih.');
      return;
    }
    if (_checkInValidationError != null) {
      showErrorSnackBar(context, _checkInValidationError!);
      return;
    }
    if (_checkOutValidationError != null) {
      showErrorSnackBar(context, _checkOutValidationError!);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final checkIn = _combineDateTime(_checkInDate, _checkInTime)!;
    final checkOut =
        _hasCheckOut ? _combineDateTime(_checkOutDate, _checkOutTime) : null;

    final store = _selectedStore!;
    final data = <String, dynamic>{
      'created_by_id': _selectedEmployee!['id'],
      'store_id': store.id,
      'shift_store_id': _selectedShiftStore!.id,
      'check_in': checkIn.toIso8601String(),
      'latitude_in': store.latitude.toString(),
      'longitude_in': store.longitude.toString(),
      'status': _status,
      if (checkOut != null) ...{
        'check_out': checkOut.toIso8601String(),
        'latitude_out': store.latitude.toString(),
        'longitude_out': store.longitude.toString(),
      },
    };

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final id = int.tryParse(widget.presence!['id']?.toString() ?? '');
        if (id == null) throw Exception('ID presensi tidak valid.');
        await _presenceService.updatePresenceManual(id, data);
      } else {
        await _presenceService.createPresenceManual(data);
      }
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        _isEditing
            ? 'Presensi berhasil diperbarui.'
            : 'Presensi berhasil ditambahkan.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody tetap false: jika true, konten bawah form tertutup bar aksi
      // (bar sudah meng-handle system inset sendiri lewat SafeBottomBar).
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(_isEditing ? 'Edit Presensi' : 'Input Presensi Manual'),
      ),
      body: Builder(
        builder: (bodyContext) => _isLoadingLookups
            ? const Center(child: CircularProgressIndicator())
            : _lookupError != null
                ? _buildErrorState()
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: AppSpacing.paddingMD.copyWith(
                          top: AppBarInsets.top(bodyContext)),
                      children: [
                        _buildEmployeeField(),
                        AppSpacing.gapVerticalMD,
                        _buildStoreField(),
                        AppSpacing.gapVerticalMD,
                        _buildShiftField(),
                        AppSpacing.gapVerticalMD,
                        _buildCheckInSection(),
                        AppSpacing.gapVerticalMD,
                        if (_selectedStore != null) ...[
                          AppSpacing.gapVerticalMD,
                          _buildCoordinateInfo(),
                        ],
                        AppSpacing.gapVerticalXL,
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            AppSpacing.gapVerticalMD,
            Text(_lookupError!, textAlign: TextAlign.center),
            AppSpacing.gapVerticalMD,
            ElevatedButton(
              onPressed: _loadLookups,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeField() {
    return SectionCard(
      title: 'Karyawan',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernDropdown<Map<String, dynamic>>(
            labelText: 'Pilih Karyawan',
            hint: 'Cari karyawan...',
            prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
            value: _selectedEmployee,
            items: _employees,
            getLabel: (e) => e['name']?.toString() ?? '-',
            getSubtitle: (e) => e['email']?.toString() ?? '',
            isRequired: true,
            // Saat edit, karyawan dikunci (backend re-check duplikat per karyawan).
            enabled: !_isEditing,
            onChanged: _isEditing
                ? null
                : (e) => setState(() => _selectedEmployee = e),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Karyawan tidak dapat diubah saat edit.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreField() {
    return SectionCard(
      title: 'Toko / Outlet',
      icon: Icons.storefront_outlined,
      child: ModernDropdown<Store>(
        labelText: 'Pilih Toko',
        hint: 'Pilih outlet...',
        prefixIcon: const Icon(Icons.store_mall_directory_outlined, size: 20),
        value: _selectedStore,
        items: _stores,
        getLabel: (s) => s.nickname,
        getSubtitle: (s) => '',
        isRequired: true,
        onChanged: (s) => setState(() => _selectedStore = s),
      ),
    );
  }

  Widget _buildShiftField() {
    return SectionCard(
      title: 'Shift',
      icon: Icons.schedule_outlined,
      child: ModernDropdown<ShiftStore>(
        labelText: 'Pilih Shift',
        hint: 'Pilih shift...',
        prefixIcon: const Icon(Icons.access_time_outlined, size: 20),
        value: _selectedShiftStore,
        items: _shiftStores,
        getLabel: (s) => s.name,
        getSubtitle: (s) => '${s.shiftStartTime} – ${s.shiftEndTime}',
        isRequired: true,
        onChanged: (s) => setState(() => _selectedShiftStore = s),
      ),
    );
  }

  Widget _buildCheckInSection() {
    return SectionCard(
      title: 'Waktu Presensi',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Check-in
          Text('Check-in',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          AppSpacing.gapVerticalSM,
          Row(
            children: [
              Expanded(
                child: ModernDateField(
                  labelText: 'Tanggal',
                  value: _checkInDate,
                  onChanged: (d) => setState(() => _checkInDate = d),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  errorText: _checkInDate == null ? 'Wajib diisi' : null,
                ),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                child: _TimeField(
                  labelText: 'Jam',
                  value: _checkInTime,
                  onTap: _pickCheckInTime,
                  errorText: _checkInTime == null ? 'Wajib diisi' : null,
                ),
              ),
            ],
          ),

          AppSpacing.gapVerticalMD,

          // Toggle check-out
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sudah check-out?'),
            subtitle:
                const Text('Aktifkan untuk mengisi waktu pulang karyawan.'),
            value: _hasCheckOut,
            onChanged: (v) => setState(() {
              _hasCheckOut = v;
              if (!v) {
                _checkOutDate = null;
                _checkOutTime = null;
              }
            }),
          ),

          if (_hasCheckOut) ...[
            AppSpacing.gapVerticalSM,
            Row(
              children: [
                Expanded(
                  child: ModernDateField(
                    labelText: 'Tanggal Pulang',
                    value: _checkOutDate,
                    onChanged: (d) => setState(() => _checkOutDate = d),
                    firstDate: _checkInDate ?? DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    errorText: _checkOutDate == null ? 'Wajib diisi' : null,
                  ),
                ),
                AppSpacing.gapHorizontalSM,
                Expanded(
                  child: _TimeField(
                    labelText: 'Jam Pulang',
                    value: _checkOutTime,
                    onTap: _pickCheckOutTime,
                    errorText: _checkOutTime == null ? 'Wajib diisi' : null,
                  ),
                ),
              ],
            ),
            if (_checkOutValidationError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _checkOutValidationError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoordinateInfo() {
    final s = _selectedStore!;
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 20, color: AppColors.info),
          AppSpacing.gapHorizontalSM,
          Expanded(
            child: Text(
              'Koordinat diisi otomatis dari toko: '
              '${s.latitude.toStringAsFixed(6)}, ${s.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return GlassContainer.bottomBar(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.lg),
      child: ModernButton(
        text: _isEditing ? 'Simpan Perubahan' : 'Simpan Presensi',
        onPressed: _isSaving ? null : _submit,
        isLoading: _isSaving,
        icon: Icons.save_outlined,
      ),
    );
  }
}

/// Field jam (TimeOfDay) read-only yang membuka [showTimePicker] saat ditekan.
/// Mengikuti gaya [ModernDateField] agar konsisten.
class _TimeField extends StatelessWidget {
  final String labelText;
  final TimeOfDay? value;
  final Future<void> Function() onTap;
  final String? errorText;

  const _TimeField({
    required this.labelText,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final hh = value?.hour.toString().padLeft(2, '0') ?? '';
    final mm = value?.minute.toString().padLeft(2, '0') ?? '';
    return TextFormField(
      controller: TextEditingController(text: hasValue ? '$hh:$mm' : ''),
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.access_time),
        errorText: errorText,
      ),
      readOnly: true,
      onTap: onTap,
    );
  }
}
