import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../theme/app_spacing.dart';
import '../../widgets/empty_state.dart';

/// Langkah 6 wizard — pra-final (render PDF server, tampil via pdfrx)
/// lalu terbitkan (finalize metode a) dengan dialog sukses di wizard.
///
/// [number] nomor surat yang sudah dipesan (reserveNumber) sebelum
/// pra-final pertama — Fix C1: nomor tampil di header pratinjau agar
/// user melihat nomor yang akan tercetak; null = belum tersedia.
class StepPreview extends StatelessWidget {
  final Uint8List? previewBytes;
  final bool building;
  final String? buildError;
  final VoidCallback onBuild;

  final bool finalizing;
  final VoidCallback onFinalize;

  final String? number;

  const StepPreview({
    super.key,
    required this.previewBytes,
    required this.building,
    required this.buildError,
    required this.onBuild,
    required this.finalizing,
    required this.onFinalize,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: building || finalizing ? null : onBuild,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(previewBytes == null
                      ? 'Buat pra-final'
                      : 'Perbarui pra-final'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      finalizing || previewBytes == null ? null : onFinalize,
                  icon: finalizing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Terbitkan'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppSpacing.paddingHorizontalMD.copyWith(
            top: AppSpacing.xs,
          ),
          child: Text(
            number == null || number!.isEmpty
                ? 'Nomor surat dipesan otomatis saat pra-final dibuat.'
                : 'Nomor surat: $number',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (buildError != null)
          Padding(
            padding: AppSpacing.paddingHorizontalMD,
            child: Text(
              buildError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.error),
            ),
          ),
        Expanded(
          child: Padding(
            padding: AppSpacing.paddingMD,
            child: building
                ? const Center(child: CircularProgressIndicator())
                : previewBytes == null
                    ? EmptyState(
                        icon: Icons.picture_as_pdf_outlined,
                        title: buildError == null
                            ? 'Buat pra-final untuk melihat pratinjau surat.'
                            : 'Gagal memuat pratinjau.',
                        subtitle: buildError,
                      )
                    : ClipRRect(
                        borderRadius: AppSpacing.borderRadiusMD,
                        child: PdfViewer.data(
                          previewBytes!,
                          sourceName: 'pra-final.pdf',
                          params: PdfViewerParams(
                            backgroundColor: colorScheme.surfaceContainerLowest,
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}
