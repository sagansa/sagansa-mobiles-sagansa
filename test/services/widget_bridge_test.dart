import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/services/widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  Object? savedData(String id) {
    final call = calls.lastWhere((c) =>
        c.method == 'saveWidgetData' && (c.arguments as Map)['id'] == id);
    return (call.arguments as Map)['data'];
  }

  test('syncAuth menyimpan token, role, app group, lalu reload widget', () async {
    await WidgetBridge.syncAuth(token: 'tok-abc', isAdmin: true);

    final setGroup = calls.firstWhere((c) => c.method == 'setAppGroupId');
    expect((setGroup.arguments as Map)['groupId'], 'group.id.sagansa.app');

    expect(savedData('auth_token'), 'tok-abc');
    expect(savedData('is_admin'), true);

    final update = calls.firstWhere((c) => c.method == 'updateWidget');
    // iOSName = KIND widget WidgetKit, bukan nama target extension.
    expect((update.arguments as Map)['ios'], 'SagansaDashboard');
  });

  test('syncAuth dengan token kosong menghapus data widget (logout)', () async {
    await WidgetBridge.syncAuth(token: '', isAdmin: false);
    expect(savedData('auth_token'), isNull);
    expect(savedData('is_admin'), false);
  });

  test('syncAuth menelan error channel — tidak throw', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      throw PlatformException(code: 'unavailable');
    });
    await WidgetBridge.syncAuth(token: 'x', isAdmin: true);
    // Tidak melempar = lulus.
  });
}
