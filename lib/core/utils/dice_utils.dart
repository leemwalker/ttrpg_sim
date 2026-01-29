import 'dart:math';

class RollResult {
  final int total;
  final String details;
  final String formula;

  RollResult({
    required this.total,
    required this.details,
    required this.formula,
  });

  @override
  String toString() => '$formula Result: $total ($details)';
}

class DiceUtils {
  static final Random _random = Random();

  /// Rolls a d20 (1-20)
  static int rollD20() {
    return _random.nextInt(20) + 1;
  }

  /// Rolls a single die of any size (1-sides)
  static int rollDie(int sides) {
    if (sides < 1) return 0;
    return _random.nextInt(sides) + 1;
  }

  /// Parses and rolls a dice formula (e.g., "3d8+5", "2d6-1", "1d8+1d6")
  static RollResult roll(String formula) {
    int total = 0;
    final List<String> detailsParts = [];

    // Normalize string: remove spaces, handle double signs if any
    String clean = formula.replaceAll(' ', '');
    // Replace '-' with '+-' to split by '+' safely (handling negative numbers/modifiers)
    // Note: This assumes standard notation. '3d8 - 5' -> '3d8+-5'
    clean = clean.replaceAll('-', '+-');

    // Split by '+'
    final List<String> parts = clean.split('+');

    for (String part in parts) {
      if (part.isEmpty) continue;

      String p = part;

      // Handle negative sign
      if (p.startsWith('-')) {
        // Should be covered by split if we see empty string?
        // '3d8-5' -> '3d8', '-5'. '-5' starts with -.
      }

      // Check for 'd' (dice)
      if (p.contains('d')) {
        // It's a die roll (e.g., "3d8", "-1d6", "d8", "-d8")
        try {
          bool negative = false;
          if (p.startsWith('-')) {
            negative = true;
            p = p.substring(1);
          }

          final List<String> dParts = p.split('d');
          final int count = dParts[0].isEmpty ? 1 : int.parse(dParts[0]);
          final int sides = int.parse(dParts[1]);

          int subTotal = 0;
          final List<int> rolls = [];

          for (int i = 0; i < count; i++) {
            final int r = _random.nextInt(sides) + 1;
            rolls.add(r);
            subTotal += r;
          }

          if (negative) {
            subTotal = -subTotal;
          }

          total += subTotal;
          // Format details: "[3, 5]" or "-[3, 5]"
          if (rolls.length > 1) {
            detailsParts.add('${negative ? "-" : ""}[${rolls.join(", ")}]');
          } else {
            detailsParts.add('${negative ? "-" : ""}[${rolls.first}]');
          }
        } catch (e) {
          // Fallback or ignore malformed parts
          print('Error parsing dice part: $part');
        }
      } else {
        // It's a modifier (e.g., "5", "-3")
        try {
          final int val = int.parse(p);
          total += val;
          detailsParts.add(((val >= 0)
              ? "+ $val"
              : "- ${val.abs()}")); // Store as string representation
        } catch (e) {
          // Ignore
        }
      }
    }

    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < detailsParts.length; i++) {
      final String s = detailsParts[i];
      if (i > 0) {
        if (!s.startsWith('+') && !s.startsWith('-')) {
          sb.write(' + '); // implicit add between dice groups if distinct?
          sb.write(s);
        } else {
          // modifiers have +/- already
          sb.write(' ');
          sb.write(s);
        }
      } else {
        // First element
        // if modifier starts with + 5, strip +
        if (s.startsWith('+ ')) {
          sb.write(s.substring(2));
        } else {
          sb.write(s);
        }
      }
    }

    return RollResult(total: total, details: sb.toString(), formula: formula);
  }
}
