import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sagansa/services/delivery_status_repository.dart';

/// Menguji DeliveryStatusRepository.loadDeliveryPhotoEditRole() — role gate
/// edit foto bukti pengiriman (admin & super_admin SAJA, tanpa supervisor).
/// Sengaja TERPISAH dari loadAdminRole() yang juga menghitung supervisor —
/// guard backend delivery-photos tidak memasukkan supervisor.
void main() {
  late DeliveryStatusRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = DeliveryStatusRepository();
  });

  Future<void> seedRoles(List<String> roles) async {
    SharedPreferences.setMockInitialValues({
      'user': jsonEncode({'id': 1, 'roles': roles}),
    });
  }

  test('admin: boleh edit foto', () async {
    await seedRoles(['admin']);
    expect(await repository.loadDeliveryPhotoEditRole(), isTrue);
  });

  test('super_admin: boleh edit foto', () async {
    await seedRoles(['super_admin']);
    expect(await repository.loadDeliveryPhotoEditRole(), isTrue);
  });

  test('supervisor: TIDAK boleh edit foto', () async {
    await seedRoles(['supervisor']);
    expect(await repository.loadDeliveryPhotoEditRole(), isFalse);
  });

  test('storage-staff: TIDAK boleh edit foto', () async {
    await seedRoles(['storage-staff']);
    expect(await repository.loadDeliveryPhotoEditRole(), isFalse);
  });

  test('tanpa role: tidak boleh edit foto', () async {
    await seedRoles([]);
    expect(await repository.loadDeliveryPhotoEditRole(), isFalse);
  });

  test('tanpa data user: tidak boleh edit foto', () async {
    expect(await repository.loadDeliveryPhotoEditRole(), isFalse);
  });
}
