import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums/order_mode.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/printer_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_bar_insets.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../../widgets/paged_body_view.dart';
import '../app_snackbar.dart';
import 'order_list_card.dart';

class OrderListView extends StatelessWidget {
  final OrderMode orderMode;

  /// Dipanggil saat user menap sebuah baris order. Parent (mis. SalesPage)
  /// bertanggung jawab membuka halaman detail baru (Navigator.push ke
  /// OrderDetailPage). Default tetap memanggil selectOrder untuk backward-compat.
  final void Function(Map<String, dynamic> order)? onOpenDetail;
  final EdgeInsets? padding;

  const OrderListView({
    super.key,
    required this.orderMode,
    this.onOpenDetail,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, _) {
        final listState = provider.listState;
        final formState = provider.formState;

        return PagedBodyView<Map<String, dynamic>>(
          controller: provider.scrollController,
          // delivery_page tidak mengirim padding → beri inset atas agar
          // item pertama tidak tertutup appbar kaca, dan clearance bawah
          // agar item terakhir tidak tertutup floating ModernBottomNav.
          padding: padding ??
              EdgeInsets.only(
                top: AppBarInsets.top(context),
                bottom: ModernBottomNav.clearance(context),
              ),
          isLoading: listState.isLoading,
          error: listState.error,
          items: provider.filteredOrders,
          hasMore: listState.hasMore,
          onRefresh: provider.loadInitialOrders,
          onLoadMore: provider.loadMoreOrders,
          emptyIcon: Icons.local_shipping_outlined,
          emptyTitle: 'Belum Ada Data Pengiriman',
          emptySubtitle: orderMode.isOnline
              ? 'Ketuk ikon pencarian di kanan atas atau scan QR/barcode resi.'
              : 'Belum ada data pengiriman direct.',
          // Header hanya untuk aksi cetak (online). Judul "Daftar Pengiriman"
          // dan search bar sudah pindah ke AppBar agar ritme body ringkas.
          sliverHeader: orderMode.isOnline
              ? SliverToBoxAdapter(
                  child: _buildHeader(context, provider),
                )
              : null,
          itemBuilder: (context, index) {
            final order = provider.filteredOrders[index];
            final orderId = int.tryParse(order['id']?.toString() ?? '') ?? -1;

            return OrderListCard(
              order: order,
              orderMode: orderMode,
              isAdmin: listState.isAdmin,
              isStickerPrinted: provider.isStickerPrinted(orderId),
              isPrintingSticker: formState.isPrintingSticker,
              onTap: () {
                if (onOpenDetail != null) {
                  onOpenDetail!(order);
                } else {
                  provider.selectOrder(order);
                }
              },
              onPrintSticker: () {
                final printerProvider =
                    context.read<PrinterProvider>();
                provider.printSticker(order, printerProvider);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DeliveryProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: _buildPrintAllButton(context, provider, Theme.of(context).colorScheme),
    );
  }

  Widget _buildPrintAllButton(
    BuildContext context,
    DeliveryProvider provider,
    ColorScheme colorScheme,
  ) {
    final listState = provider.listState;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: listState.isPrintingPaymentProof
          ? null
          : () {
              provider.printAllPendingPaymentProofs().catchError((e) {
                if (context.mounted) {
                  showAppSnackBar(
                    context,
                    e.toString().replaceAll('Exception: ', ''),
                    background: colorScheme.error,
                  );
                }
              });
            },
      icon: listState.isPrintingPaymentProof
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: colorScheme.onPrimary,
                strokeWidth: 2,
              ),
            )
          : Icon(Icons.print, color: colorScheme.onPrimary),
      label: Text(
        listState.isPrintingPaymentProof
            ? 'Menyiapkan Bukti Bayar...'
            : 'Cetak Bukti Bayar Belum Dikirim Seluruhnya',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
