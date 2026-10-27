import 'package:flutter/material.dart';

import '../../services/document/document_models.dart';
import '../../theme/app_spacing.dart';

/// Langkah 5 wizard — penandatangan: pembuat (direktur, otomatis via blok
/// TTD server) read-only + opsi ajukan tanda tangan komisaris dari
/// direktori signer aktif (GET /signers).
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
      padding: AppSpacing.paddingMD,
      children: [
        Text('Penandatangan utama',
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.draw_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(creatorSigner?.displayName ?? 'Pembuat surat'),
            subtitle: Text(
              creatorSigner == null
                  ? 'Pembuat otomatis masuk blok tanda tangan surat.'
                  : '${creatorSigner!.roleLabel} — menandatangani otomatis '
                      'lewat blok tanda tangan.',
            ),
            trailing: const Icon(Icons.lock_outline_rounded, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile.adaptive(
          value: needCommissioner,
          onChanged: onNeedCommissionerChanged,
          title: const Text('Butuh tanda tangan komisaris'),
          subtitle: const Text(
            'Surat diajukan ke komisaris untuk disetujui sebelum terbit.',
          ),
        ),
        if (needCommissioner) ...[
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const Padding(
              padding: AppSpacing.paddingMD,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error!,
                    style:
                        textTheme.bodySmall?.copyWith(color: colorScheme.error)),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ],
            )
          else if (commissionerCandidates.isEmpty)
            Text(
              'Tidak ada signer komisaris aktif. Hubungi admin untuk '
              'menambahkan peran komisaris.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            )
          else
            DropdownButtonFormField<SignerModel>(
              initialValue: selectedCommissioner,
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
                labelText: 'Pilih komisaris',
                prefixIcon: Icon(Icons.how_to_reg_rounded),
                isDense: true,
              ),
            ),
          if (alreadyRequested)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Permintaan tanda tangan sudah diajukan untuk surat ini.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
