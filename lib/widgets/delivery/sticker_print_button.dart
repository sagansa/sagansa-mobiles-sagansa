import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/printer_provider.dart';
import '../../theme/app_colors.dart';
import '../detail/detail_section_card.dart';
import '../detail_row.dart';

class StickerPrintButton extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isPrinting;
  final VoidCallback onPrint;

  const StickerPrintButton({
    super.key,
    required this.order,
    required this.isPrinting,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<PrinterProvider>(
      builder: (context, provider, _) {
        final bool thermalReady = provider.isEnabled;

        return DetailSectionCard(
          title: 'Cetak Resi Stiker',
          icon: Icons.print_outlined,
          trailing: _buildModeBadge(thermalReady),
          itemSpacing: 6,
          children: [
            DetailRow(
              label: 'Printer / Koneksi',
              value: thermalReady
                  ? provider.formattedEndpoint
                  : 'Mode Spooler (Non-WiFi)',
            ),
            DetailRow(
              label: 'Ukuran Label',
              value: thermalReady
                  ? '${provider.formattedSize} • ${provider.copies}x salinan'
                  : provider.formattedSize,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isPrinting ? null : onPrint,
                icon: isPrinting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        thermalReady
                            ? Icons.print
                            : Icons.receipt_outlined,
                        size: 18,
                      ),
                label: Text(
                  isPrinting
                      ? 'Mencetak...'
                      : 'Cetak Stiker Resi${provider.copies > 1 ? ' (${provider.copies}x)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeBadge(bool thermalReady) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: thermalReady
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: thermalReady
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            thermalReady ? Icons.wifi : Icons.receipt_long,
            size: 12,
            color: thermalReady ? AppColors.success : AppColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            thermalReady ? 'WiFi Thermal' : 'Spooler',
            style: TextStyle(
              color: thermalReady ? AppColors.success : AppColors.info,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
