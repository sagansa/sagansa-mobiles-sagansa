import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums/delivery_status.dart';
import '../../models/enums/order_mode.dart';
import '../../providers/delivery_provider.dart';
import '../../services/image_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/status_mappers.dart';
import '../../widgets/detail_row.dart';
import '../../widgets/photo_uploader.dart';
import '../../widgets/status_badge.dart';
import 'delivery_actions.dart';
import 'delivery_stepper.dart';
import 'edit_order_assignment_sheet.dart';
import 'edit_order_items_sheet.dart';

class DirectOrderDetailView extends StatelessWidget {
  final Map<String, dynamic> order;
  final OrderMode orderMode;
  final DeliveryStatus status;

  const DirectOrderDetailView({
    super.key,
    required this.order,
    required this.orderMode,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<DeliveryProvider>();
    final formState = provider.formState;
    final listState = provider.listState;

    final deliveryStatus = status;
    final isLocked = deliveryStatus.isLocked;
    final canMarkReadyToShip = deliveryStatus.canMarkReady;
    final canSubmitDelivery = deliveryStatus.canSubmitDelivery;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMD,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeliveryStepper(
            status: status,
            orderMode: orderMode,
          ),
          AppSpacing.gapVerticalMD,
          _buildTransactionInfoCard(
              context, textTheme, colorScheme, provider, listState, isLocked),
          AppSpacing.gapVerticalMD,
          _buildProductsCard(
              context, textTheme, colorScheme, provider, listState, isLocked),
          AppSpacing.gapVerticalMD,
          if (order['image_payment_url'] != null) ...[
            _buildPaymentProofCard(context, textTheme, colorScheme),
            AppSpacing.gapVerticalMD,
          ],
          if (order['image_delivery_url'] != null) ...[
            _buildDeliveryPhotoCard(context, textTheme, colorScheme),
            AppSpacing.gapVerticalMD,
          ],
          if (canMarkReadyToShip)
            MarkReadyToShipCard(
              isLoading: formState.isMarkingReady,
              onMarkReady: () {
                provider.markReadyToShip().catchError((e) {
                  if (context.mounted) _showError(context, e);
                });
              },
            )
          else if (canSubmitDelivery) ...[
            _buildDeliveryForm(context, provider, textTheme, colorScheme),
            AppSpacing.gapVerticalMD,
            _buildRefundButton(context, provider, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionInfoCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    DeliveryProvider provider,
    DeliveryListState listState,
    bool isLocked,
  ) {
    final canEditAssignment = listState.isAdmin &&
        !(status == DeliveryStatus.delivered &&
            order['payment_status']?.toString() == '2');
    final editIcon = canEditAssignment
        ? _buildEditAssignmentIcon(context, provider)
        : null;

    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ORDER #${order['id']}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    StatusBadge(
                      label: StatusMappers.deliveryLabel(
                          order['delivery_status']),
                      type: StatusMappers.deliveryStatus(
                          order['delivery_status']),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DetailRow(
                    label: 'Toko',
                    value: order['store_name'] ?? '-',
                    trailing: editIcon),
                const SizedBox(height: 8),
                DetailRow(
                    label: 'Metode Bayar',
                    value: order['payment_method'] ?? '-'),
                const SizedBox(height: 8),
                DetailRow(
                    label: 'Status Bayar',
                    value: StatusMappers.paymentLabel(
                        order['payment_status']?.toString()),
                    trailing: editIcon),
                if (order['bank_name'] != null) ...[
                  const SizedBox(height: 8),
                  DetailRow(
                    label: 'Rekening Tujuan',
                    value:
                        '${order['bank_name']} - ${order['bank_account_number']} (${order['bank_account_name']})',
                  ),
                ],
                const SizedBox(height: 8),
                DetailRow(
                    label: 'Jasa Kirim',
                    value: order['delivery_service_name'] ?? '-'),
                const SizedBox(height: 8),
                DetailRow(
                    label: 'Tanggal Kirim',
                    value: order['delivery_date'] ?? '-'),
                if (isLocked) ...[
                  const SizedBox(height: 8),
                  DetailRow(
                      label: 'Penerima',
                      value: order['received_by'] ?? '-'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditAssignmentIcon(
    BuildContext context,
    DeliveryProvider provider,
  ) {
    return IconButton(
      onPressed: () => EditOrderAssignmentSheet.show(
        context,
        order: order,
        provider: provider,
      ),
      icon: const Icon(Icons.edit_rounded, size: 16),
      visualDensity: VisualDensity.compact,
      tooltip: 'Ubah toko & status bayar',
      color: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildProductsCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    DeliveryProvider provider,
    DeliveryListState listState,
    bool isLocked,
  ) {
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rincian Produk',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            if (order['items'] != null &&
                (order['items'] as List).isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (order['items'] as List).length,
                separatorBuilder: (context, index) => Divider(
                    height: 16,
                    color: colorScheme.outlineVariant
                        .withValues(alpha: 0.2)),
                itemBuilder: (context, index) {
                  final item = order['items'][index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${item['quantity']} ${item['product_unit'] ?? 'pcs'}',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item['product_name'] ?? '-',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Tidak ada rincian produk.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            if (listState.isAdmin && !isLocked) ...[
              AppSpacing.gapVerticalMD,
              _buildAdminProductEditSection(context, provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminProductEditSection(
    BuildContext context,
    DeliveryProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => EditOrderItemsSheet.show(
          context,
          order: order,
          provider: provider,
        ),
        icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 18),
        label: const Text('Ubah Rincian Produk'),
      ),
    );
  }

  Widget _buildPaymentProofCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment,
                    color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Bukti Pembayaran',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildNetworkImage(context,
              imageUrl: order['image_payment_url'],
              errorText: 'Gagal memuat bukti pembayaran',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryPhotoCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo,
                    color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Foto Bukti Pengiriman',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildNetworkImage(context,
              imageUrl: order['image_delivery_url'],
              errorText: 'Gagal memuat bukti pengiriman',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkImage(
    BuildContext context, {
    required String? imageUrl,
    required String errorText,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    // Normalisasi URL: backend mungkin mengirim path relatif (mis. hasil
    // decode JSON yang gagal) atau URL absolut. buildUrl menangani keduanya
    // dan menjamin host img.sagansa.id yang benar. Null/empty → placeholder.
    final resolvedUrl = ImageService.buildUrl(imageUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _buildImagePlaceholder(colorScheme, textTheme, errorText, 200);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    child: Image.network(
                      resolvedUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.cumulativeBytesLoaded /
                                (progress.expectedTotalBytes ?? 1),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          color: Colors.black54,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image,
                                  color: Colors.white70, size: 48),
                              const SizedBox(height: 12),
                              Text(errorText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Image.network(
              resolvedUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagePlaceholder(
                    colorScheme, textTheme, errorText, 120);
              },
            ),
            Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.zoom_in,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Ketuk untuk memperbesar gambar',
                    style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String errorText,
    double height,
  ) {
    return Container(
      height: height,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.grey, size: 36),
          const SizedBox(height: 8),
          Text(errorText, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildDeliveryForm(
    BuildContext context,
    DeliveryProvider provider,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final formState = provider.formState;

    return SubmitDeliveryCard(
      selectedStatus: formState.selectedStatus,
      isSubmitting: formState.isSubmitting,
      hasPhotos: provider.imageFiles.isNotEmpty,
      showReturnOption: false,
      receiverField: _buildGoldTextField(
        labelText: 'Nama Penerima (Opsional)',
        controller: provider.receiverController,
        prefixIcon: Icons.person_outline,
        colorScheme: colorScheme,
      ),
      notesField: _buildGoldTextField(
        labelText: 'Alasan Pengembalian (Wajib)',
        controller: provider.notesController,
        prefixIcon: Icons.notes_outlined,
        colorScheme: colorScheme,
      ),
      photoUploader: PhotoUploader(
        photos: provider.imageFiles,
        onChanged: provider.setPhotos,
        layout: PhotoUploaderLayout.grid,
        maxPhotos: 999,
        label: formState.selectedStatus == 6
            ? 'Ambil Foto Bukti Retur'
            : 'Ambil Foto Bukti Pengiriman',
      ),
      onStatusChanged: (status) => provider.setStatus(status),
      onSubmit: () {
        provider.submitDelivery(onSuccess: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Status pengiriman berhasil diperbarui.'),
                backgroundColor: Colors.green.shade600,
              ),
            );
          }
        }).catchError((e) {
          if (context.mounted) _showError(context, e);
        });
      },
    );
  }

  Widget _buildRefundButton(
    BuildContext context,
    DeliveryProvider provider,
    ColorScheme colorScheme,
  ) {
    return RefundButton(
      onRefund: () {
        provider.setStatus(6);
        provider.imageFiles.clear();
        provider.notesController.text = 'Refund oleh storage staff';
        provider.submitDelivery(onSuccess: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Status pengiriman berhasil diperbarui.'),
                backgroundColor: Colors.green.shade600,
              ),
            );
          }
        }).catchError((e) {
          if (context.mounted) _showError(context, e);
        });
      },
    );
  }

  Widget _buildGoldTextField({
    required String labelText,
    required TextEditingController controller,
    required IconData prefixIcon,
    required ColorScheme colorScheme,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle:
            TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(prefixIcon, color: AppColors.info),
      ),
    );
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceAll('Exception: ', ''),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
