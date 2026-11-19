import 'dart:io';
import 'package:flutter/foundation.dart';

/// Data supplier dari item fuel/service yang dipilih.
class SelectedSupplier {
  final int id;
  final String name;
  final String? bankName;
  final String? bankAccountNo;
  final String? bankAccountName;
  final String? qris;

  const SelectedSupplier({
    required this.id,
    required this.name,
    this.bankName,
    this.bankAccountNo,
    this.bankAccountName,
    this.qris,
  });
}

/// State untuk flow pembayaran transfer bensin/servis.
///
/// Provider ini menyimpan:
/// - selectedFuelServiceIds: id fuel service yang dipilih user
/// - _amounts: mapping fuel_service_id → amount (untuk compute total)
/// - _suppliersById: supplier per item terpilih (bisa null untuk item bensin)
/// - _serviceSupplierId: supplier item servis terpilih (aturan 1 supplier)
/// - imageFile: bukti transfer yang di-upload (opsional)
/// - notes: catatan
///
/// Aturan supplier:
/// - Item SERVIS (fuel_service == 2) dibayar ke rekening supplier, sehingga
///   semua item servis dalam satu receipt wajib berasal dari supplier sama
///   (tidak boleh null).
/// - Item BENSIN (fuel_service == 1) dibayar ke rekening user pembuat item
///   (reimbursement), sehingga boleh beda-beda supplier atau tanpa supplier.
///
/// UI pakai provider ini via `context.watch<FuelServicePaymentProvider>()`.
/// Saat submit, panggil submit() yang akan call service API.
class FuelServicePaymentProvider extends ChangeNotifier {
  final Set<int> _selectedIds = {};
  final Map<int, int> _amounts = {};
  final Map<int, SelectedSupplier?> _suppliersById = {};
  final Set<int> _selectedServiceIds = {};
  int? _serviceSupplierId;
  File? _imageFile;
  String _notes = '';
  bool _isSubmitting = false;

  List<int> get selectedFuelServiceIds => _selectedIds.toList();
  int get selectedCount => _selectedIds.length;
  bool isSelected(int id) => _selectedIds.contains(id);
  int get totalAmount => _amounts.values.fold(0, (sum, a) => sum + a);
  File? get imageFile => _imageFile;
  String get notes => _notes;
  bool get isSubmitting => _isSubmitting;

  /// Supplier unik dari seluruh item terpilih (item tanpa supplier diabaikan).
  List<SelectedSupplier> get distinctSuppliers {
    final byId = <int, SelectedSupplier>{};
    for (final s in _suppliersById.values) {
      if (s != null) byId[s.id] = s;
    }
    return byId.values.toList();
  }

  /// Supplier tunggal bila SEMUA item terpilih berasal dari satu supplier
  /// yang sama — kartu supplier + QRIS hanya relevan dalam kondisi ini.
  /// Null bila belum ada item, atau supplier berbeda/campur (reimbursement).
  SelectedSupplier? get supplier {
    final suppliers = distinctSuppliers;
    return suppliers.length == 1 ? suppliers.first : null;
  }

  /// True bila item terpilih berasal dari >1 supplier (hanya mungkin terjadi
  /// pada kombinasi item bensin) — UI menampilkan info pembayaran ke rekening
  /// pembuat alih-alih kartu supplier.
  bool get hasMixedSuppliers => distinctSuppliers.length > 1;

  /// Bisa submit jika minimal 1 item dipilih (image opsional per spec).
  bool get canSubmit => _selectedIds.isNotEmpty && !_isSubmitting;

  /// Toggle selection untuk satu fuel service. [amount] = nominal fuel
  /// service. [fuelServiceType] = 1 (bensin) / 2 (servis) — menentukan
  /// aturan supplier (lihat doc class). [supplierId], [supplierName], dll.
  /// digunakan untuk validasi & kartu supplier.
  /// Returns null on success, or error message string on failure.
  String? toggleSelection(
    int fuelServiceId, {
    required int amount,
    required int fuelServiceType,
    int? supplierId,
    String? supplierName,
    String? bankName,
    String? bankAccountNo,
    String? bankAccountName,
    String? qris,
  }) {
    if (_selectedIds.contains(fuelServiceId)) {
      _selectedIds.remove(fuelServiceId);
      _amounts.remove(fuelServiceId);
      _suppliersById.remove(fuelServiceId);
      _selectedServiceIds.remove(fuelServiceId);
      // Jika tidak ada lagi item servis terpilih, reset supplier servis.
      if (_selectedServiceIds.isEmpty) {
        _serviceSupplierId = null;
      }
      notifyListeners();
      return null;
    }

    // Item servis dibayar ke rekening supplier → wajib 1 supplier sama.
    // Item bensin dibayar ke rekening pembuat → supplier bebas/opsional.
    if (fuelServiceType == 2) {
      if (supplierId == null) {
        return 'Item servis ini belum memiliki data supplier. Lengkapi data supplier terlebih dahulu.';
      }
      if (_serviceSupplierId != null && _serviceSupplierId != supplierId) {
        final currentSupplier = distinctSuppliers
            .firstWhere((s) => s.id == _serviceSupplierId);
        return 'Item servis ini berasal dari supplier berbeda (${currentSupplier.name}). Pilih item servis dari supplier yang sama.';
      }
      _serviceSupplierId = supplierId;
      _selectedServiceIds.add(fuelServiceId);
    }

    _selectedIds.add(fuelServiceId);
    _amounts[fuelServiceId] = amount;
    _suppliersById[fuelServiceId] = supplierId == null
        ? null
        : SelectedSupplier(
            id: supplierId,
            name: supplierName ?? '-',
            bankName: bankName,
            bankAccountNo: bankAccountNo,
            bankAccountName: bankAccountName,
            qris: qris,
          );
    notifyListeners();
    return null;
  }

  void setImageFile(File? file) {
    _imageFile = file;
    notifyListeners();
  }

  void setNotes(String value) {
    _notes = value;
    notifyListeners();
  }

  void setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  /// Reset semua state ke kondisi awal.
  void clearSelection() {
    _selectedIds.clear();
    _amounts.clear();
    _suppliersById.clear();
    _selectedServiceIds.clear();
    _serviceSupplierId = null;
    _imageFile = null;
    _notes = '';
    _isSubmitting = false;
    notifyListeners();
  }
}
