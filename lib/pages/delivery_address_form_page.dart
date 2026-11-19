import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/delivery_address_model.dart';
import '../models/supplier_model.dart';
import '../services/delivery_address_service.dart';
import '../services/region_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_bar_insets.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/safe_bottom_bar.dart';

/// Form create/update calon konsumen (DeliveryAddress).
///
/// [address] null → mode create. Tidak null → mode edit.
/// Setelah simpan berhasil, halaman pop dengan [DeliveryAddressModel] yang
/// tersimpan (dipakai sales order form untuk auto-pilih konsumen baru).
class DeliveryAddressFormPage extends StatefulWidget {
  final DeliveryAddressModel? address;
  const DeliveryAddressFormPage({super.key, this.address});

  @override
  State<DeliveryAddressFormPage> createState() =>
      _DeliveryAddressFormPageState();
}

class _DeliveryAddressFormPageState extends State<DeliveryAddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  final DeliveryAddressService _service = DeliveryAddressService();
  final RegionService _regionService = RegionService();

  final _nameController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _telpController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loadingInitial = true;
  bool _saving = false;

  // Wilayah (berjenjang)
  List<ProvinceModel> _provinces = [];
  List<CityModel> _cities = [];
  List<DistrictModel> _districts = [];
  List<SubdistrictModel> _subdistricts = [];
  List<PostalCodeModel> _postalCodes = [];

  ProvinceModel? _province;
  CityModel? _city;
  DistrictModel? _district;
  SubdistrictModel? _subdistrict;
  PostalCodeModel? _postalCode;

  bool _loadingCities = false;
  bool _loadingDistricts = false;
  bool _loadingSubdistricts = false;
  bool _loadingPostalCodes = false;

  // Koordinat (opsional)
  double? _latitude;
  double? _longitude;
  bool _locating = false;

  bool get _isEdit => widget.address != null;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _recipientNameController.dispose();
    _telpController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
    });
    try {
      _provinces = await _regionService.getProvinces();
      if (!mounted) return;

      // Prefill untuk edit mode
      final a = widget.address;
      if (a != null) {
        _nameController.text = a.name;
        _recipientNameController.text = a.recipientName;
        _telpController.text = a.recipientTelpNo;
        _addressController.text = a.address;
        _latitude = a.latitude;
        _longitude = a.longitude;
        await _prefillRegions();
        if (!mounted) return;
      }

      setState(() => _loadingInitial = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingInitial = false);
      SnackbarUtils.error(context, 'Gagal memuat data wilayah: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  /// Muat berjenjang wilayah untuk edit mode (province → ... → postal).
  Future<void> _prefillRegions() async {
    final a = widget.address!;

    if (a.provinceId != null) {
      final p = _provinces.where((x) => x.id == a.provinceId).firstOrNull;
      if (p == null) return;
      _province = p;
      _cities = await _regionService.getCities(p.id);

      if (a.cityId != null) {
        final c = _cities.where((x) => x.id == a.cityId).firstOrNull;
        if (c == null) return;
        _city = c;
        _districts = await _regionService.getDistricts(c.id);

        if (a.districtId != null) {
          final d =
              _districts.where((x) => x.id == a.districtId).firstOrNull;
          if (d == null) return;
          _district = d;
          _subdistricts = await _regionService.getSubdistricts(d.id);

          if (a.subdistrictId != null) {
            final s =
                _subdistricts.where((x) => x.id == a.subdistrictId).firstOrNull;
            if (s == null) return;
            _subdistrict = s;
            _postalCodes = await _regionService.getPostalCodes(s.id);
            _postalCode =
                _postalCodes.where((x) => x.id == a.postalCodeId).firstOrNull;
            // Konsumen lama yang dibuat tanpa kode pos: isi otomatis bila
            // kelurahannya hanya punya satu kode pos.
            _postalCode ??= _postalCodes.length == 1 ? _postalCodes.first : null;
          }
        }
      }
    }
  }

  Future<void> _selectProvince(ProvinceModel? p) async {
    setState(() {
      _province = p;
      _city = null;
      _district = null;
      _subdistrict = null;
      _postalCode = null;
      _cities = [];
      _districts = [];
      _subdistricts = [];
      _postalCodes = [];
    });
    if (p == null) return;
    setState(() => _loadingCities = true);
    try {
      final cities = await _regionService.getCities(p.id);
      if (mounted) {
        setState(() {
          _cities = cities;
          _loadingCities = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _selectCity(CityModel? c) async {
    setState(() {
      _city = c;
      _district = null;
      _subdistrict = null;
      _postalCode = null;
      _districts = [];
      _subdistricts = [];
      _postalCodes = [];
    });
    if (c == null) return;
    setState(() => _loadingDistricts = true);
    try {
      final districts = await _regionService.getDistricts(c.id);
      if (mounted) {
        setState(() {
          _districts = districts;
          _loadingDistricts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _selectDistrict(DistrictModel? d) async {
    setState(() {
      _district = d;
      _subdistrict = null;
      _postalCode = null;
      _subdistricts = [];
      _postalCodes = [];
    });
    if (d == null) return;
    setState(() => _loadingSubdistricts = true);
    try {
      final subdistricts = await _regionService.getSubdistricts(d.id);
      if (mounted) {
        setState(() {
          _subdistricts = subdistricts;
          _loadingSubdistricts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSubdistricts = false);
    }
  }

  Future<void> _selectSubdistrict(SubdistrictModel? s) async {
    setState(() {
      _subdistrict = s;
      _postalCode = null;
      _postalCodes = [];
    });
    if (s == null) return;
    setState(() => _loadingPostalCodes = true);
    try {
      final postalCodes = await _regionService.getPostalCodes(s.id);
      if (mounted) {
        setState(() {
          _postalCodes = postalCodes;
          // Hampir semua kelurahan hanya punya satu kode pos — pilih
          // otomatis agar user tidak perlu memilih manual.
          if (postalCodes.length == 1) _postalCode = postalCodes.first;
          _loadingPostalCodes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPostalCodes = false);
    }
  }

  Future<void> _pickCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          SnackbarUtils.warning(
              context, 'Izin lokasi diperlukan untuk ambil koordinat.');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (e) {
      if (mounted) {
        SnackbarUtils.error(context,
            'Gagal mendapatkan lokasi: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_province == null || _city == null) {
      SnackbarUtils.warning(context, 'Provinsi dan Kota wajib diisi.');
      return;
    }

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'recipient_name': _recipientNameController.text.trim(),
      'recipient_telp_no': _telpController.text.trim(),
      'address': _addressController.text.trim(),
      'province_id': _province!.id,
      'city_id': _city!.id,
      if (_district != null) 'district_id': _district!.id,
      if (_subdistrict != null) 'subdistrict_id': _subdistrict!.id,
      if (_postalCode != null) 'postal_code_id': _postalCode!.id,
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
    };

    setState(() => _saving = true);
    try {
      final saved = _isEdit
          ? await _service.update(widget.address!.id, payload)
          : await _service.create(payload);
      if (!mounted) return;
      SnackbarUtils.success(
          context, _isEdit ? 'Konsumen diperbarui.' : 'Konsumen ditambahkan.');
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.error(
          context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(_isEdit ? 'Edit Konsumen' : 'Konsumen Baru'),
      ),
      body: _loadingInitial
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppBarInsets.top(context),
                  AppSpacing.md,
                  AppSpacing.md + context.systemBottomInset,
                ),
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nama Konsumen',
                    hint: 'Mis. Rumah, Kantor, atau Lain-lain',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  AppSpacing.gapVerticalMD,
                  _buildTextField(
                    controller: _recipientNameController,
                    label: 'Nama Penerima',
                    hint: 'Nama penerima paket',
                    icon: Icons.person_pin_outlined,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  AppSpacing.gapVerticalMD,
                  _buildTextField(
                    controller: _telpController,
                    label: 'No. Telp Penerima',
                    hint: '08xxxxxxxx',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  AppSpacing.gapVerticalMD,
                  _buildTextField(
                    controller: _addressController,
                    label: 'Alamat Lengkap',
                    hint: 'Jalan, nomor, RT/RW, patokan',
                    icon: Icons.home_outlined,
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  AppSpacing.gapVerticalMD,
                  _buildRegionSection(theme),
                  AppSpacing.gapVerticalMD,
                  _buildCoordinateSection(theme),
                  AppSpacing.gapVerticalLG,
                  ModernButton(
                    text: _isEdit ? 'Simpan Perubahan' : 'Simpan',
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
                    icon: Icons.save_outlined,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$label *',
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildRegionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wilayah',
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        _regionDropdown<ProvinceModel>(
          label: 'Provinsi',
          hint: 'Pilih provinsi',
          icon: Icons.flag_outlined,
          value: _province,
          items: _provinces,
          itemLabel: (p) => p.name,
          onChanged: _selectProvince,
          isRequired: true,
        ),
        AppSpacing.gapVerticalSM,
        _regionDropdown<CityModel>(
          label: 'Kota/Kabupaten',
          hint: _province == null ? 'Pilih provinsi dulu' : 'Pilih kota',
          icon: Icons.location_city_outlined,
          value: _city,
          items: _cities,
          itemLabel: (c) => c.name,
          onChanged: _province == null ? null : _selectCity,
          isRequired: true,
          isLoading: _loadingCities,
        ),
        AppSpacing.gapVerticalSM,
        _regionDropdown<DistrictModel>(
          label: 'Kecamatan',
          hint: _city == null ? 'Pilih kota dulu' : 'Pilih kecamatan',
          icon: Icons.map_outlined,
          value: _district,
          items: _districts,
          itemLabel: (d) => d.name,
          onChanged: _city == null ? null : _selectDistrict,
          isLoading: _loadingDistricts,
        ),
        AppSpacing.gapVerticalSM,
        _regionDropdown<SubdistrictModel>(
          label: 'Desa/Kelurahan',
          hint: _district == null ? 'Pilih kecamatan dulu' : 'Pilih kelurahan',
          icon: Icons.apartment_outlined,
          value: _subdistrict,
          items: _subdistricts,
          itemLabel: (s) => s.name,
          onChanged: _district == null ? null : _selectSubdistrict,
          isLoading: _loadingSubdistricts,
        ),
        AppSpacing.gapVerticalSM,
        _regionDropdown<PostalCodeModel>(
          label: 'Kode Pos',
          hint: _subdistrict == null
              ? 'Pilih kelurahan dulu'
              : 'Pilih kode pos',
          icon: Icons.markunread_mailbox_outlined,
          value: _postalCode,
          items: _postalCodes,
          itemLabel: (p) => p.postalCode,
          onChanged: _subdistrict == null
              ? null
              : (p) => setState(() => _postalCode = p),
          isLoading: _loadingPostalCodes,
        ),
      ],
    );
  }

  Widget _regionDropdown<T>({
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?>? onChanged,
    bool isRequired = false,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return Row(
        children: [
          const SizedBox(
              width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.md),
          Text(hint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant)),
        ],
      );
    }
    return ModernDropdown<T>(
      value: value,
      labelText: label,
      hint: hint,
      isRequired: isRequired,
      prefixIcon: Icon(icon, size: 20),
      items: items,
      getLabel: itemLabel,
      onChanged: onChanged,
      validator: isRequired
          ? (v) => v == null ? '$label wajib dipilih' : null
          : null,
    );
  }

  Widget _buildCoordinateSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final hasCoordinate = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Koordinat (opsional)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        AppSpacing.gapVerticalSM,
        OutlinedButton.icon(
          onPressed: _locating ? null : _pickCurrentLocation,
          icon: _locating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location_outlined),
          label: const Text('Ambil lokasi saat ini'),
        ),
        AppSpacing.gapVerticalSM,
        if (hasCoordinate)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant),
            ),
          ),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: AppSpacing.borderRadiusMD,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      _latitude ?? -6.200000,
                      _longitude ?? 106.816666,
                    ),
                    initialZoom: 13,
                    // Tap peta → set koordinat konsumen.
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _latitude = latLng.latitude;
                        _longitude = latLng.longitude;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      userAgentPackageName: 'id.sagansa.presence',
                    ),
                    if (hasCoordinate)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_latitude!, _longitude!),
                            child: const Icon(Icons.location_pin,
                                color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
                if (!hasCoordinate)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: colorScheme.surface.withValues(alpha: 0.3),
                        alignment: Alignment.center,
                        child: Text(
                          'Tap peta untuk set lokasi',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            backgroundColor:
                                colorScheme.surface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}