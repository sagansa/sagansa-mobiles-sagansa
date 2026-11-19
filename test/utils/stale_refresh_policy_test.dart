import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/utils/stale_refresh_policy.dart';

void main() {
  final now = DateTime(2026, 11, 8, 9);

  group('StaleRefreshPolicy', () {
    test('lastFetch null (belum pernah fetch) → tidak refresh', () {
      const policy = StaleRefreshPolicy(threshold: Duration(minutes: 5));
      expect(policy.shouldRefresh(null, now), isFalse);
    });

    test('di bawah ambang → tidak refresh', () {
      const policy = StaleRefreshPolicy(threshold: Duration(minutes: 5));
      final lastFetch = now.subtract(const Duration(minutes: 4, seconds: 59));
      expect(policy.shouldRefresh(lastFetch, now), isFalse);
    });

    test('tepat pada ambang → refresh', () {
      const policy = StaleRefreshPolicy(threshold: Duration(minutes: 5));
      final lastFetch = now.subtract(const Duration(minutes: 5));
      expect(policy.shouldRefresh(lastFetch, now), isTrue);
    });

    test('melewati ambang → refresh', () {
      const policy = StaleRefreshPolicy(threshold: Duration(minutes: 5));
      final lastFetch = now.subtract(const Duration(hours: 8));
      expect(policy.shouldRefresh(lastFetch, now), isTrue);
    });

    test('ambang kustom dihormati', () {
      const policy = StaleRefreshPolicy(threshold: Duration(seconds: 30));
      final lastFetch = now.subtract(const Duration(seconds: 31));
      expect(policy.shouldRefresh(lastFetch, now), isTrue);
    });
  });
}
