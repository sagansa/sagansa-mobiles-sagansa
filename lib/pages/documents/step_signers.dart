import 'package:flutter/material.dart';

import '../../services/document/document_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

/// Langkah 5 wizard — penandatangan: pembuat (direktur, otomatis via blok
/// TTD server) read-only + opsi ajukan tanda tangan komisaris dari
/// direktori signer aktif (GET /signers).
///
/// Semua blok memakai kartu dengan padding 16 yang sama (judul section di
/// luar kartu) supaya tepi kiri-kanan isi sejajar — sebelumnya
/// `SwitchListTile` polos menempel ke tepi layar dan terlihat tidak sejajar
/// dengan kartu penandatangan utama.
class StepSigners extends StatelessWidget {
  /// Signer milik pembuat (preferensi role direktur); null bila belum
  /// termuat — blok TTD tetap diisi label generik oleh server.
  final SignerModel? creatorSigner;

  final bool needCommissioner;
  final ValueChanged<bool> onNeedCommissionerChanged;

  final List<SignerModel> commissionerCandidates;
  final SignerModel? selectedCommissioner;
  final ValueChanged<SignerModel?> onSelectCommissioner;
  final bool alreadyRequested;

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const StepSigners({
    super.key,
    required this.creatorSigner,
    required this.needCommissioner,
    required this.onNeedCommissionerChanged,
    required this.commissionerCandidates,
    required this.selectedCommissioner,
    required this.onSelectCommissioner,
    required this.alreadyRequested,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        const _SectionTitle(
          title: 'Penandatangan utama',
          subtitle: 'Ditentukan otomatis dari akun pembuat surat.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          padding: AppSpacing.paddingMD,
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.draw_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creatorSigner?.displayName ?? 'Pembuat surat',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      creatorSigner == null
                          ? 'Pembuat otomatis masuk blok tanda tangan surat.'
                          : '${creatorSigner!.roleLabel} — menandatangani '
                              'otomatis lewat blok tanda tangan.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _Pill(
                icon: Icons.check_rounded,
                label: 'Otomatis',
                background: colorScheme.primaryContainer,
                foreground: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(
          title: 'Tanda tangan tambahan',
          subtitle: 'Opsional — bila surat perlu disetujui komisaris.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                value: needCommissioner,
                onChanged: onNeedCommissionerChanged,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                secondary: Icon(
                  Icons.how_to_reg_rounded,
                  color: needCommissioner
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: const Text(
                  'Butuh tanda tangan komisaris',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Surat diajukan ke komisaris untuk disetujui sebelum terbit.',
                  ),
                ),
              ),
              if (needCommissioner) ...[
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loading)
                        // Spinner cukup padding vertikal — luar kartu sudah
                        // padding MD (dobel 16 terasa longgar).
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (error != null)
                        EmptyState(
                          icon: Icons.error_outline_rounded,
                          title: error!,
                          subtitle:
                              'Terjadi kesalahan saat memuat daftar komisaris',
                          action: OutlinedButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba lagi'),
                          ),
                        )
                      else if (commissionerCandidates.isEmpty)
                        const _InlineNote(
                          icon: Icons.info_outline_rounded,
                          text:
                              'Tidak ada signer komisaris aktif. Hubungi admin '
                              'untuk menambahkan peran komisaris.',
                        )
                      else ...[
                        Text(
                          'Pilih komisaris penandatangan',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<SignerModel>(
                          initialValue: selectedCommissioner,
                          isExpanded: true,
                          items: [
                            for (final signer in commissionerCandidates)
                              DropdownMenuItem(
                                value: signer,
                                child: Text(
                                  '${signer.displayName} (${signer.roleLabel})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: onSelectCommissioner,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.how_to_reg_rounded),
                            hintText: 'Pilih komisaris',
                          ),
                        ),
                      ],
                      if (alreadyRequested) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _InlineNote(
                          icon: Icons.schedule_rounded,
                          text: 'Permintaan tanda tangan sudah diajukan untuk '
                              'surat ini.',
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Judul section + keterangan singkat di atas kartu.
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Kartu standar langkah ini — surface + radius LG + outline tipis,
/// padding 16 seragam (kecuali konten yang butuh edge-to-edge).
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = AppSpacing.paddingMD,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Label kecil berikon (status "Otomatis").
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

/// Catatan inline berikon di dalam kartu.
class _InlineNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InlineNote({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effective = color ?? colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: effective),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: effective, height: 1.35),
          ),
        ),
      ],
    );
  }
}
