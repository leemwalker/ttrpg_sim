import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/rules/dnd5e_rules.dart';

void main() {
  group('HP Calculation Tests', () {
    final rules = Dnd5eRules();

    test('Fighter Level 1 (CON 10) -> HP 10', () {
      expect(rules.calculateMaxHp('Fighter', 1, 10, []), equals(10));
    });

    test('Fighter Level 1 (CON 14) -> HP 12 (10 Base + 2 Mod)', () {
      expect(rules.calculateMaxHp('Fighter', 1, 14, []), equals(12));
    });

    test('Wizard Level 1 (CON 10) -> HP 6', () {
      expect(rules.calculateMaxHp('Wizard', 1, 10, []), equals(6));
    });

    test('Fighter Level 2 (CON 10) -> HP 16 (10 + 6)', () {
      // Level 2 adds (10/2 + 1) = 6
      expect(rules.calculateMaxHp('Fighter', 2, 10, []), equals(16));
    });

    test('Fighter Level 2 (CON 14) -> HP 20 (12 + (6 + 2))', () {
      // Lev 1: 10 + 2 = 12
      // Lev 2: 6 + 2 = 8
      // Total: 20
      expect(rules.calculateMaxHp('Fighter', 2, 14, []), equals(20));
    });

    test('Fighter Level 1 with Tough Feat -> HP 12 (10 + 2)', () {
      expect(rules.calculateMaxHp('Fighter', 1, 10, ['Tough']), equals(12));
    });

    test('Fighter Level 5 (CON 14) with Tough Feat', () {
      // Lev 1: 10 (base) + 2 (con) = 12
      // Lev 2-5 (4 levels): 4 * (6 + 2) = 32
      // Tough: 2 * 5 = 10
      // Total: 12 + 32 + 10 = 54
      expect(rules.calculateMaxHp('Fighter', 5, 14, ['Tough']), equals(54));
    });
  });
}
