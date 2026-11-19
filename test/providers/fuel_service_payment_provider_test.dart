import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/providers/fuel_service_payment_provider.dart';

void main() {
  group('FuelServicePaymentProvider', () {
    test('initial state kosong', () {
      final p = FuelServicePaymentProvider();
      expect(p.selectedFuelServiceIds, isEmpty);
      expect(p.totalAmount, 0);
      expect(p.imageFile, isNull);
      expect(p.notes, isEmpty);
      expect(p.canSubmit, isFalse);
      expect(p.supplier, isNull);
      expect(p.hasMixedSuppliers, isFalse);
    });

    test('toggle selection menambah/menghapus id', () {
      final p = FuelServicePaymentProvider();
      final err = p.toggleSelection(1,
          amount: 50000, fuelServiceType: 1, supplierId: 10);
      expect(err, isNull);
      expect(p.selectedFuelServiceIds, [1]);
      expect(p.totalAmount, 50000);
      expect(p.isSelected(1), isTrue);
      expect(p.supplier?.id, 10);

      p.toggleSelection(1, amount: 50000, fuelServiceType: 1);
      expect(p.selectedFuelServiceIds, isEmpty);
      expect(p.totalAmount, 0);
      expect(p.isSelected(1), isFalse);
      expect(p.supplier, isNull);
    });

    test('multi-select akumulasi total (satu supplier)', () {
      final p = FuelServicePaymentProvider();
      p.toggleSelection(1,
          amount: 50000, fuelServiceType: 2, supplierId: 10);
      p.toggleSelection(2,
          amount: 30000, fuelServiceType: 2, supplierId: 10);
      p.toggleSelection(3,
          amount: 20000, fuelServiceType: 1, supplierId: 10);
      expect(p.selectedCount, 3);
      expect(p.totalAmount, 100000);
      expect(p.hasMixedSuppliers, isFalse);
    });

    test('item servis tanpa supplier ditolak', () {
      final p = FuelServicePaymentProvider();
      final err = p.toggleSelection(1, amount: 50000, fuelServiceType: 2);
      expect(err, isNotNull);
      expect(p.selectedFuelServiceIds, isEmpty);
      expect(p.canSubmit, isFalse);
    });

    test('item servis supplier berbeda ditolak', () {
      final p = FuelServicePaymentProvider();
      p.toggleSelection(1,
          amount: 50000, fuelServiceType: 2, supplierId: 10);
      final err = p.toggleSelection(2,
          amount: 30000, fuelServiceType: 2, supplierId: 20);
      expect(err, isNotNull);
      expect(p.selectedFuelServiceIds, [1]);
      expect(p.supplier?.id, 10);
    });

    test('item bensin tanpa supplier diijinkan (reimbursement)', () {
      final p = FuelServicePaymentProvider();
      final err = p.toggleSelection(1, amount: 50000, fuelServiceType: 1);
      expect(err, isNull);
      expect(p.selectedFuelServiceIds, [1]);
      expect(p.canSubmit, isTrue);
      // Tidak ada supplier sama sekali → tidak ada kartu supplier.
      expect(p.supplier, isNull);
      expect(p.hasMixedSuppliers, isFalse);
    });

    test('item bensin beda supplier diijinkan', () {
      final p = FuelServicePaymentProvider();
      expect(
        p.toggleSelection(1,
            amount: 50000, fuelServiceType: 1, supplierId: 10),
        isNull,
      );
      expect(
        p.toggleSelection(2,
            amount: 30000, fuelServiceType: 1, supplierId: 20),
        isNull,
      );
      expect(p.selectedCount, 2);
      expect(p.totalAmount, 80000);
      expect(p.hasMixedSuppliers, isTrue);
      // Supplier campur → tidak ada supplier tunggal (kartu supplier
      // disembunyikan, diganti info reimbursement).
      expect(p.supplier, isNull);

      // Deselect salah satu → kembali satu supplier tunggal.
      p.toggleSelection(2, amount: 30000, fuelServiceType: 1, supplierId: 20);
      expect(p.hasMixedSuppliers, isFalse);
      expect(p.supplier?.id, 10);
    });

    test('bensin campur supplier + servis satu supplier diijinkan', () {
      final p = FuelServicePaymentProvider();
      p.toggleSelection(1,
          amount: 50000, fuelServiceType: 1, supplierId: 10);
      p.toggleSelection(2,
          amount: 30000, fuelServiceType: 1, supplierId: 20);
      final err = p.toggleSelection(3,
          amount: 70000, fuelServiceType: 2, supplierId: 30);
      expect(err, isNull);
      expect(p.selectedCount, 3);
      expect(p.hasMixedSuppliers, isTrue);
    });

    test('deselect semua item servis melepas aturan satu supplier servis', () {
      final p = FuelServicePaymentProvider();
      p.toggleSelection(1,
          amount: 50000, fuelServiceType: 2, supplierId: 10);
      // Deselect satu-satunya item servis.
      p.toggleSelection(1,
          amount: 50000, fuelServiceType: 2, supplierId: 10);
      // Item servis dari supplier lain kini diijinkan.
      final err = p.toggleSelection(2,
          amount: 30000, fuelServiceType: 2, supplierId: 20);
      expect(err, isNull);
      expect(p.selectedFuelServiceIds, [2]);
    });

    test('canSubmit true jika ada item (image opsional)', () {
      final p = FuelServicePaymentProvider();
      p.toggleSelection(1,
          amount: 50000, fuelServiceType: 1, supplierId: 10);
      p.setNotes('Test note');
      expect(p.canSubmit, isTrue);
    });

    test('canSubmit false jika tidak ada item', () {
      final p = FuelServicePaymentProvider();
      p.setNotes('Test');
      expect(p.canSubmit, isFalse);
    });

    test('clearSelection reset state', () {
      final p = FuelServicePaymentProvider();
      p.toggleSelection(1,
          amount: 50000, fuelServiceType: 1, supplierId: 10);
      p.setNotes('note');
      p.clearSelection();
      expect(p.selectedFuelServiceIds, isEmpty);
      expect(p.totalAmount, 0);
      expect(p.notes, isEmpty);
      expect(p.imageFile, isNull);
      expect(p.supplier, isNull);
      expect(p.hasMixedSuppliers, isFalse);
    });

    test('setNotes update nilai', () {
      final p = FuelServicePaymentProvider();
      p.setNotes('hello world');
      expect(p.notes, 'hello world');
    });
  });
}
