import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart' show CameraDevice, ImageSource;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/shift_store_model.dart';
import '../models/store_model.dart';
import '../pages/closing_store_page.dart';
import '../pages/home_page.dart';
import '../pages/hygiene_page.dart';
import '../pages/readiness_page.dart';
import '../providers/presence_provider.dart';
import '../services/hygiene_service.dart';
import '../services/image_service.dart';
import '../theme/app_button_style.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/snackbar_utils.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/bar_button_cluster.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';

class PresencePage extends StatefulWidget {
  final bool isCheckIn;

  const PresencePage({super.key, required this.isCheckIn});

  @override
  PresencePageState createState() => PresencePageState();
}

class PresencePageState extends State<PresencePage> {
  List<Store> stores = [];
  List<ShiftStore> shiftStores = [];
  Store? selectedStore;
  ShiftStore? selectedShiftStore;
  bool isLoading = false;
  Position? currentPosition;
  MapController mapController = MapController();
  bool isLoadingLocation = false;
  bool isLocationValid = false;
  bool isTimeValid = true;

  File? _imageFile;

  /// Toko yang sudah memiliki laporan kebersihan hari ini (boleh presensi).
  /// Cukup satu laporan per toko per hari, boleh oleh user lain.
  final Set<int> _storeHygieneDone = {};

  final TextEditingController _salaryAmountController =
      TextEditingController(text: '50.000');
  int? _selectedPaymentTypeId = 2; // Default Tunai (2)

  @override
  void initState() {
    super.initState();
    _loadData();
    _validateCheckoutTime();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final provider = context.read<PresenceProvider>();
      await provider.loadInitialData();
      setState(() {
        stores = provider.stores;
        shiftStores = provider.shiftStores;
      });
      _getCurrentLocation();
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(context, e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isLoadingLocation = true);
    try {
      final provider = context.read<PresenceProvider>();
      await provider.getCurrentLocation();
      final position = provider.currentLocation;
      if (position == null) throw Exception('Gagal mendapatkan lokasi');
      Store? nearestStore;
      double shortestDistance = double.infinity;

      setState(() {
        currentPosition = position;

        for (var store in stores) {
          final double distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            store.latitude,
            store.longitude,
          );

          if (distance < shortestDistance) {
            shortestDistance = distance;
            nearestStore = store;
          }
        }

        final picked = nearestStore;
        if (picked != null) {
          selectedStore = picked;
          isLocationValid = shortestDistance <= picked.radius;

          if (!widget.isCheckIn) {
            _salaryAmountController.text = FormatUtils.formatAmount(
                double.tryParse(picked.dailySalaryAmount) ?? 0);
          }

          final String message = isLocationValid
              ? 'Anda berada di area ${picked.nickname} (${shortestDistance.toStringAsFixed(2)} meter)'
              : 'Anda berada di luar area ${picked.nickname}. Jarak: ${shortestDistance.toStringAsFixed(2)} meter';

          SnackbarUtils.show(
            context,
            message,
            backgroundColor:
                isLocationValid ? Colors.green.shade600 : Colors.red.shade800,
          );
        }
      });

      // Cek status kebersihan toko terdekat (hanya untuk check-in), sama
      // seperti saat user memilih toko manual. Tanpa ini, store tidak masuk
      // _storeHygieneDone dan tombol clock-in tidak aktif meski semua syarat
      // lain sudah terpenuhi (lihat kondisi isButtonEnabled baris ~327).
      // Dipanggil di luar setState karena method async & dapat mem-push halaman.
      if (widget.isCheckIn && nearestStore != null) {
        await _ensureStoreHygiene(nearestStore!);
      }

      mapController.move(
        LatLng(position.latitude, position.longitude),
        18.0,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(context, e.toString());
    } finally {
      setState(() => isLoadingLocation = false);
    }
  }

  void _validateCheckoutTime() {
    // Validasi batas waktu checkout sepenuhnya dipegang backend (PresenceController
    // mengembalikan error 400 + checkout_deadline bila lewat). Dahulu ada gate
    // client-side dgn jam hard-coded 02:00 yang bug (`currentHour <= 23 || ...`
    // selalu true) dan inkonsisten dgn aturan shift malam (deadline 06:00 hari
    // berikutnya). isTimeValid tetap true agar tombol selalu aktif; penolakan
    // final ditangani backend saat submit.
    isTimeValid = true;
  }

