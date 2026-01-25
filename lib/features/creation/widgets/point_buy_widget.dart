import 'package:flutter/material.dart';

class PointBuyWidget extends StatefulWidget {
  final ValueChanged<Map<String, int>> onStatsChanged;

  const PointBuyWidget({
    super.key,
    required this.onStatsChanged,
  });

  @override
  State<PointBuyWidget> createState() => _PointBuyWidgetState();
}

class _PointBuyWidgetState extends State<PointBuyWidget> {
  // Initial stats (all 8)
  final Map<String, int> _stats = {
    'Strength': 8,
    'Dexterity': 8,
    'Constitution': 8,
    'Intelligence': 8,
    'Wisdom': 8,
    'Charisma': 8,
  };

  // Initial points budget
  static const int _maxPoints = 27;

  int get _usedPoints {
    int total = 0;
    for (var score in _stats.values) {
      total += _calculateCost(score);
    }
    return total;
  }

  int get _remainingPoints => _maxPoints - _usedPoints;

  // Cost to reach a certain score from 8
  int _calculateCost(int score) {
    // 8: 0
    // 9: 1
    // 10: 2
    // 11: 3
    // 12: 4
    // 13: 5
    // 14: 7 (+2)
    // 15: 9 (+2)
    if (score <= 8) return 0;
    if (score <= 13) return score - 8;
    if (score == 14) return 7;
    if (score == 15) return 9;
    return 0; // Should not happen with validation
  }

  // Cost to increase from current to next
  int _costToIncrease(int currentScore) {
    if (currentScore < 13) return 1;
    if (currentScore >= 13) return 2;
    return 100; // Impossible
  }

  void _increaseStat(String stat) {
    final current = _stats[stat]!;
    if (current >= 15) return;

    final cost = _costToIncrease(current);
    if (_remainingPoints >= cost) {
      setState(() {
        _stats[stat] = current + 1;
      });
      widget.onStatsChanged(_stats);
    }
  }

  void _decreaseStat(String stat) {
    final current = _stats[stat]!;
    if (current <= 8) return;

    setState(() {
      _stats[stat] = current - 1;
    });
    widget.onStatsChanged(_stats);
  }

  Color _getStatColor(int score) {
    if (score >= 14) return Colors.amber;
    if (score >= 12) return Colors.blue;
    return Colors.white;
  }

  @override
  void initState() {
    super.initState();
    // Fire initial stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStatsChanged(_stats);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ability Scores (Point Buy)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        _remainingPoints >= 0 ? Colors.blue[900] : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: Text(
                    'Points: $_remainingPoints',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._stats.entries.map((entry) {
              final stat = entry.key;
              final score = entry.value;
              final costNext = _costToIncrease(score);
              final canAfford = _remainingPoints >= costNext && score < 15;
              final canDecrease = score > 8;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        stat,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$score',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatColor(score)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: canDecrease ? Colors.redAccent : Colors.grey,
                            onPressed:
                                canDecrease ? () => _decreaseStat(stat) : null,
                            tooltip: '-1 Score',
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: canAfford ? Colors.greenAccent : Colors.grey,
                            onPressed:
                                canAfford ? () => _increaseStat(stat) : null,
                            tooltip:
                                'Cost: $costNext pts', // Show cost in tooltip
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        // Show total cost for this stat so far
                        '(${_calculateCost(score)} pts)',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
