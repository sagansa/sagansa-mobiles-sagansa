import 'package:flutter/material.dart';
import '../models/applicant_detail_model.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/forms/form_section_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/safe_bottom_bar.dart';

class AdminProfileDetailPage extends StatefulWidget {
  final int profileId;
  const AdminProfileDetailPage({super.key, required this.profileId});

  @override
  State<AdminProfileDetailPage> createState() => _AdminProfileDetailPageState();
}

class _AdminProfileDetailPageState extends State<AdminProfileDetailPage> {
  final UserService _userService = UserService();
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _user;
  bool _locked = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _userService.getAdminProfileDetail(widget.profileId);
      if (!mounted) return;

      final dataMap = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : null;

      final rawDetails = res['details'] ??
          dataMap?['details'] ??
          (res['data'] is Map<String, dynamic> && !res.containsKey('details')
              ? res['data']
              : null);

      final rawUser = res['user'] ?? dataMap?['user'];

      setState(() {
        _detail = rawDetails is Map<String, dynamic>
            ? rawDetails
            : (res.containsKey('nickname') || res.containsKey('phone')
                ? res
                : null);
        _user = rawUser is Map<String, dynamic> ? rawUser : null;
        _locked = res['locked'] == true || dataMap?['locked'] == true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLock() async {
    setState(() => _isSaving = true);
    try {
      final newStatus = _locked ? 'draft' : 'submitted';
      final res =
          await _userService.setProfileStatus(widget.profileId, newStatus);
      if (!mounted) return;

      final dataMap = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : null;

      setState(() {
        _locked = res['locked'] == true || dataMap?['locked'] == true;
        if (res['details'] is Map<String, dynamic>) {
          _detail = res['details'] as Map<String, dynamic>;
        } else if (dataMap?['details'] is Map<String, dynamic>) {
          _detail = dataMap!['details'] as Map<String, dynamic>;
        }
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ??
                dataMap?['message']?.toString() ??
                'Status profil berhasil diperbarui.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Widget _row(String label, String? value, TextTheme textTheme,
      ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : '-',
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String? imageUrl,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppSpacing.borderRadiusMD,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: hasImage
                      ? AppColors.success.withValues(alpha: 0.15)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasImage
                        ? AppColors.success.withValues(alpha: 0.4)
                        : colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasImage ? Icons.check_circle : Icons.info_outline,
                      size: 12,
                      color: hasImage
                          ? AppColors.success
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasImage ? 'Terlampir' : 'Belum Diunggah',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasImage
                            ? AppColors.success
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalXS,
          if (hasImage)
            DetailImageView(
              imageUrl: imageUrl,
              height: 180,
              previewTitle: title,
            )
          else
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: AppSpacing.borderRadiusMD,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Belum ada foto yang diunggah',
                      style: textTheme.bodySmall?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(title: Text('Detail Profil')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: Text('Detail Profil')),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLG,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!,
                    style: TextStyle(color: colorScheme.error)),
                AppSpacing.gapVerticalMD,
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final d = _detail ?? {};
    final detail = ApplicantDetail.fromJson(d);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Detail Profil')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppBarInsets.top(context),
          AppSpacing.md,
          AppSpacing.md + context.systemBottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingMD,
              decoration: BoxDecoration(
                color: _locked
                    ? colorScheme.error.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                borderRadius: AppSpacing.borderRadiusMD,
                border: Border.all(
                  color: _locked
                      ? colorScheme.error.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _locked ? Icons.lock_outline : Icons.lock_open_outlined,
                    color: _locked ? colorScheme.error : AppColors.success,
                    size: 24,
                  ),
                  AppSpacing.gapHorizontalSM,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locked ? 'Profil Terkunci' : 'Profil Terbuka',
                          style: textTheme.titleSmall?.copyWith(
                            color: _locked ? colorScheme.error : AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSpacing.gapVerticalXS,
                        Text(
                          _locked
                              ? 'Hanya data rekening yang dapat diubah user.'
                              : 'User dapat mengubah seluruh data profil.',
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
            AppSpacing.gapVerticalMD,
            FormSectionCard(
              title: 'Data Akun & User',
              icon: Icons.person_outline,
              children: [
                _row('Nama', _user?['name'], textTheme, colorScheme),
                _row('Email', _user?['email'], textTheme, colorScheme),
                _row('Status Rekrutmen', detail.status ?? 'draft', textTheme, colorScheme),
              ],
            ),
            AppSpacing.gapVerticalMD,
            FormSectionCard(
              title: 'Data Pribadi',
              icon: Icons.badge_outlined,
              children: [
                _row('Nama Panggilan', detail.nickname, textTheme, colorScheme),
                _row('No. Telepon', detail.phone, textTheme, colorScheme),
                _row('NIK', detail.nik, textTheme, colorScheme),
                _row('Tempat Lahir', detail.birthPlace, textTheme, colorScheme),
                _row('Tanggal Lahir', detail.birthDate, textTheme, colorScheme),
                _row('Agama', detail.religion, textTheme, colorScheme),
                _row('Status Pernikahan', detail.maritalStatus, textTheme, colorScheme),
                _row('Pendidikan', detail.educationLevel, textTheme, colorScheme),
                _row('Alamat', detail.address, textTheme, colorScheme),
                _row('Kontak Darurat', detail.emergencyName, textTheme, colorScheme),
                _row('Telepon Darurat', detail.emergencyPhone, textTheme, colorScheme),
              ],
            ),
            AppSpacing.gapVerticalMD,
            FormSectionCard(
              title: 'Data Rekening Bank',
              icon: Icons.account_balance_outlined,
              children: [
                _row('Nama Bank', detail.bankName, textTheme, colorScheme),
                _row('Pemilik Rekening', detail.bankAccountName, textTheme, colorScheme),
                _row('No. Rekening', detail.bankAccountNumber, textTheme, colorScheme),
              ],
            ),
            AppSpacing.gapVerticalMD,
            FormSectionCard(
              title: 'Dokumen Verifikasi',
              subtitle: 'Foto KTP & Foto Diri untuk identifikasi pelamar',
              icon: Icons.photo_library_outlined,
              children: [
                _buildDocumentCard(
                  context: context,
                  title: 'Foto KTP',
                  icon: Icons.badge_outlined,
                  imageUrl: detail.ktpImageUrl,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                _buildDocumentCard(
                  context: context,
                  title: 'Foto Diri (Selfie)',
                  icon: Icons.face_outlined,
                  imageUrl: detail.selfieImageUrl,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              ],
            ),
            AppSpacing.gapVerticalLG,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _toggleLock,
                icon: _isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Icon(_locked ? Icons.lock_open : Icons.lock),
                label: Text(_isSaving
                    ? 'Memproses...'
                    : (_locked ? 'Buka Kunci Profil' : 'Kunci Profil')),
              ),
            ),
            AppSpacing.gapVerticalLG,
          ],
        ),
      ),
    );
  }
}
