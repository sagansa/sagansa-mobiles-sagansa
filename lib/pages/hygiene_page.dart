import 'dart:io';

import 'package:flutter/material.dart';

import '../models/hygiene_model.dart';
import '../models/store_model.dart';
import '../services/asset_service.dart';
import '../services/hygiene_service.dart';
import '../services/image_service.dart';
import '../services/store_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/modern_dropdown.dart';
import '../widgets/safe_bottom_bar.dart';

class HygienePage extends StatefulWidget {
  final int? initialStoreId;

  const HygienePage({super.key, this.initialStoreId});

  @override
  State<HygienePage> createState() => _HygienePageState();
}

class _HygienePageState extends State<HygienePage> {
  final HygieneService _hygieneService = HygieneService();

  List<RoomModel> _rooms = [];
  final Map<int, File?> _roomPhotos = {};
  final Map<int, String?> _roomNotes = {};
  List<StoreModel> _stores = [];
  StoreModel? _selectedStore;
  int? _storeId;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final storeService = StoreService();
      final assetService = AssetService();
      final results = await Future.wait([
        _hygieneService.getRooms(),
        storeService.getStores(),
        assetService.getCurrentStoreId(),
      ]);

      final rooms = results[0] as List<RoomModel>;
      final stores = results[1] as List<StoreModel>;
      final currentStoreId = results[2] as int?;

      StoreModel? selectedStore;
      if (widget.initialStoreId != null) {
        selectedStore =
            stores.where((s) => s.id == widget.initialStoreId).firstOrNull;
      }
      if (selectedStore == null && currentStoreId != null) {
        selectedStore = stores.where((s) => s.id == currentStoreId).firstOrNull;
      }
      if (selectedStore == null && stores.isNotEmpty) {
        selectedStore = stores.first;
      }
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _stores = stores;
          _selectedStore = selectedStore;
          _storeId = selectedStore?.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.error(context, 'Gagal memuat data: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  int get _completedCount {
    int count = 0;
    for (final room in _rooms) {
      if (_roomPhotos[room.id] != null) {
        count++;
      }
    }
    return count;
  }

  bool get _isReadyToSubmit {
    return _completedCount >= _rooms.length;
  }

  Future<void> _pickImage(int roomId) async {
    final photo = await ImageService.selectAndPickImage(context);
    if (photo != null && mounted) {
      setState(() {
        _roomPhotos[roomId] = photo;
      });
    }
  }

  // Condition picking removed per requirements (admin determines status, not staff)

  Future<void> _addNotes(int roomId) async {
    final controller = TextEditingController(text: _roomNotes[roomId] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catatan'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tulis catatan kondisi ruangan...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _roomNotes[roomId] = result.trim().isEmpty ? null : result.trim();
      });
    }
  }

  Future<void> _submit() async {
    if (_storeId == null) {
      SnackbarUtils.warning(context, 'Silakan pilih toko terlebih dahulu!');
      return;
    }

    if (!_isReadyToSubmit) {
      SnackbarUtils.warning(context, 'Lengkapi semua ruangan terlebih dahulu!');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Laporan'),
        content:
            Text('Kirim laporan kebersihan untuk $_completedCount ruangan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final rooms = _rooms.map((room) {
        return {
          'room_id': room.id,
          'image_path': _roomPhotos[room.id]?.path,
          'condition': null,
          'notes': _roomNotes[room.id],
        };
      }).toList();

      await _hygieneService.submitHygiene(
        storeId: _storeId ?? 0,
        rooms: rooms,
      );

      if (mounted) {
        SnackbarUtils.success(context, 'Laporan kebersihan berhasil dikirim!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.error(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading && !_isSubmitting,
      child: Scaffold(
        appBar: GlassAppBar(
          title: const Text('Kebersihan Toko'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final progress = _rooms.isEmpty ? 0.0 : _completedCount / _rooms.length;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ModernDropdown<StoreModel>(
                        value: _selectedStore,
                        labelText: 'Pilih Toko',
                        hint: 'Pilih Toko...',
                        isRequired: true,
                        prefixIcon:
                            const Icon(Icons.storefront_rounded, size: 20),
                        items: _stores,
                        getLabel: (s) => s.nickname.isNotEmpty
                            ? s.nickname
                            : 'Store #${s.id}',
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _selectedStore = v;
                            _storeId = v.id;
                          });
                        },
                      ),
                      AppSpacing.gapVerticalMD,
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: AppSpacing.borderRadiusSM,
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                            ),
                          ),
                          AppSpacing.gapHorizontalMD,
                          Text(
                            '$_completedCount/${_rooms.length}',
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      AppSpacing.gapVerticalSM,
                      Text(
                        _isReadyToSubmit
                            ? 'Semua ruangan sudah diperiksa'
                            : '${_rooms.length - _completedCount} ruangan belum diperiksa',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isReadyToSubmit
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      AppSpacing.gapVerticalMD,
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: AppSpacing.paddingHorizontalMD,
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildRoomCard(_rooms[index]),
                    childCount: _rooms.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: context.systemBottomInset + 100),
              ),
            ],
          ),
        ),
        _buildSubmitBar(),
      ],
    );
  }

  Widget _buildRoomCard(RoomModel room) {
    final hasPhoto = _roomPhotos.containsKey(room.id);
    final photoFile = _roomPhotos[room.id];
    final hasNotes =
        _roomNotes.containsKey(room.id) && _roomNotes[room.id] != null;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusMD,
      child: GestureDetector(
        onTap: () => _pickImage(room.id),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border.all(
              color: hasPhoto ? AppColors.success : colorScheme.outlineVariant,
              width: hasPhoto ? 2 : 1,
            ),
            borderRadius: AppSpacing.borderRadiusMD,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Photo / Camera Placeholder (1:1 aspect ratio)
              hasPhoto && photoFile != null
                  ? Image.file(
                      photoFile,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: AppColors.info,
                        ),
                        AppSpacing.gapVerticalXS,
                        Text(
                          'Ambil Foto',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

              // 2. Scrim Atas: Nama Ruangan + Indicator
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 2, color: Colors.black54)
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasPhoto) ...[
                        AppSpacing.gapHorizontalXS,
                        Icon(Icons.check_circle,
                            size: 16, color: AppColors.success),
                      ],
                    ],
                  ),
                ),
              ),

              // 3. Scrim Bawah: Catatan
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () => _addNotes(room.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasNotes
                            ? AppColors.info
                            : Colors.black.withValues(alpha: 0.5),
                        borderRadius: AppSpacing.borderRadiusXS,
                        border: Border.all(
                          color: hasNotes ? AppColors.info : Colors.white30,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasNotes ? Icons.notes : Icons.notes_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          AppSpacing.gapHorizontalXS,
                          Flexible(
                            child: Text(
                              hasNotes
                                  ? (_roomNotes[room.id] ?? 'Ada Catatan')
                                  : 'Catatan',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitBar() {
    return SafeBottomBar(
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _isSubmitting ? 'Mengirim...' : 'KIRIM LAPORAN KEBERSIHAN',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
