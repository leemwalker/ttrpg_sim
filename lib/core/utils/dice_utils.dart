import 'dart:math';

class DiceUtils {
  static final Random _random = Random();

  /// Rolls a d20 (1-20)
  static int rollD20() {
    return _random.nextInt(20) + 1;
  }

  /// Rolls any die size (1-sides)
  static int roll(int sides) {
    if (sides < 1) return 0;
    return _random.nextInt(sides) + 1;
  }
}
