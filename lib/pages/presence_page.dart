import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/store_model.dart';
import '../models/shift_store_model.dart';
import '../pages/home_page.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../controllers/presence_controller.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PresencePage extends StatefulWidget {
  final bool isCheckIn;

  const PresencePage({super.key, required this.isCheckIn});

  @override
  _PresencePageState createState() => _PresencePageState();
}

class _PresencePageState extends State<PresencePage> {
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
  late PresenceController _presenceController;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _salaryAmountController = TextEditingController(text: '50000');
  int? _selectedPaymentTypeId = 2; // Default Tunai (2)

  @override
  void initState() {
    super.initState();
    _presenceController = PresenceController(context);
    _loadData();
    _validateCheckoutTime();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final data = await _presenceController.loadInitialData();
      setState(() {
        stores = data['stores'];
        shiftStores = data['shiftStores'];
      });
      _getCurrentLocation();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isLoadingLocation = true);
    try {
      final position = await _presenceController.getCurrentLocation();
      setState(() {
        currentPosition = position;

        // Cari toko terdekat
        Store? nearestStore;
        double shortestDistance = double.infinity;

        for (var store in stores) {
          double distance = Geolocator.distanceBetween(
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

        // Update selected store dan validasi lokasi
        if (nearestStore != null) {
          selectedStore = nearestStore;
          isLocationValid = shortestDistance <= nearestStore.radius;
          
          if (!widget.isCheckIn) {
            _salaryAmountController.text = nearestStore.dailySalaryAmount;
          }

          // Tampilkan snackbar dengan informasi jarak
          String message = isLocationValid
              ? 'Anda berada di area ${nearestStore.nickname} (${shortestDistance.toStringAsFixed(2)} meter)'
              : 'Anda berada di luar area ${nearestStore.nickname}. Jarak: ${shortestDistance.toStringAsFixed(2)} meter';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: isLocationValid ? Colors.green : Colors.red,
            ),
          );
        }
      });

      // Pindahkan map ke posisi saat ini
      mapController.move(
        LatLng(position.latitude, position.longitude),
        18.0,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isLoadingLocation = false);
    }
  }

  void _validateCheckoutTime() {
    if (!widget.isCheckIn) {
      final now = DateTime.now();
      final currentHour = now.hour;
      setState(() {
        isTimeValid = currentHour <= 23 || currentHour <= 2;
      });

      if (!isTimeValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Waktu checkout hanya diperbolehkan sampai jam 02:00'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _validateAndSubmitPresence() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap ambil foto selfie terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {


      // Modifikasi pemanggilan submitPresence untuk mengirim foto
      await _presenceController.submitPresence(
        isCheckIn: widget.isCheckIn,
        currentPosition: currentPosition!,
        selectedStore: selectedStore!,
        selectedShiftStore: selectedShiftStore,
        imageFile: _imageFile!, // Tambahkan parameter imageFile
        dailySalaryAmount: widget.isCheckIn ? null : _salaryAmountController.text,
        dailySalaryPaymentTypeId: widget.isCheckIn ? null : _selectedPaymentTypeId.toString(),
        onSuccess: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateMapView() {
    if (selectedStore != null && currentPosition != null) {
      // Hitung titik tengah antara user dan store
      final centerLat =
          (currentPosition!.latitude + selectedStore!.latitude) / 2;
      final centerLng =
          (currentPosition!.longitude + selectedStore!.longitude) / 2;

      // Hitung zoom yang sesuai berdasarkan jarak
      final distance = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        selectedStore!.latitude,
        selectedStore!.longitude,
      );

      // Sesuaikan zoom berdasarkan jarak
      double zoom = 18.0;
      if (distance > 1000) {
        zoom = 14.0;
      } else if (distance > 500)
        zoom = 15.0;
      else if (distance > 200)
        zoom = 16.0;
      else if (distance > 100) zoom = 17.0;

      mapController.move(LatLng(centerLat, centerLng), zoom);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front, // Menggunakan kamera depan
        imageQuality: 50, // Kompres kualitas gambar
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isButtonEnabled = selectedStore != null &&
        currentPosition != null &&
        isLocationValid &&
        _imageFile != null;

    if (widget.isCheckIn) {
      isButtonEnabled = isButtonEnabled && selectedShiftStore != null;
    } else {
      isButtonEnabled = isButtonEnabled && isTimeValid;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCheckIn ? 'Check In' : 'Check Out'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              if (_imageFile != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _imageFile!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              ElevatedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt),
                                label: Text(_imageFile == null
                                    ? 'Ambil Foto Selfie'
                                    : 'Ambil Ulang Foto'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.isCheckIn) ...[
                        ModernDropdown<Store>(
                          value: selectedStore,
                          hint: 'Pilih Toko',
                          items: stores,
                          getLabel: (store) => store.nickname,
                          onChanged: (value) async {
                            setState(() {
                              selectedStore = value;
                              isLocationValid = false;
                            });

                            if (value != null && currentPosition != null) {
                              double distance = Geolocator.distanceBetween(
                                currentPosition!.latitude,
                                currentPosition!.longitude,
                                value.latitude,
                                value.longitude,
                              );

                              setState(() {
                                isLocationValid = distance <= value.radius;
                              });

                              if (!isLocationValid) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Anda berada di luar area toko. Jarak: ${distance.toStringAsFixed(2)} meter'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }

                            _updateMapView();
                          },
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
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
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'id.sagansa.presence',
                                ),
                                if (selectedStore != null)
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: LatLng(selectedStore!.latitude,
                                            selectedStore!.longitude),
                                        radius: selectedStore!.radius
                                            .toDouble(), // dalam meter
                                        color: Colors.blue.withValues(alpha: 0.2),
                                        borderColor: Colors.blue,
                                        borderStrokeWidth: 2,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: [
                                    // Marker untuk posisi user
                                    if (currentPosition != null)
                                      Marker(
                                        point: LatLng(currentPosition!.latitude,
                                            currentPosition!.longitude),
                                        child: const Icon(
                                            Icons.person_pin_circle,
                                            color: Colors.red,
                                            size: 40.0),
                                      ),
                                    // Marker untuk store yang dipilih
                                    if (selectedStore != null)
                                      Marker(
                                        point: LatLng(selectedStore!.latitude,
                                            selectedStore!.longitude),
                                        child: const Icon(Icons.store,
                                            color: Colors.blue, size: 40.0),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            if (isLoadingLocation)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 8),
                                      Text('Mendapatkan lokasi...'),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (selectedStore != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lokasi Toko:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.store, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedStore!.nickname,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                                if (currentPosition != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Jarak: ${Geolocator.distanceBetween(
                                          currentPosition!.latitude,
                                          currentPosition!.longitude,
                                          selectedStore!.latitude,
                                          selectedStore!.longitude,
                                        ).toStringAsFixed(2)} meter',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        isLocationValid
                                            ? Icons.check_circle
                                            : Icons.error,
                                        color: isLocationValid
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isLocationValid
                                            ? 'Anda berada di area toko'
                                            : 'Anda di luar area toko',
                                        style: TextStyle(
                                          color: isLocationValid
                                              ? Colors.green
                                              : Colors.red,
                                          fontSize: 15,
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
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Salary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _salaryAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount (Rp)',
                            border: OutlineInputBorder(),
                            prefixText: 'Rp ',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedPaymentTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Payment Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Transfer')),
                            DropdownMenuItem(value: 2, child: Text('Tunai')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentTypeId = value;
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
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: ModernButton(
                  text: widget.isCheckIn ? 'Check In' : 'Check Out',
                  onPressed: isButtonEnabled ? _validateAndSubmitPresence : null,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ),
    );
  }
}
