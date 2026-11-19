import 'package:flutter/material.dart';

import '../models/sales_order_employee_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/status_mappers.dart';
import 'status_badge.dart';

/// Kartu list untuk penjualan Employee (SalesPage tab Employee).
///
/// Gaya visual disamakan dgn OrderListCard (tab Online/Direct): header judul +
/// badge status, info baris berikon, preview item, padding AppSpacing konsisten.
/// Berbeda dari OrderListCard: tidak ada tombol cetak resi (employee pakai
/// detail page terpisah) dan menampilkan total harga (relevan utk employee).
/// [isAdmin] mengontrol nominal per harga satuan di preview item — pola yang
/// sama dengan tab Online/Direct (user non-admin tidak melihat nominal).
class EmployeeOrderListCard extends StatelessWidget {
  final SalesOrderEmployeeModel order;
  final bool isAdmin;
  final VoidCallback onTap;

  const EmployeeOrderListCard({
    super.key,
    required this.order,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.surface,
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(colorScheme, textTheme),
              Divider(
                  height: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.1)),
              _buildInfoRow(
                Icons.storefront,
                order.storeName ?? 'Customer',
                colorScheme,
                textTheme,
              ),
              AppSpacing.gapVerticalXS,
              _buildInfoRow(
                Icons.person_outline,
                order.orderedByName ?? '-',
                colorScheme,
                textTheme,
              ),
              // Konsumen tujuan pengiriman (alamat pengiriman) — sesuai
              // field "Konsumen" di halaman detail penjualan employee.
              if (order.deliveryAddressName != null &&
                  order.deliveryAddressName!.isNotEmpty) ...[
                AppSpacing.gapVerticalXS,
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  'Dikirim ke: ${order.deliveryAddressName}',
                  colorScheme,
                  textTheme,
                ),
              ],
              if (order.deliveryDate != null) ...[
                AppSpacing.gapVerticalXS,
                _buildInfoRow(
                  Icons.calendar_today,
                  FormatUtils.formatDate(order.deliveryDate!),
                  colorScheme,
                  textTheme,
                ),
              ],
              AppSpacing.gapVerticalXS,
              _buildTotalRow(colorScheme, textTheme),
              if (order.items.isNotEmpty) ...[
                AppSpacing.gapVerticalSM,
                _buildItemsPreview(colorScheme, textTheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Order #${order.id}',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Row(
          children: [
            StatusBadge(
              label: StatusMappers.deliveryLabel(order.deliveryStatus),
              type: StatusMappers.deliveryStatus(order.deliveryStatus),
            ),
            AppSpacing.gapHorizontalXS,
            StatusBadge(
              label: order.paymentStatusLabel,
              type: _paymentStatusType(),
            ),
          ],
        ),
      ],
    );
  }

  StatusType _paymentStatusType() {
    switch (order.paymentStatus) {
      case 2:
        return StatusType.success;
      case 3:
        return StatusType.error;
      case 4:
        return StatusType.warning;
      default:
        return StatusType.neutral;
    }
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.info),
        AppSpacing.gapHorizontalSM,
        Expanded(
          child: Text(
            text,
            style:
                textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          FormatUtils.formatCurrency(order.totalPrice),
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsPreview(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingXS,
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: AppSpacing.borderRadiusSM,
        border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daftar Barang:',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          AppSpacing.gapVerticalXS,
          ...order.items.map((item) {
            // Nominal per harga satuan hanya untuk admin — konsisten dengan
            // tab Online/Direct yang menyembunyikan nominal utk non-admin.
            final priceSuffix = isAdmin
                ? ' × ${FormatUtils.formatCurrency(item.unitPrice)}'
                : '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                '• ${item.productName} (${item.quantity} ${item.productUnit ?? ''})$priceSuffix',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
              ),
            );
          }),
        ],
      ),
    );
  }
}
