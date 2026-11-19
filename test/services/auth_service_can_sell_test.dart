import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kontrak `AuthService.canSell`: ber-role `sales` = boleh berjualan,
/// termasuk `sales + former-employee` (sales eksternal, keputusan
/// 2026-10-16). Roles dibaca dari prefs `user`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedRoles(List<String> roles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = roles.map((r) => '"$r"').join(',');
    await prefs.setString('user', '{"roles": [$encoded]}');
  }

  test('canSell true untuk sales + former-employee (sales eksternal)',
      () async {
    await seedRoles(['sales', 'former-employee']);
    expect(await AuthService.canSell(), isTrue);
  });

  test('canSell true untuk sales aktif', () async {
    await seedRoles(['sales']);
    expect(await AuthService.canSell(), isTrue);
  });

  test('canSell false tanpa role sales', () async {
    await seedRoles(['staff', 'supervisor']);
    expect(await AuthService.canSell(), isFalse);
  });

  test('canSell false bila data user tidak ada', () async {
    expect(await AuthService.canSell(), isFalse);
  });
}
