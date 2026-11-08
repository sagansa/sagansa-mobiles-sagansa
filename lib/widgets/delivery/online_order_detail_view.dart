import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/enums/delivery_status.dart';
import '../../models/enums/order_mode.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/printer_provider.dart';
import '../../services/image_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/status_mappers.dart';
import '../../widgets/detail/detail_image_view.dart';
import '../../widgets/detail/detail_product_tile.dart';
import '../../widgets/detail/detail_section_card.dart';
import '../../widgets/detail_row.dart';
import '../../widgets/photo_uploader.dart';
import '../../widgets/status_badge.dart';
import '../app_snackbar.dart';
import 'delivery_actions.dart';
import 'delivery_stepper.dart';
import 'edit_order_items_sheet.dart';
import 'sticker_print_button.dart';

class OnlineOrderDetailView extends StatelessWidget {
  final Map<String, dynamic> order;
  final OrderMode orderMode;
  final DeliveryStatus status;

  const OnlineOrderDetailView({
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
    final canMarkReadyToShip = deliveryStatus.canMarkReady;
    final canSubmitDelivery = deliveryStatus.canSubmitDelivery;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeliveryStepper(
            status: status,
            orderMode: orderMode,
            isStickerPrinted: provider.isStickerPrinted(
              int.tryParse(order['id']?.toString() ?? '') ?? 0,
            ),
          ),
          const SizedBox(height: 10),
          _buildTransactionInfoCard(context, textTheme, colorScheme),
          const SizedBox(height: 10),
          _buildRecipientCard(context, textTheme, colorScheme),
          const SizedBox(height: 10),
          _buildLogisticsCard(context, textTheme, colorScheme, provider),
          const SizedBox(height: 10),
          StickerPrintButton(
            order: order,
            isPrinting: formState.isPrintingSticker,
            onPrint: () {
              final printerProvider = context.read<PrinterProvider>();
              provider.printSticker(order, printerProvider);
            },
          ),
          const SizedBox(height: 10),
          _buildProductsCard(context, textTheme, colorScheme, provider, listState),
          if (order['image_payment_url'] != null) ...[
            const SizedBox(height: 10),
            _buildPaymentProofCard(
              context,
              textTheme,
              colorScheme,
              provider,
              formState,
            ),
          ],
          if (order['image_delivery_url'] != null) ...[
            const SizedBox(height: 10),
            _buildDeliveryPhotoCard(context, textTheme, colorScheme),
          ],
          const SizedBox(height: 10),
          if (canMarkReadyToShip)
            MarkReadyToShipCard(
              isLoading: formState.isMarkingReady,
              onMarkReady: () {
                provider.markReadyToShip().then((_) {
                  if (context.mounted) {
                    showSuccessSnackBar(
                      context,
                      'Order berhasil ditandai siap dikirim.',
                    );
                  }
                }).catchError((e) {
                  if (context.mounted) _showError(context, e);
                });
              },
            )
          else if (canSubmitDelivery) ...[
            _buildDeliveryForm(context, provider, textTheme, colorScheme),
            if (deliveryStatus.canRefund) ...[
              const SizedBox(height: 10),
              _buildRefundButton(context, provider, colorScheme),
            ],
          ] else if (deliveryStatus.canRefund)
            _buildRefundButton(context, provider, colorScheme),
          if (listState.isAdmin && deliveryStatus.canCancel) ...[
            const SizedBox(height: 10),
            CancelOrderButton(
              isLoading: formState.isCancelling,
              onCancel: () => _showCancelOrderDialog(context, provider),
            ),
          ],
          if (deliveryStatus == DeliveryStatus.cancelled &&
              (order['notes']?.toString().isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            _buildCancellationReasonCard(context, order, textTheme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionInfoCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final receiptNo = order['receipt_no']?.toString() ?? '-';
    final providerName = order['provider_name']?.toString() ?? '-';
    final storeName = order['store_name']?.toString() ?? '-';
    final orderId = order['id']?.toString() ?? '';

    return DetailSectionCard(
      title: orderId.isNotEmpty ? 'ORDER #$orderId' : 'INFORMASI PESANAN',
      icon: Icons.receipt_long_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (providerName.isNotEmpty && providerName != '-') ...[
            _buildProviderBadge(providerName, colorScheme, textTheme),
            const SizedBox(width: 6),
          ],
          StatusBadge(
            label: StatusMappers.deliveryLabel(order['delivery_status']),
            type: StatusMappers.deliveryStatus(order['delivery_status']),
          ),
        ],
      ),
      itemSpacing: 6,
      children: [
        DetailRow(
          label: 'Nomor Resi',
          value: receiptNo,
          trailing: receiptNo != '-' && receiptNo.isNotEmpty
              ? _buildCopyButton(context, receiptNo, 'Nomor resi')
              : null,
        ),
        DetailRow(
          label: 'Toko Asal',
          value: storeName,
        ),
        if (order['ordered_by_name'] != null)
          DetailRow(
            label: 'Dipesan Oleh',
            value: order['ordered_by_name'].toString(),
          ),
      ],
    );
  }

  Widget _buildProviderBadge(
    String providerName,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 12, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            providerName,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final recipientName =
        order['address_recipient_name'] ?? order['received_by'] ?? '-';
    final recipientPhone = order['address_recipient_telp_no']?.toString() ?? '-';
    final addressName = order['address_name']?.toString() ?? '';
    final fullAddress = [
      if (order['address_detail'] != null &&
          order['address_detail'].toString().trim().isNotEmpty)
        order['address_detail'].toString().trim(),
      if (order['address_subdistrict'] != null &&
          order['address_subdistrict'].toString().trim().isNotEmpty)
        'Kec. ${order['address_subdistrict']}',
      if (order['address_district'] != null &&
          order['address_district'].toString().trim().isNotEmpty)
        order['address_district'].toString().trim(),
      if (order['address_city'] != null &&
          order['address_city'].toString().trim().isNotEmpty)
        order['address_city'].toString().trim(),
      if (order['address_province'] != null &&
          order['address_province'].toString().trim().isNotEmpty)
        order['address_province'].toString().trim(),
    ].join(', ');

    return DetailSectionCard(
      title: 'Penerima & Alamat Kirim',
      icon: Icons.person_pin_circle_outlined,
      itemSpacing: 6,
      children: [
        DetailRow(
          label: 'Nama Penerima',
          value: recipientName.toString(),
        ),
        DetailRow(
          label: 'Nomor Telepon',
          value: recipientPhone,
          trailing: recipientPhone != '-' && recipientPhone.isNotEmpty
              ? _buildCopyButton(context, recipientPhone, 'Nomor telepon')
              : null,
        ),
        if (addressName.isNotEmpty)
          DetailRow(
            label: 'Label Alamat',
            value: addressName,
          ),
        DetailRow(
          label: 'Alamat Kirim',
          value: fullAddress.isEmpty ? '-' : fullAddress,
          trailing: fullAddress.isNotEmpty && fullAddress != '-'
              ? _buildCopyButton(context, fullAddress, 'Alamat lengkap')
              : null,
        ),
      ],
    );
  }

  Widget _buildLogisticsCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    DeliveryProvider provider,
  ) {
    final deliveryServiceName =
        order['delivery_service_name']?.toString() ?? '-';
    final deliveryDate = order['delivery_date']?.toString() ?? '-';

    return DetailSectionCard(
      title: 'Informasi Logistik',
      icon: Icons.local_shipping_outlined,
      itemSpacing: 6,
      children: [
        DetailRow(
          label: 'Jasa Kirim',
          value: deliveryServiceName,
        ),
        DetailRow(
          label: 'Tanggal Kirim',
          value: deliveryDate,
        ),
        DetailRow(
          label: 'Status Cetak Label',
          value: provider.stickerPrintStatusText(order),
        ),
        if (status.isLocked)
          DetailRow(
            label: 'Penerima Lapangan',
            value: order['received_by']?.toString() ?? '-',
          ),
      ],
    );
  }

  Widget _buildProductsCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    DeliveryProvider provider,
    DeliveryListState listState,
  ) {
    final items = order['items'] as List?;
    final hasItems = items != null && items.isNotEmpty;

    return DetailSectionCard(
      title: 'Rincian Produk (${hasItems ? items.length : 0})',
      icon: Icons.inventory_2_outlined,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      children: [
        if (hasItems) ...[
          ...items.map((item) {
            final qty = item['quantity'] is int
                ? item['quantity'] as int
                : int.tryParse('${item['quantity']}') ?? 1;
            return DetailProductTile(
              productName: item['product_name'] ?? '-',
              productUnit: item['product_unit']?.toString(),
              quantity: qty,
              formattedUnitPrice: listState.isAdmin
                  ? provider.formatPrice(item['unit_price'] ?? 0)
                  : null,
              formattedSubtotalPrice: listState.isAdmin
                  ? provider.formatPrice(item['subtotal_price'] ?? 0)
                  : null,
              showPrice: listState.isAdmin,
            );
          }),
          if (listState.isAdmin) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Nilai Order',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    provider.formatPrice(order['total_price']),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Tidak ada rincian produk.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        if (listState.isAdmin && !status.isLocked) ...[
          const SizedBox(height: 10),
          _buildAdminProductEditSection(context, provider),
        ],
      ],
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
        icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 16),
        label: const Text('Ubah Rincian Produk'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildPaymentProofCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    DeliveryProvider provider,
    DeliveryFormState formState,
  ) {
    return DetailSectionCard(
      title: 'Bukti Pembayaran',
      icon: Icons.payments_outlined,
      children: [
        _buildNetworkImage(
          context,
          imageUrl: order['image_payment_url'],
          errorText: 'Gagal memuat bukti pembayaran',
          colorScheme: colorScheme,
          textTheme: textTheme,
          previewTitle: 'Bukti Pembayaran',
        ),
        if (provider.hasPaymentProof(order)) ...[
          const SizedBox(height: 8),
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
              onPressed: formState.isPrintingPaymentProof
                  ? null
                  : () {
                      provider.printPaymentProof(order).catchError((e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$e'.replaceAll('Exception: ', ''),
                              ),
                            ),
                          );
                        }
                      });
                    },
              icon: formState.isPrintingPaymentProof
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined, size: 18),
              label: Text(
                formState.isPrintingPaymentProof
                    ? 'Mencetak...'
                    : 'Cetak Bukti Bayar',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryPhotoCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return DetailSectionCard(
      title: 'Foto Bukti Pengiriman',
      icon: Icons.photo_camera_outlined,
      child: _buildNetworkImage(
        context,
        imageUrl: order['image_delivery_url'],
        errorText: 'Gagal memuat bukti pengiriman',
        colorScheme: colorScheme,
        textTheme: textTheme,
        previewTitle: 'Foto Bukti Pengiriman',
      ),
    );
  }