  Future<void> _validateAndSubmitPresence() async {
    if (_imageFile == null) {
      SnackbarUtils.error(context, 'Harap ambil foto selfie terlebih dahulu');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Validasi kebersihan: clock-in wajib lapor kebersihan dulu.
      // Status sudah dicek saat memilih toko (_ensureStoreHygiene), cukup
      // verifikasi di sini bahwa toko terpilih sudah tercatat melakukan
      // kebersihan hari ini. Backend tetap menjadi penjaga final.
      if (widget.isCheckIn && !_storeHygieneDone.contains(selectedStore!.id)) {
        if (!mounted) return;
        setState(() => isLoading = false);
        SnackbarUtils.warning(
          context,
          'Laporan kebersihan untuk ${selectedStore!.nickname} belum diisi. '
          'Pilih toko tersebut untuk mengisi laporan terlebih dahulu.',
        );
        return;
      }

      final provider = context.read<PresenceProvider>();
      final responseData = await provider.submitPresence(
        isCheckIn: widget.isCheckIn,
        currentPosition: currentPosition!,
        selectedStore: selectedStore!,
        selectedShiftStore: selectedShiftStore,
        imageFile: _imageFile!,
        dailySalaryAmount: widget.isCheckIn
            ? null
            : parseAmountInt(_salaryAmountController.text).toString(),
        dailySalaryPaymentTypeId:
            widget.isCheckIn ? null : _selectedPaymentTypeId.toString(),
      );

      if (!mounted) return;

      if (responseData['status'] == 'success') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      } else {
        final errorCode = responseData['error_code'];
        final message = responseData['message'] ?? 'Gagal melakukan presensi';

        if (errorCode == 'READINESS_REQUIRED') {
          SnackbarUtils.warning(context, message);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReadinessPage()),
          );
        } else if (errorCode == 'HYGIENE_REQUIRED') {
          SnackbarUtils.warning(context, message);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HygienePage()),
          );
        } else if (errorCode == 'CLOSING_STORE_REQUIRED') {
          // Invoice tunai buatan user belum masuk Tutup Shift — buka
          // langsung form Tutup Shift agar bisa diselesaikan.
          SnackbarUtils.warning(context, message);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ClosingStorePage(
                      autoStartDraft: true,
                    )),
          );
        } else {
          SnackbarUtils.error(context, message);
        }
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(context, e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Pastikan toko sudah memiliki laporan kebersihan hari ini.
  /// Jika belum, arahkan ke form kebersihan untuk toko tersebut dan tunggu
  /// hingga user mengisi (atau membatalkan). Hasilnya disimpan di
  /// [_storeHygieneDone] agar toko dianggap "aktif" untuk presensi.
  Future<void> _ensureStoreHygiene(Store store) async {
    if (_storeHygieneDone.contains(store.id)) return;

    bool hasHygiene;
    try {
      hasHygiene = await HygieneService().checkTodayStatus(storeId: store.id);
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(context, 'Gagal mengecek laporan kebersihan: $e');
      return;
    }

    if (!mounted) return;

    if (hasHygiene) {
      setState(() => _storeHygieneDone.add(store.id));
      SnackbarUtils.success(
        context,
        'Toko ${store.nickname} sudah memiliki laporan kebersihan hari ini.',
      );
      return;
    }

    // Toko belum lapor kebersihan -> langsung buka form untuk toko tersebut.
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => HygienePage(initialStoreId: store.id),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() => _storeHygieneDone.add(store.id));
      SnackbarUtils.success(
        context,
        'Laporan kebersihan untuk ${store.nickname} berhasil dikirim.',
      );
    } else {
      // User membatalkan -> batalkan pemilihan toko agar tidak bisa presensi.
      setState(() => selectedStore = null);
      SnackbarUtils.warning(
        context,
        'Laporan kebersihan untuk ${store.nickname} belum diisi. '
        'Pilih toko lain atau isi laporan terlebih dahulu.',
      );
    }
  }

  void _updateMapView() {
    if (selectedStore != null && currentPosition != null) {
      final centerLat =
          (currentPosition!.latitude + selectedStore!.latitude) / 2;
      final centerLng =
          (currentPosition!.longitude + selectedStore!.longitude) / 2;

      final distance = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        selectedStore!.latitude,
        selectedStore!.longitude,
      );

      double zoom = 18.0;
      if (distance > 1000) {
        zoom = 14.0;
      } else if (distance > 500) {
        zoom = 15.0;
      } else if (distance > 200) {
        zoom = 16.0;
      } else if (distance > 100) {
        zoom = 17.0;
      }

      mapController.move(LatLng(centerLat, centerLng), zoom);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await ImageService.pickAndResizeImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo != null && mounted) {
        setState(() {
          _imageFile = photo;
        });
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(context, 'Gagal mengambil foto: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Checkout memakai toko terdekat dari GPS tanpa batasan radius (user tetap
    // bisa check-out meski sedang di luar radius). Check-in tetap divalidasi
    // radius agar tidak bisa presensi masuk dari jarak jauh.
    bool isButtonEnabled =
        selectedStore != null && currentPosition != null && _imageFile != null;

    if (widget.isCheckIn) {
      isButtonEnabled = isButtonEnabled &&
          selectedShiftStore != null &&
          isLocationValid &&
          _storeHygieneDone.contains(selectedStore!.id);
    } else {
      isButtonEnabled = isButtonEnabled && isTimeValid;
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(widget.isCheckIn ? 'Check In' : 'Check Out'),
        actions: [
          BarButtonCluster(actions: [
            BarButtonSpec(
              icon: Icons.my_location,
              tooltip: 'Lokasi saya',
              onTap: _getCurrentLocation,
            ),
          ]),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: Builder(
                builder: (bodyContext) => SingleChildScrollView(
                  padding: AppSpacing.paddingMD
                      .copyWith(top: AppBarInsets.top(bodyContext)),
                  child: Column(
                    children: [
                      Card(
                        elevation: 0,
                        color: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.borderRadiusLG,
                          side: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: AppSpacing.paddingMD,
                          child: Column(
                            children: [
                              if (_imageFile != null) ...[
                                ClipRRect(
                                  borderRadius: AppSpacing.borderRadiusSM,
                                  child: Image.file(
                                    _imageFile!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                AppSpacing.gapVerticalSM,
                              ],
                              ElevatedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt),
                                label: Text(_imageFile == null
                                    ? 'Ambil Foto Selfie'
                                    : 'Ambil Ulang Foto'),
                                style: AppButtonStyle.elevated(
                                  minimumSize: const Size(double.infinity, 45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.gapVerticalMD,
                      if (widget.isCheckIn) ...[
                        ModernDropdown<Store>(
                          value: selectedStore,
                          hint: 'Pilih Toko',
                          items: stores,
                          getLabel: (store) =>
                              _storeHygieneDone.contains(store.id)
                                  ? '${store.nickname}  •  sudah kebersihan'
                                  : store.nickname,
                          onChanged: (value) async {
                            setState(() {
                              selectedStore = value;
                              isLocationValid = false;
                            });

                            if (value != null && currentPosition != null) {
                              final double distance =
                                  Geolocator.distanceBetween(
                                currentPosition!.latitude,
                                currentPosition!.longitude,
                                value.latitude,
                                value.longitude,
                              );

                              setState(() {
                                isLocationValid = distance <= value.radius;
                              });

                              if (!isLocationValid) {
                                SnackbarUtils.error(
                                  context,
                                  'Anda berada di luar area toko. Jarak: ${distance.toStringAsFixed(2)} meter',
                                );
                              }
                            }

                            // Check-in: toko wajib sudah lapor kebersihan hari ini.
                            // Cukup satu laporan per toko (boleh oleh user lain).
                            if (widget.isCheckIn && value != null) {
                              await _ensureStoreHygiene(value);
                            }

                            _updateMapView();
                          },
                        ),
                        AppSpacing.gapVerticalMD,
                        ModernDropdown<ShiftStore>(
                          value: selectedShiftStore,
                          hint: 'Pilih Shift',
                          items: shiftStores,
                          getLabel: (shift) => shift.name,
                          onChanged: (value) {
                            setState(() {
                              selectedShiftStore = value;
                            });
                          },
                        ),
                        AppSpacing.gapVerticalMD,
                      ],
                      SizedBox(
                        height: 300,
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: mapController,
                              options: MapOptions(
                                initialCenter: LatLng(
                                  currentPosition?.latitude ?? -6.200000,
                                  currentPosition?.longitude ?? 106.816666,
                                ),
                                initialZoom: 15.0,
                              ),
                              children: [
                                // CartoDB Voyager: tile berbasis data OSM dengan
                                // gaya bersih yang mirip Google Maps (jalan oranye,
                                // latar terang, label rapi). Gratis tanpa API key.
                                TileLayer(
                                  urlTemplate:
                                      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                  userAgentPackageName: 'id.sagansa.presence',
                                ),
                                if (selectedStore != null)
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: LatLng(selectedStore!.latitude,
                                            selectedStore!.longitude),
                                        radius:
                                            selectedStore!.radius.toDouble(),
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.2),
                                        borderColor: colorScheme.primary,
                                        borderStrokeWidth: 2,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: [
                                    if (currentPosition != null)
                                      Marker(
                                        point: LatLng(currentPosition!.latitude,
                                            currentPosition!.longitude),
                                        child: Icon(Icons.person_pin_circle,
                                            color: colorScheme.error,
                                            size: 40.0),
                                      ),
                                    if (selectedStore != null)
                                      Marker(
                                        point: LatLng(selectedStore!.latitude,
                                            selectedStore!.longitude),
                                        child: Icon(Icons.store,
                                            color: colorScheme.primary,
                                            size: 40.0),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            if (isLoadingLocation)
                              Center(
                                child: Container(
                                  padding: AppSpacing.paddingMD,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: AppSpacing.borderRadiusSM,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      AppSpacing.gapVerticalSM,
                                      const Text('Mendapatkan lokasi...'),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      AppSpacing.gapVerticalMD,
                      if (selectedStore != null)
                        Card(
                          elevation: 0,
                          color: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppSpacing.borderRadiusLG,
                            side: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: AppSpacing.cardPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lokasi Toko:',
                                  style: textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                AppSpacing.gapVerticalSM,
                                Row(
                                  children: [
                                    Icon(Icons.store, color: AppColors.info),
                                    AppSpacing.gapHorizontalSM,
                                    Expanded(
                                      child: Text(
                                        selectedStore!.nickname,
                                        style: textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                if (currentPosition != null) ...[
                                  AppSpacing.gapVerticalSM,
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: AppColors.info),
                                      AppSpacing.gapHorizontalSM,
                                      Text(
                                        'Jarak: ${Geolocator.distanceBetween(
                                          currentPosition!.latitude,
                                          currentPosition!.longitude,
                                          selectedStore!.latitude,
                                          selectedStore!.longitude,
                                        ).toStringAsFixed(2)} meter',
                                        style: textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                  AppSpacing.gapVerticalSM,
                                  Row(
                                    children: [
                                      Icon(
                                        isLocationValid
                                            ? Icons.check_circle
                                            : Icons.error,
                                        color: isLocationValid
                                            ? AppColors.success
                                            : colorScheme.error,
                                      ),
                                      AppSpacing.gapHorizontalSM,
                                      Text(
                                        isLocationValid
                                            ? 'Anda berada di area toko'
                                            : 'Anda di luar area toko',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: isLocationValid
                                              ? AppColors.success
                                              : colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.isCheckIn) ...[
              AppSpacing.gapVerticalMD,
              Card(
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusLG,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Salary',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: AppSpacing.sectionGap),
                      TextField(
                        controller: _salaryAmountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: rupiahInputFormatters,
                        decoration: const InputDecoration(
                          labelText: 'Amount (Rp)',
                          prefixText: 'Rp ',
                        ),
                      ),
                      SizedBox(height: AppSpacing.sectionGap),
                      ModernDropdown<int>(
                        value: _selectedPaymentTypeId,
                        labelText: 'Payment Type',
                        hint: 'Pilih tipe pembayaran...',
                        items: const [1, 2],
                        getLabel: (v) => v == 1 ? 'Transfer' : 'Tunai',
                        onChanged: (value) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _selectedPaymentTypeId = value;
                              });
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                    spreadRadius: 0,
                    blurRadius: 12,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: AppSpacing.paddingMD,
              child: ModernButton(
                text: widget.isCheckIn ? 'Check In' : 'Check Out',
                onPressed: isButtonEnabled ? _validateAndSubmitPresence : null,
                isLoading: isLoading,
                backgroundColor: widget.isCheckIn ? null : Colors.redAccent,
                foregroundColor: widget.isCheckIn ? null : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
