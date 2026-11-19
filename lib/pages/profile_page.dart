import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/applicant_detail_model.dart';
import '../services/image_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/error_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();

  final _nicknameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _religionCtrl = TextEditingController();
  final _maritalCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _isLocked = false;
  String? _profileStatus;

  // Dokumen: file lokal yg baru dipilih (dikirim saat Simpan) + URL server.
  File? _ktpFile;
  File? _selfieFile;
  String? _ktpUrl;
  String? _selfieUrl;
  bool _deletingKtp = false;
  bool _deletingSelfie = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [
      _nicknameCtrl,
      _phoneCtrl,
      _addressCtrl,
      _nikCtrl,
      _birthPlaceCtrl,
      _birthDateCtrl,
      _religionCtrl,
      _maritalCtrl,
      _educationCtrl,
      _emergencyPhoneCtrl,
      _emergencyNameCtrl,
      _bankNameCtrl,
      _bankAccountNameCtrl,
      _bankAccountNumberCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _userService.getProfile();
      if (!mounted) return;
      _fillControllers(detail);
      setState(() {
        _isLocked = detail.isLocked;
        _profileStatus = detail.status;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorUtils.sanitize(e);
        _isLoading = false;
      });
    }
  }

  void _fillControllers(ApplicantDetail d) {
    _nicknameCtrl.text = d.nickname ?? '';
    _phoneCtrl.text = d.phone ?? '';
    _addressCtrl.text = d.address ?? '';
    _nikCtrl.text = d.nik ?? '';
    _birthPlaceCtrl.text = d.birthPlace ?? '';
    _birthDateCtrl.text = d.birthDate ?? '';
    _religionCtrl.text = d.religion ?? '';
    _maritalCtrl.text = d.maritalStatus ?? '';
    _educationCtrl.text = d.educationLevel ?? '';
    _emergencyPhoneCtrl.text = d.emergencyPhone ?? '';
    _emergencyNameCtrl.text = d.emergencyName ?? '';
    _bankNameCtrl.text = d.bankName ?? '';
    _bankAccountNameCtrl.text = d.bankAccountName ?? '';
    _bankAccountNumberCtrl.text = d.bankAccountNumber ?? '';
    _ktpUrl = d.ktpImageUrl;
    _selfieUrl = d.selfieImageUrl;
    _ktpFile = null;
    _selfieFile = null;
  }

  ApplicantDetail _collect() {
    return ApplicantDetail(
      nickname: _nicknameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      nik: _nikCtrl.text.trim(),
      birthPlace: _birthPlaceCtrl.text.trim(),
      birthDate: _birthDateCtrl.text.trim(),
      religion: _religionCtrl.text.trim(),
      maritalStatus: _maritalCtrl.text.trim(),
      educationLevel: _educationCtrl.text.trim(),
      emergencyPhone: _emergencyPhoneCtrl.text.trim(),
      emergencyName: _emergencyNameCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim(),
      bankAccountName: _bankAccountNameCtrl.text.trim(),
      bankAccountNumber: _bankAccountNumberCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = await _userService.updateProfile(
        _collect(),
        bankOnly: _isLocked,
        ktpFile: _isLocked ? null : _ktpFile,
        selfieFile: _isLocked ? null : _selfieFile,
      );
      if (!mounted) return;
      _fillControllers(updated);
      setState(() {
        _isLocked = updated.isLocked;
        _profileStatus = updated.status;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.sanitize(e))),
      );
    }
  }

  Future<void> _pickDocument(bool isKtp) async {
    if (_isLocked) return;
    final file = await ImageService.selectAndPickImage(context);
    if (file == null || !mounted) return;
    setState(() {
      if (isKtp) {
        _ktpFile = file;
      } else {
        _selfieFile = file;
      }
    });
  }

  void _clearLocalPick(bool isKtp) {
    setState(() {
      if (isKtp) {
        _ktpFile = null;
      } else {
        _selfieFile = null;
      }
    });
  }

  Future<void> _deleteServerDocument(bool isKtp) async {
    if (_isLocked) return;
    final url = isKtp ? _ktpUrl : _selfieUrl;
    if (url == null || url.isEmpty) return;
    setState(() {
      if (isKtp) {
        _deletingKtp = true;
      } else {
        _deletingSelfie = true;
      }
    });
    try {
      await _userService
          .deleteProfileImage(isKtp ? 'ktp_image' : 'selfie_image');
      if (!mounted) return;
      setState(() {
        if (isKtp) {
          _ktpUrl = null;
          _ktpFile = null;
          _deletingKtp = false;
        } else {
          _selfieUrl = null;
          _selfieFile = null;
          _deletingSelfie = false;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isKtp) {
          _deletingKtp = false;
        } else {
          _deletingSelfie = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.sanitize(e))),
      );
    }
  }

  Future<void> _pickBirthDate() async {
    if (_isLocked) return;
    DateTime initial = DateTime(2000, 1, 1);
    if (_birthDateCtrl.text.trim().isNotEmpty) {
      try {
        initial = DateTime.parse(_birthDateCtrl.text.trim());
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: GlassAppBar(title: Text('Profil Saya')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: const GlassAppBar(title: Text('Profil Saya')),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLG,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.error)),
                AppSpacing.gapVerticalMD,
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final nickname = _nicknameCtrl.text.trim();

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const GlassAppBar(title: Text('Profil Saya')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppBarInsets.top(context),
          AppSpacing.md,
          100 + context.systemBottomInset,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(colorScheme, textTheme, nickname),
              AppSpacing.gapVerticalMD,
              FormSectionCard(
                title: 'Data Pribadi',
                subtitle: _isLocked
                    ? 'Data dikunci oleh admin'
                    : 'Informasi identitas diri Anda',
                icon: Icons.person_rounded,
                iconColor: colorScheme.primary,
                trailing: _isLocked
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: AppSpacing.borderRadiusSM,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded,
                                size: 12, color: colorScheme.error),
                            const SizedBox(width: 4),
                            Text(
                              'Terkunci',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                children: [
                  _modernField(
                    ctrl: _nicknameCtrl,
                    label: 'Nama Panggilan',
                    icon: Icons.badge_outlined,
                    enabled: !_isLocked,
                  ),
                  _modernField(
                    ctrl: _phoneCtrl,
                    label: 'No. Telepon',
                    icon: Icons.phone_outlined,
                    enabled: !_isLocked,
                    keyboard: TextInputType.phone,
                  ),
                  _modernField(
                    ctrl: _nikCtrl,
                    label: 'NIK (Nomor Induk Kependudukan)',
                    icon: Icons.credit_card_outlined,
                    enabled: !_isLocked,
                    keyboard: TextInputType.number,
                  ),
                  _modernField(
                    ctrl: _birthPlaceCtrl,
                    label: 'Tempat Lahir',
                    icon: Icons.location_city_outlined,
                    enabled: !_isLocked,
                  ),
                  _buildDateField(colorScheme, textTheme),
                  _modernField(
                    ctrl: _religionCtrl,
                    label: 'Agama',
                    icon: Icons.wb_sunny_outlined,
                    enabled: !_isLocked,
                  ),
                  _modernField(
                    ctrl: _maritalCtrl,
                    label: 'Status Pernikahan',
                    icon: Icons.favorite_border_rounded,
                    enabled: !_isLocked,
                  ),
                  _modernField(
                    ctrl: _educationCtrl,
                    label: 'Pendidikan Terakhir',
                    icon: Icons.school_outlined,
                    enabled: !_isLocked,
                  ),
                  _modernField(
                    ctrl: _addressCtrl,
                    label: 'Alamat Domisili',
                    icon: Icons.home_outlined,
                    enabled: !_isLocked,
                    maxLines: 2,
                  ),
                  _modernField(
                    ctrl: _emergencyNameCtrl,
                    label: 'Kontak Darurat (Nama)',
                    icon: Icons.contact_phone_outlined,
                    enabled: !_isLocked,
                  ),
                  _modernField(
                    ctrl: _emergencyPhoneCtrl,
                    label: 'Kontak Darurat (No. Telepon)',
                    icon: Icons.emergency_outlined,
                    enabled: !_isLocked,
                    keyboard: TextInputType.phone,
                  ),
                ],
              ),
              AppSpacing.gapVerticalMD,
              FormSectionCard(
                title: 'Data Rekening Bank',
                subtitle: 'Dapat diperbarui sewaktu-waktu untuk pembayaran gaji',
                icon: Icons.account_balance_rounded,
                iconColor: colorScheme.primary,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: AppSpacing.borderRadiusSM,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Selalu Aktif',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                children: [
                  _modernField(
                    ctrl: _bankNameCtrl,
                    label: 'Nama Bank',
                    icon: Icons.account_balance_outlined,
                  ),
                  _modernField(
                    ctrl: _bankAccountNameCtrl,
                    label: 'Nama Pemilik Rekening',
                    icon: Icons.person_pin_outlined,
                  ),
                  _modernField(
                    ctrl: _bankAccountNumberCtrl,
                    label: 'Nomor Rekening',
                    icon: Icons.numbers_outlined,
                    keyboard: TextInputType.number,
                  ),
                ],
              ),
              AppSpacing.gapVerticalMD,
              FormSectionCard(
                title: 'Dokumen Verifikasi',
                subtitle: _isLocked
                    ? 'Dokumen terkunci oleh sistem'
                    : 'Format JPG/PNG, ukuran maks 2 MB',
                icon: Icons.photo_library_outlined,
                iconColor: colorScheme.primary,
                children: [
                  _documentCard(
                    title: 'Foto KTP',
                    isKtp: true,
                    localFile: _ktpFile,
                    imageUrl: _ktpUrl,
                    isDeleting: _deletingKtp,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 8),
                  _documentCard(
                    title: 'Foto Diri (Selfie)',
                    isKtp: false,
                    localFile: _selfieFile,
                    imageUrl: _selfieUrl,
                    isDeleting: _deletingSelfie,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                ],
              ),
              AppSpacing.gapVerticalMD,
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: AppSpacing.borderRadiusLG,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.shield_outlined,
                          size: 20, color: colorScheme.onSurfaceVariant),
                    ),
                    AppSpacing.gapHorizontalMD,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keamanan & Akun',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSpacing.gapVerticalXS,
                          Text(
                            'Perubahan email atau password dilayani melalui admin atau PIC cabang Anda.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapVerticalLG,
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeBottomBar(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _isSaving ? 'Menyimpan Perubahan...' : 'Simpan Perubahan',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
      ColorScheme colorScheme, TextTheme textTheme, String nickname) {
    final displayName = nickname.isNotEmpty ? nickname : 'Pengguna Sagansa';
    String initials = 'S';
    final parts =
        nickname.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      initials = (parts[0][0] + parts[1][0]).toUpperCase();
    } else if (nickname.isNotEmpty) {
      initials = nickname
          .substring(0, nickname.length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    final statusText = _isLocked
        ? 'Data Pribadi Terkunci'
        : (_profileStatus == 'submitted'
            ? 'Menunggu Verifikasi'
            : 'Profil Terbuka');

    final statusColor = _isLocked
        ? AppColors.warning
        : (_profileStatus == 'submitted' ? AppColors.info : AppColors.success);

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusLG,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapVerticalXS,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: AppSpacing.borderRadiusSM,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLocked
                                ? Icons.lock_outline_rounded
                                : Icons.lock_open_rounded,
                            size: 13,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalSM,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: AppSpacing.borderRadiusMD,
            ),
            child: Text(
              _isLocked
                  ? 'Data pribadi telah disetujui admin dan tidak dapat diubah sendiri. Data rekening bank tetap dapat diperbarui kapan pun.'
                  : 'Pastikan data Anda sesuai dengan dokumen asli. Perubahan data rekening akan digunakan untuk penyaluran gaji.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLocked) {
      final val = _birthDateCtrl.text.trim();
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Tanggal Lahir',
          filled: true,
          fillColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          prefixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMD,
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMD,
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Text(
          val.isNotEmpty ? val : '-',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return TextFormField(
      controller: _birthDateCtrl,
      readOnly: true,
      onTap: _pickBirthDate,
      decoration: InputDecoration(
        labelText: 'Tanggal Lahir',
        filled: true,
        fillColor:
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        prefixIcon: Icon(
          Icons.calendar_today_outlined,
          size: 20,
          color: colorScheme.primary,
        ),
        suffixIcon: const Icon(Icons.arrow_drop_down, size: 24),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _modernField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!enabled) {
      final value = ctrl.text.trim();
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          prefixIcon: Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMD,
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMD,
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Text(
          value.isNotEmpty ? value : '-',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor:
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: colorScheme.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _documentCard({
    required String title,
    required bool isKtp,
    required File? localFile,
    required String? imageUrl,
    required bool isDeleting,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final locked = _isLocked;
    final hasLocal = localFile != null;
    final hasServer = imageUrl != null && imageUrl.isNotEmpty;

    Widget preview;
    if (hasLocal) {
      preview = ClipRRect(
        borderRadius: AppSpacing.borderRadiusMD,
        child: Image.file(
          localFile,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else if (hasServer) {
      preview = ClipRRect(
        borderRadius: AppSpacing.borderRadiusMD,
        child: Image.network(
          imageUrl,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 140,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: AppSpacing.borderRadiusMD,
            ),
            child: Icon(Icons.broken_image_outlined,
                color: colorScheme.onSurfaceVariant),
          ),
          loadingBuilder: (ctx, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                ),
        ),
      );
    } else {
      preview = GestureDetector(
        onTap: locked ? null : () => _pickDocument(isKtp),
        child: Container(
          width: double.infinity,
          height: 110,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: AppSpacing.borderRadiusMD,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (locked ? colorScheme.onSurfaceVariant : colorScheme.primary)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  color: locked ? colorScheme.onSurfaceVariant : colorScheme.primary,
                  size: 24,
                ),
              ),
              AppSpacing.gapVerticalSM,
              Text(
                locked ? 'Belum ada foto terlampir' : 'Ambil atau Pilih Foto',
                style: textTheme.bodySmall?.copyWith(
                  color: locked
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            if (hasLocal && !locked)
              TextButton.icon(
                onPressed: () => _clearLocalPick(isKtp),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Batal', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        AppSpacing.gapVerticalXS,
        Stack(
          children: [
            preview,
            if (hasLocal)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: AppSpacing.borderRadiusSM,
                  ),
                  child: Text(
                    'Foto baru — klik Simpan',
                    style: textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            if (!locked && (hasLocal || hasServer))
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.65),
                      radius: 17,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: Colors.white),
                        tooltip: 'Ganti foto',
                        onPressed: () => _pickDocument(isKtp),
                      ),
                    ),
                    if (hasServer && !hasLocal) ...[
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.65),
                        radius: 17,
                        child: isDeleting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 16, color: Colors.white),
                                tooltip: 'Hapus foto',
                                onPressed: isDeleting
                                    ? null
                                    : () => _deleteServerDocument(isKtp),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