  Widget _buildNetworkImage(
    BuildContext context, {
    required String? imageUrl,
    required String errorText,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    String? previewTitle,
  }) {
    final resolvedUrl = ImageService.buildUrl(imageUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _buildImagePlaceholder(colorScheme, textTheme, errorText, 140);
    }
    return DetailImageView(
      imageUrl: resolvedUrl,
      height: 180,
      previewTitle: previewTitle,
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

  Widget _buildCopyButton(BuildContext context, String text, String label) {
    return IconButton(
      icon: Icon(
        Icons.copy_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: 'Salin $label',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        showAppSnackBar(
          context,
          '$label disalin ke clipboard',
          background: Colors.grey.shade800,
        );
      },
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
        labelText: 'Nama Penerima (Wajib)',
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
        _showDeliveryConfirmDialog(
          context,
          provider,
          formState.selectedStatus,
        );
      },
    );
  }

  void _showDeliveryConfirmDialog(
    BuildContext context,
    DeliveryProvider provider,
    int selectedStatus,
  ) {
    if (selectedStatus == 3 &&
        provider.receiverController.text.trim().isEmpty) {
      _showError(context, 'Harap isi nama penerima terlebih dahulu.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pengiriman'),
        content: const Text(
            'Apakah Anda yakin ingin mengirim bukti pengiriman ini? '
            'Status pengiriman akan diubah menjadi "Sudah Dikirim" dan tidak dapat diubah lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.submitDelivery(onSuccess: () {
                if (context.mounted) {
                  showAppSnackBar(
                    context,
                    'Status pengiriman berhasil diperbarui.',
                    background: Colors.green.shade600,
                  );
                }
              }).catchError((e) {
                if (context.mounted) _showError(context, e);
              });
            },
            child: const Text('Ya, Kirim'),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundButton(
    BuildContext context,
    DeliveryProvider provider,
    ColorScheme colorScheme,
  ) {
    return RefundButton(
      onRefund: () => _showRefundDialog(context, provider),
    );
  }

  void _showRefundDialog(
      BuildContext context, DeliveryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogColorScheme = Theme.of(ctx).colorScheme;
        final dialogTextTheme = Theme.of(ctx).textTheme;

        return AlertDialog(
          backgroundColor: dialogColorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.assignment_return, color: AppColors.error),
              const SizedBox(width: 10),
              Text(
                'Konfirmasi Refund / Kembalikan',
                style: dialogTextTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: dialogColorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin mengembalikan order ini? '
            'Status pengiriman akan diubah menjadi "Dikembalikan" dan tidak dapat diubah lagi.',
            style: dialogTextTheme.bodyMedium?.copyWith(
              color: dialogColorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: dialogColorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColorScheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                provider.setStatus(6);
                provider.imageFiles.clear();
                provider.notesController.text =
                    'Refund oleh storage staff';
                provider.submitDelivery(onSuccess: () {
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      'Status pengiriman berhasil diperbarui.',
                      background: Colors.green.shade600,
                    );
                  }
                }).catchError((e) {
                  if (context.mounted) _showError(context, e);
                });
              },
              child: const Text('Ya, Kembalikan'),
            ),
          ],
        );
      },
    );
  }

  void _showCancelOrderDialog(
    BuildContext context,
    DeliveryProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => CancelOrderDialog(
        onConfirm: (reason) {
          Navigator.pop(ctx);
          provider.cancelOrder(reason).then((_) {
            if (context.mounted) {
              showAppSnackBar(
                context,
                'Order berhasil dibatalkan.',
                background: Colors.green.shade600,
              );
            }
          }).catchError((e) {
            if (context.mounted) _showError(context, e);
          });
        },
      ),
    );
  }

  Widget _buildCancellationReasonCard(
    BuildContext context,
    Map<String, dynamic> order,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alasan Pembatalan',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order['notes'].toString(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(prefixIcon, color: AppColors.info),
      ),
    );
  }

  void _showError(BuildContext context, Object error) {
    showAppSnackBar(
      context,
      error.toString().replaceAll('Exception: ', ''),
      background: Theme.of(context).colorScheme.error,
    );
  }
}
