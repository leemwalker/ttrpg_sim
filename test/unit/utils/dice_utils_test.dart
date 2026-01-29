import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/utils/dice_utils.dart';

void main() {
  group('DiceUtils Tests', () {
    test('rollD20 returns values between 1 and 20', () {
      for (int i = 0; i < 100; i++) {
        final result = DiceUtils.rollD20();
        expect(result, greaterThanOrEqualTo(1));
        expect(result, lessThanOrEqualTo(20));
      }
    });

    test('roll returns correct range for custom sides', () {
      // d6
      for (int i = 0; i < 50; i++) {
        final result = DiceUtils.rollDie(6);
        expect(result, greaterThanOrEqualTo(1));
        expect(result, lessThanOrEqualTo(6));
      }
    });

    test('rollDie handles invalid sides gracefully', () {
      expect(DiceUtils.rollDie(0), 0);
      expect(DiceUtils.rollDie(-5), 0);
    });
  });
}
