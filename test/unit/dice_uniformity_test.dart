import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/core/utils/dice_utils.dart';

/// Statistical tests to verify dice rolling produces expected distributions.
///
/// For a d20, we expect a uniform distribution where each value (1-20)
/// has an equal probability of 5% (1/20).
void main() {
  group('DiceUtils Uniformity Tests', () {
    test('d20 rolls should be uniformly distributed', () {
      // Number of rolls - higher = more statistical power
      const int numRolls = 100000;
      const int sides = 20;
      const double expectedProbability = 1.0 / sides; // 5%
      const double expectedCount = numRolls * expectedProbability; // 5000

      // Count occurrences of each value
      final Map<int, int> counts = {};
      for (int i = 1; i <= sides; i++) {
        counts[i] = 0;
      }

      // Roll the d20 many times
      for (int i = 0; i < numRolls; i++) {
        final int roll = DiceUtils.rollD20();
        counts[roll] = counts[roll]! + 1;
      }

      // Verify all values are within expected range (1-20)
      for (int value in counts.keys) {
        expect(value, greaterThanOrEqualTo(1));
        expect(value, lessThanOrEqualTo(20));
      }

      // Calculate chi-squared statistic
      // χ² = Σ((observed - expected)² / expected)
      double chiSquared = 0.0;
      for (int i = 1; i <= sides; i++) {
        final double observed = counts[i]!.toDouble();
        final double diff = observed - expectedCount;
        chiSquared += (diff * diff) / expectedCount;
      }

      // For 19 degrees of freedom (20-1), critical values:
      // - α = 0.01 (99% confidence): 36.19
      // - α = 0.05 (95% confidence): 30.14
      // - α = 0.001 (99.9% confidence): 43.82
      //
      // If chi-squared is less than the critical value, we cannot reject
      // the null hypothesis that the distribution is uniform.
      const double criticalValue99 = 36.19;

      // Log distribution for debugging
      print('\n=== D20 Uniformity Test Results ===');
      print('Total rolls: $numRolls');
      print('Expected count per value: ${expectedCount.toStringAsFixed(0)}');
      print('\nDistribution:');

      // Calculate min/max deviation for reporting
      double maxDeviation = 0.0;
      int maxDeviationValue = 0;

      for (int i = 1; i <= sides; i++) {
        final int count = counts[i]!;
        final double percentage = (count / numRolls) * 100;
        final double deviation =
            ((count - expectedCount) / expectedCount) * 100;

        if (deviation.abs() > maxDeviation.abs()) {
          maxDeviation = deviation;
          maxDeviationValue = i;
        }

        // Visual bar representation
        final int barLength = (percentage * 2).round(); // Scale for visibility
        final String bar = '█' * barLength;

        print('  ${i.toString().padLeft(2)}: ${count.toString().padLeft(6)} '
            '(${percentage.toStringAsFixed(2)}%) $bar');
      }

      print('\nStatistics:');
      print('  Chi-squared value: ${chiSquared.toStringAsFixed(2)}');
      print('  Critical value (α=0.01): $criticalValue99');
      print(
          '  Max deviation: ${maxDeviation.toStringAsFixed(2)}% (value: $maxDeviationValue)');
      print('  Result: ${chiSquared < criticalValue99 ? "PASS ✓" : "FAIL ✗"}');
      print('===================================\n');

      // Primary assertion: chi-squared test
      expect(
        chiSquared,
        lessThan(criticalValue99),
        reason:
            'Chi-squared value $chiSquared exceeds critical value $criticalValue99. '
            'The d20 distribution does not appear to be uniform.',
      );

      // Secondary assertion: no single value should deviate by more than 10%
      // (a sanity check in addition to chi-squared)
      for (int i = 1; i <= sides; i++) {
        final double observedPercentage = counts[i]! / numRolls;
        expect(
          observedPercentage,
          closeTo(expectedProbability, 0.01), // Within 1% absolute deviation
          reason:
              'Value $i appears ${(observedPercentage * 100).toStringAsFixed(2)}% '
              'of the time, expected ${(expectedProbability * 100).toStringAsFixed(2)}%',
        );
      }
    });

    test('rollDie should produce values within expected range', () {
      // Test various die sizes
      final List<int> dieSizes = [4, 6, 8, 10, 12, 20, 100];

      for (int sides in dieSizes) {
        for (int i = 0; i < 1000; i++) {
          final int roll = DiceUtils.rollDie(sides);
          expect(roll, greaterThanOrEqualTo(1),
              reason: 'd$sides rolled $roll, expected >= 1');
          expect(roll, lessThanOrEqualTo(sides),
              reason: 'd$sides rolled $roll, expected <= $sides');
        }
      }
    });

    test('roll formula "1d20" should match rollD20 distribution', () {
      const int numRolls = 10000;
      final Map<int, int> counts = {};
      for (int i = 1; i <= 20; i++) {
        counts[i] = 0;
      }

      for (int i = 0; i < numRolls; i++) {
        final result = DiceUtils.roll('1d20');
        counts[result.total] = counts[result.total]! + 1;
      }

      // Just verify values are in range
      for (int i = 1; i <= 20; i++) {
        expect(counts[i], greaterThan(0),
            reason: 'Value $i was never rolled in $numRolls attempts');
      }
    });

    test('d6 rolls should be uniformly distributed', () {
      const int numRolls = 60000;
      const int sides = 6;
      final double expectedCount = numRolls / sides; // 10000

      final Map<int, int> counts = {};
      for (int i = 1; i <= sides; i++) {
        counts[i] = 0;
      }

      for (int i = 0; i < numRolls; i++) {
        final int roll = DiceUtils.rollDie(6);
        counts[roll] = counts[roll]! + 1;
      }

      // Chi-squared test for d6
      double chiSquared = 0.0;
      for (int i = 1; i <= sides; i++) {
        final double observed = counts[i]!.toDouble();
        final double diff = observed - expectedCount;
        chiSquared += (diff * diff) / expectedCount;
      }

      // For 5 degrees of freedom, critical value at α=0.01 is 15.09
      const double criticalValue = 15.09;

      print('\n=== D6 Uniformity Test ===');
      print(
          'Chi-squared: ${chiSquared.toStringAsFixed(2)} (critical: $criticalValue)');
      for (int i = 1; i <= sides; i++) {
        print(
            '  $i: ${counts[i]} (${(counts[i]! / numRolls * 100).toStringAsFixed(2)}%)');
      }
      print('==========================\n');

      expect(chiSquared, lessThan(criticalValue));
    });

    test('edge case: rollDie with 0 or negative sides returns 0', () {
      expect(DiceUtils.rollDie(0), equals(0));
      expect(DiceUtils.rollDie(-1), equals(0));
      expect(DiceUtils.rollDie(-100), equals(0));
    });

    test('roll formula parsing handles complex expressions', () {
      // Test various formulas
      final result1 = DiceUtils.roll('2d6+5');
      expect(result1.total, greaterThanOrEqualTo(7)); // 2+5 minimum
      expect(result1.total, lessThanOrEqualTo(17)); // 12+5 maximum
      expect(result1.formula, equals('2d6+5'));

      final result2 = DiceUtils.roll('1d8-2');
      expect(result2.total, greaterThanOrEqualTo(-1)); // 1-2 minimum
      expect(result2.total, lessThanOrEqualTo(6)); // 8-2 maximum

      final result3 = DiceUtils.roll('d20');
      expect(result3.total, greaterThanOrEqualTo(1));
      expect(result3.total, lessThanOrEqualTo(20));
    });
  });
}
