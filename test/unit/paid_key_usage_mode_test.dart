import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/features/settings/paid_key_usage_mode.dart';

void main() {
  group('PaidKeyUsageMode', () {
    test('has correct display names', () {
      expect(PaidKeyUsageMode.fallback.displayName, 'Fallback');
      expect(PaidKeyUsageMode.asDefault.displayName, 'Default');
      expect(PaidKeyUsageMode.rateBased.displayName, 'Rate-Based');
    });

    test('has correct descriptions', () {
      expect(PaidKeyUsageMode.fallback.description,
          'Use paid key only when free key hits rate limit');
      expect(PaidKeyUsageMode.asDefault.description, 'Always use the paid key');
      expect(PaidKeyUsageMode.rateBased.description,
          'Use at a configurable rate per minute');
    });

    test('values list has all modes', () {
      expect(PaidKeyUsageMode.values.length, 3);
      expect(PaidKeyUsageMode.values, contains(PaidKeyUsageMode.fallback));
      expect(PaidKeyUsageMode.values, contains(PaidKeyUsageMode.asDefault));
      expect(PaidKeyUsageMode.values, contains(PaidKeyUsageMode.rateBased));
    });
  });
}
