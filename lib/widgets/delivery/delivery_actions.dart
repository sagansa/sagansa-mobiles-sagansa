import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../detail/detail_section_card.dart';

class MarkReadyToShipCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onMarkReady;

  const MarkReadyToShipCard({
    super.key,
    required this.isLoading,
    required this.onMarkReady,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DetailSectionCard(
      title: 'Order Belum Siap Dikirim',
      icon: Icons.inventory_2_outlined,
      iconColor: AppColors.warning,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Belum Siap',
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
      children: [
        Text(
          'Tandai order ini sebagai siap dikirim sebelum kurir melakukan penjemputan atau mengunggah bukti pengiriman.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: isLoading ? null : onMarkReady,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              isLoading ? 'Memproses...' : 'Tandai Siap Dikirim',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class SubmitDeliveryCard extends StatelessWidget {
  final int selectedStatus;
  final bool isSubmitting;
  final bool hasPhotos;
  final Widget receiverField;
  final Widget notesField;
  final Widget photoUploader;
  final ValueChanged<int> onStatusChanged;
  final VoidCallback onSubmit;

  /// Sembunyikan pilihan "Dikembalikan". Order online hanya boleh direfund
  /// setelah status Sudah Dikirim (tombol Refund terpisah), jadi form
  /// pengiriman online tidak menawarkan opsi retur.
  final bool showReturnOption;

  const SubmitDeliveryCard({
    super.key,
    required this.selectedStatus,
    required this.isSubmitting,
    required this.hasPhotos,
    required this.receiverField,
    required this.notesField,
    required this.photoUploader,
    required this.onStatusChanged,
    required this.onSubmit,
    this.showReturnOption = true,
  });

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: selectedStatus == 6
          ? 'Laporkan Barang Kembali'
          : 'Kirim Bukti Pengiriman',
      icon: selectedStatus == 6
          ? Icons.assignment_return_outlined
          : Icons.local_shipping_outlined,
      children: [
        if (showReturnOption) ...[
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Sudah Dikirim')),
                  selected: selectedStatus == 3,
                  onSelected: (selected) {
                    if (selected) onStatusChanged(3);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Dikembalikan')),
                  selected: selectedStatus == 6,
                  onSelected: (selected) {
                    if (selected) onStatusChanged(6);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (selectedStatus == 3) receiverField else notesField,
        const SizedBox(height: 10),
        photoUploader,
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: hasPhotos && !isSubmitting ? onSubmit : null,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    selectedStatus == 6
                        ? Icons.assignment_return
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
            label: Text(
              isSubmitting
                  ? 'Mengirim...'
                  : (selectedStatus == 6
                      ? 'Laporkan Barang Kembali'
                      : 'Kirim Bukti Pengiriman'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class RefundButton extends StatelessWidget {
  final VoidCallback onRefund;

  const RefundButton({super.key, required this.onRefund});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.error,
        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.6)),
        minimumSize: const Size(double.infinity, 42),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(Icons.assignment_return, size: 18),
      label: const Text(
        'Refund / Kembalikan Order',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: onRefund,
    );
  }
}

/// Tombol pembatalan order online oleh admin — pola RefundButton.
/// Saat [isLoading] (request pembatalan in-flight) tombol disabled dan
/// menampilkan indikator progres — pola [MarkReadyToShipCard.isLoading] —
/// untuk mencegah double-submit.
class CancelOrderButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onCancel;

  const CancelOrderButton({
    super.key,
    this.isLoading = false,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.error,
        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.6)),
        minimumSize: const Size(double.infinity, 42),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: colorScheme.error,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.cancel_outlined, size: 18),
      label: Text(
        isLoading ? 'Memproses...' : 'Batalkan Order',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: isLoading ? null : onCancel,
    );
  }
}

/// Dialog konfirmasi pembatalan: alasan wajib (default
/// "Dibatalkan oleh pembeli"), confirm memanggil [onConfirm] dengan
/// alasan hasil trim. Disabled saat alasan kosong.
class CancelOrderDialog extends StatefulWidget {
  final void Function(String reason) onConfirm;

  const CancelOrderDialog({super.key, required this.onConfirm});

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  late final TextEditingController _reasonController =
      TextEditingController(text: 'Dibatalkan oleh pembeli');

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.cancel_outlined, color: colorScheme.error),
          const SizedBox(width: 10),
          Text(
            'Batalkan Order',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apakah Anda yakin ingin membatalkan order ini? '
            'Status order akan diubah menjadi "Dibatalkan" dan tidak '
            'dapat diubah lagi.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Alasan Pembatalan (Wajib)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: _reasonController.text.trim().isEmpty
              ? null
              : () => widget.onConfirm(_reasonController.text.trim()),
          child: const Text('Ya, Batalkan'),
        ),
      ],
    );
  }
}
