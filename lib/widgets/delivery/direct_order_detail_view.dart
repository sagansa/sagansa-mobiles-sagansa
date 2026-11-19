import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums/delivery_status.dart';
import '../../models/enums/order_mode.dart';
import '../../providers/delivery_provider.dart';
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
import '../procurement/purchase_invoice_link_card.dart';
import 'delivery_actions.dart';
import 'delivery_stepper.dart';
import 'edit_delivery_photos_sheet.dart';
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
          ),
          const SizedBox(height: 10),
          _buildTransactionInfoCard(
              context, textTheme, colorScheme, provider, listState, isLocked),
          const SizedBox(height: 10),
          _buildProductsCard(
              context, textTheme, colorScheme, provider, listState, isLocked),
          if (order['image_payment_url'] != null) ...[
            const SizedBox(height: 10),
            _buildPaymentProofCard(context, textTheme, colorScheme),
          ],
          if (_deliveryPhotoUrls().isNotEmpty ||
              listState.canEditDeliveryPhotos) ...[
            const SizedBox(height: 10),
            _buildDeliveryPhotoCard(
                context, textTheme, colorScheme, provider, listState),
          ],
          // Invoice pembelian terkait — tampil pada order valid; tombol link aktif
          // jika memiliki izin (storage-staff atau admin/super_admin).
          if (int.tryParse('${order['id']}') != null) ...[
            const SizedBox(height: 10),
            PurchaseInvoiceLinkCard(
              orderId: int.tryParse('${order['id']}')!,
              canEdit: listState.canManageSalesLink || listState.isAdmin,
            ),
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
            if (status == DeliveryStatus.fix) ...[
              const SizedBox(height: 10),
              _buildRefundButton(context, provider, colorScheme),
            ],
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

    return DetailSectionCard(
      title: 'ORDER #${order['id']}',
      icon: Icons.receipt_long_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            label: StatusMappers.deliveryLabel(order['delivery_status']),
            type: StatusMappers.deliveryStatus(order['delivery_status']),
          ),
          const SizedBox(width: 6),
          StatusBadge(
            label: StatusMappers.paymentLabel(order['payment_status']?.toString()),
            type: StatusMappers.paymentStatus(order['payment_status']?.toString()),
          ),
          if (canEditAssignment) ...[
            const SizedBox(width: 6),
            _buildEditAssignmentIcon(context, provider),
          ],
        ],
      ),
      itemSpacing: 6,
      children: [
        DetailRow(
          label: 'Toko',
          value: order['store_name'] ?? '-',
        ),
        DetailRow(
          label: 'Metode Bayar',
          value: order['payment_method'] ?? '-',
        ),
        DetailRow(
          label: 'Status Bayar',
          value: StatusMappers.paymentLabel(order['payment_status']?.toString()),
        ),
        if (order['bank_name'] != null)
          DetailRow(
            label: 'Rekening Tujuan',
            value:
                '${order['bank_name']} - ${order['bank_account_number']} (${order['bank_account_name']})',
          ),
        DetailRow(
          label: 'Jasa Kirim',
          value: order['delivery_service_name'] ?? '-',
        ),
        DetailRow(
          label: 'Tanggal Kirim',
          value: order['delivery_date'] ?? '-',
        ),
        if (isLocked)
          DetailRow(
            label: 'Penerima',
            value: order['received_by'] ?? '-',
          ),
      ],
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
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
    final items = order['items'] as List?;
    final hasItems = items != null && items.isNotEmpty;

    return DetailSectionCard(
      title: 'Rincian Produk (${hasItems ? items.length : 0})',
      icon: Icons.inventory_2_outlined,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      trailing: (listState.isAdmin && !isLocked)
          ? _buildEditItemsIcon(context, provider)
          : null,
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
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Tidak ada rincian produk.',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        // Ringkasan nilai TIDAK bergantung pada hasItems — order tanpa
        // detail (data lama) tetap menampilkan ongkir & total untuk admin.
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
            child: Column(
              children: [
                // Ongkos kirim ikut dirangkum total — tampil hanya bila
                // server mengirim field-nya.
                if (order['shipping_cost'] != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ongkos Kirim',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        provider.formatPrice(order['shipping_cost']),
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
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
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditItemsIcon(
    BuildContext context,
    DeliveryProvider provider,
  ) {
    return IconButton(
      onPressed: () => EditOrderItemsSheet.show(
        context,
        order: order,
        provider: provider,
      ),
      icon: const Icon(Icons.edit_rounded, size: 16),
      visualDensity: VisualDensity.compact,
      tooltip: 'Ubah rincian produk',
      color: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildPaymentProofCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return DetailSectionCard(
      title: 'Bukti Pembayaran',
      icon: Icons.payments_outlined,
      child: _buildNetworkImage(
        context,
        imageUrl: order['image_payment_url'],
        errorText: 'Gagal memuat bukti pembayaran',
        colorScheme: colorScheme,
        textTheme: textTheme,
        previewTitle: 'Bukti Pembayaran',
      ),
    );
  }

  /// Daftar URL foto bukti pengiriman dari `image_delivery_urls` (plural,
  /// multi-upload) dengan fallback ke `image_delivery_url` (singular,
  /// respons backend lama).
  List<String> _deliveryPhotoUrls() {
    final urls = order['image_delivery_urls'];
    if (urls is List && urls.isNotEmpty) {
      return urls
          .map((u) => u?.toString() ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
    }
    final single = order['image_delivery_url']?.toString();
    return (single == null || single.isEmpty) ? [] : [single];
  }

  Widget _buildDeliveryPhotoCard(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    DeliveryProvider provider,
    DeliveryListState listState,
  ) {
    final photoUrls = _deliveryPhotoUrls();
    final resolvedUrls = photoUrls
        .map((u) => ImageService.buildUrl(u))
        .whereType<String>()
        .toList();

    return DetailSectionCard(
      title: photoUrls.length > 1
          ? 'Foto Bukti Pengiriman (${photoUrls.length})'
          : 'Foto Bukti Pengiriman',
      icon: Icons.photo_camera_outlined,
      trailing: listState.canEditDeliveryPhotos
          ? _buildEditDeliveryPhotosIcon(context, provider)
          : null,
      child: resolvedUrls.isEmpty
          ? _buildImagePlaceholder(
              colorScheme, textTheme, 'Belum ada foto bukti pengiriman', 140)
          : resolvedUrls.length == 1
              ? DetailImageView(
                  imageUrl: resolvedUrls.first,
                  aspectRatio: 16 / 9,
                  previewTitle: 'Foto Bukti Pengiriman',
                )
              : SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: resolvedUrls.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    // Lebar tetap: DetailImageView memakai width infinity
                    // yang tidak valid di main-axis horizontal list.
                    itemBuilder: (context, index) => SizedBox(
                      width: 280,
                      child: DetailImageView(
                        imageUrl: resolvedUrls[index],
                        height: 200,
                        previewTitle:
                            'Foto Bukti Pengiriman (${index + 1}/${resolvedUrls.length})',
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEditDeliveryPhotosIcon(
    BuildContext context,
    DeliveryProvider provider,
  ) {
    return IconButton(
      onPressed: () => EditDeliveryPhotosSheet.show(
        context,
        order: order,
        provider: provider,
      ),
      icon: const Icon(Icons.edit_rounded, size: 16),
      visualDensity: VisualDensity.compact,
      tooltip: 'Ganti foto bukti pengiriman',
      color: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
    // Normalisasi URL: backend mungkin mengirim path relatif atau URL absolut.
    final resolvedUrl = ImageService.buildUrl(imageUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _buildImagePlaceholder(colorScheme, textTheme, errorText, 140);
    }
    return DetailImageView(
      imageUrl: resolvedUrl,
      aspectRatio: 16 / 9,
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
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.grey, size: 32),
          const SizedBox(height: 6),
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
            showAppSnackBar(
              context,
              'Status pengiriman berhasil diperbarui.',
              background: Colors.green.shade600,
            );
          }
        }).catchError((e) {
          provider.setStatus(3);
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle:
            TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(prefixIcon, color: AppColors.info, size: 20),
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
