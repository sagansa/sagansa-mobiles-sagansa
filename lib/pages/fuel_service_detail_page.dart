import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/image_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/detail/detail_image_view.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail_row.dart';
import '../widgets/glass_app_bar.dart';

class FuelServiceDetailPage extends StatelessWidget {
  final Map<String, dynamic> service;

  const FuelServiceDetailPage({
    super.key,
    required this.service,
  });

  bool get isFuel => service['fuel_service'] == 1;
  bool get isPaid => service['status'] == 2;
  double get amount => double.tryParse(service['amount']?.toString() ?? '0') ?? 0;
  double get km => double.tryParse(service['km']?.toString() ?? '0') ?? 0;
  double get liter => double.tryParse(service['liter']?.toString() ?? '0') ?? 0;

  List<dynamic> get serviceDetails {
    final raw = service['service_details'];
    if (raw is List) return raw;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final typeLabel = isFuel ? 'Bensin (Fuel)' : 'Servis Kendaraan';
    final typeIcon = isFuel ? Icons.local_gas_station_outlined : Icons.build_circle_outlined;
    final typeColor = isFuel ? AppColors.success : AppColors.warning;

    final vehicle = service['vehicle'] as Map<String, dynamic>?;
    final vehicleNo = vehicle?['no_register'] ?? service['vehicle_no'] ?? '-';
    final vehicleName = vehicle?['name'] ?? vehicle?['merk'] ?? 'Kendaraan Operasional';

    final supplier = service['supplier'] as Map<String, dynamic>?;
    final supplierName = supplier?['name'] ?? service['supplier_name'];
    final supplierBank = supplier?['bank'] as Map<String, dynamic>?;
    final bankName = supplierBank?['name'] ?? supplier?['bank_name'];
    final bankAccountNo = supplier?['bank_account_no']?.toString();
    final bankAccountName = supplier?['bank_account_name']?.toString();

    final creator = service['created_by'] as Map<String, dynamic>?;
    final creatorName = creator?['name'] ?? service['created_by_name'] ?? '-';

    final paymentTypeId = service['payment_type_id'];
    final paymentTypeName = paymentTypeId == 1
        ? 'Transfer'
        : paymentTypeId == 2
            ? 'Tunai'
            : (service['payment_type']?['name'] ?? 'Tunai');

    final store = service['store'] as Map<String, dynamic>?;
    final storeName = store?['name'] ?? service['store_name'];

    final imageUrl = ImageService.buildUrl(service['image']?.toString());
    final rawNotes = service['notes']?.toString();
    final cleanNotes = rawNotes != null ? FormatUtils.stripHtml(rawNotes).trim() : '';

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(isFuel ? 'Detail Bensin' : 'Detail Servis'),
        actions: [
          BarButtonCluster(actions: [
            if (imageUrl != null)
              BarButtonSpec(
                icon: Icons.share_outlined,
                tooltip: 'Bagikan Bukti',
                onTap: () {
                  final shareText = StringBuffer()
                    ..writeln('[${typeLabel.toUpperCase()}]')
                    ..writeln('Nominal: ${FormatUtils.formatCurrency(amount)}')
                    ..writeln('Kendaraan: $vehicleNo ($vehicleName)')
                    ..writeln('Tanggal: ${service['date'] ?? '-'}')
                    ..writeln('Oleh: $creatorName')
                    ..writeln('Status: ${isPaid ? 'Lunas' : 'Pending'}');
                  if (imageUrl.isNotEmpty) {
                    shareText.writeln('Foto Bukti: $imageUrl');
                  }
                  SharePlus.instance.share(
                    ShareParams(text: shareText.toString()),
                  );
                },
              ),
          ]),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding
            .copyWith(top: AppBarInsets.top(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card 1: Informasi Utama Transaksi
            DetailSectionCard(
              icon: typeIcon,
              title: typeLabel,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPaid ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusSM,
                  border: Border.all(
                    color: (isPaid ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  isPaid ? 'Lunas' : 'Pending',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isPaid ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              children: [
                if (storeName != null)
                  DetailRow(
                    label: 'Toko / Cabang',
                    value: storeName,
                    isBold: true,
                  ),
                DetailRow(
                  label: 'Tanggal',
                  value: service['date']?.toString() ?? '-',
                ),
                DetailRow(
                  label: 'Dibuat Oleh',
                  value: creatorName,
                ),
                DetailRow(
                  label: 'Metode Pembayaran',
                  value: paymentTypeName,
                ),
                AppSpacing.gapVerticalSM,
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.08),
                    borderRadius: AppSpacing.borderRadiusMD,
                    border: Border.all(
                      color: typeColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL BIAYA',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        FormatUtils.formatCurrency(amount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapVerticalMD,

            // Card 2: Informasi Kendaraan & Odometer
            DetailSectionCard(
              icon: Icons.directions_car_outlined,
              title: 'Kendaraan & Odometer',
              children: [
                DetailRow(
                  label: 'No. Polisi',
                  value: vehicleNo,
                  isBold: true,
                ),
                if (vehicleName.isNotEmpty && vehicleName != 'Kendaraan Operasional')
                  DetailRow(
                    label: 'Nama / Model',
                    value: vehicleName,
                  ),
                DetailRow(
                  label: 'KM Terakhir (Odometer)',
                  value: '${FormatUtils.formatNumber(km)} KM',
                  isBold: true,
                ),
                if (isFuel && liter > 0)
                  DetailRow(
                    label: 'Volume Pengisian',
                    value: '${liter.toStringAsFixed(1)} Liter',
                  ),
              ],
            ),
            AppSpacing.gapVerticalMD,

            // Card 3: Rincian Servis (khusus jika ada breakdown item servis)
            if (!isFuel && serviceDetails.isNotEmpty) ...[
              DetailSectionCard(
                icon: Icons.format_list_bulleted_outlined,
                title: 'Rincian Perbaikan / Sparepart',
                trailing: Text(
                  '${serviceDetails.length} Item',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: serviceDetails.length,
                    separatorBuilder: (context, index) => AppSpacing.gapVerticalSM,
                    itemBuilder: (context, index) {
                      final item = serviceDetails[index] as Map<String, dynamic>;
                      final itemName = item['name']?.toString() ?? 'Item ${index + 1}';
                      final itemPrice = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: AppSpacing.borderRadiusMD,
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                itemName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              FormatUtils.formatCurrency(itemPrice),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              AppSpacing.gapVerticalMD,
            ],

            // Card 4: Supplier / Bengkel / Rekening
            if (supplierName != null || bankAccountNo != null) ...[
              DetailSectionCard(
                icon: Icons.storefront_outlined,
                title: 'Bengkel / SPBU / Supplier',
                children: [
                  if (supplierName != null)
                    DetailRow(
                      label: 'Nama Penyedia',
                      value: supplierName,
                      isBold: true,
                    ),
                  if (bankName != null)
                    DetailRow(
                      label: 'Bank Tujuan',
                      value: bankName,
                    ),
                  if (bankAccountNo != null && bankAccountNo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            flex: 2,
                            child: Text(
                              'Nomor Rekening',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bankAccountNo,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: bankAccountNo));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Nomor rekening disalin')),
                                  );
                                },
                                borderRadius: AppSpacing.borderRadiusSM,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.copy_rounded,
                                      size: 15, color: colorScheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (bankAccountName != null && bankAccountName.isNotEmpty)
                    DetailRow(
                      label: 'Atas Nama',
                      value: bankAccountName,
                    ),
                ],
              ),
              AppSpacing.gapVerticalMD,
            ],

            // Card 5: Catatan
            if (cleanNotes.isNotEmpty) ...[
              DetailSectionCard(
                icon: Icons.notes_outlined,
                title: 'Catatan',
                children: [
                  Text(
                    cleanNotes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVerticalMD,
            ],

            // Card 6: Foto Bukti / Struk
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              DetailSectionCard(
                icon: Icons.image_outlined,
                title: 'Foto Bukti / Struk',
                child: DetailImageView(
                  imageUrl: imageUrl,
                  previewTitle: 'Foto Bukti',
                ),
              ),
              AppSpacing.gapVerticalMD,
            ],
          ],
        ),
      ),
    );
  }
}
