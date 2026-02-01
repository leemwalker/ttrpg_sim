import 'package:flutter/material.dart';

class PointBuyWidget extends StatefulWidget {
  final ValueChanged<Map<String, int>> onStatsChanged;
  final int maxPoints;
  final int maxAttribute;

  const PointBuyWidget({
    super.key,
    required this.onStatsChanged,
    required this.maxPoints,
    required this.maxAttribute,
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

  int get _usedPoints {
    int total = 0;
    for (var score in _stats.values) {
      total += _calculateCost(score);
    }
    return total;
  }

  int get _remainingPoints => widget.maxPoints - _usedPoints;

  // Cost to reach a certain score from 8
  int _calculateCost(int score) {
    // Standard 5e Point Buy logic extended
    // 8: 0
    // 9-13: 1 pt each
    // 14-15: 2 pts each
    // 16-17: 3 pts each (Extrapolated)
    // 18+: 4 pts each (Extrapolated)

    if (score <= 8) return 0;
    int cost = 0;
    for (int i = 9; i <= score; i++) {
      if (i <= 13) {
        cost += 1;
      } else if (i <= 15) {
        cost += 2;
      } else if (i <= 17) {
        cost += 3;
      } else {
        cost += 4; // High cost for super stats
      }
    }
    return cost;
  }

  // Cost to increase from current to next
  int _costToIncrease(int currentScore) {
    final nextScore = currentScore + 1;
    if (nextScore <= 13) return 1;
    if (nextScore <= 15) return 2;
    if (nextScore <= 17) return 3;
    return 4;
  }

  void _increaseStat(String stat) {
    final current = _stats[stat]!;
    if (current >= widget.maxAttribute) return;

    final cost = _costToIncrease(current);

    // In Custom mode/High budget, we might allow going negative or just have high budget.
    // If maxPoints is huge (e.g. 999), we assume basically infinite.
    final ignoreCost = widget.maxPoints > 500;

    if (ignoreCost || _remainingPoints >= cost) {
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
    if (score >= 18) return Colors.purpleAccent;
    if (score >= 16) return Colors.orangeAccent;
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
                  'Ability Scores',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.maxPoints <
                    500) // Hide points if "Infinite" (Custom)
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
                      'Points: $_remainingPoints / ${widget.maxPoints}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const Text("Sandbox Mode (Unlimited)",
                      style: TextStyle(color: Colors.amber)),
              ],
            ),
            const SizedBox(height: 16),
            ..._stats.entries.map((entry) {
              final stat = entry.key;
              final score = entry.value;
              final costNext = _costToIncrease(score);
              final canAfford =
                  (widget.maxPoints > 500 || _remainingPoints >= costNext) &&
                      score < widget.maxAttribute;
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
                      child: widget.maxPoints < 500
                          ? Text(
                              // Show total cost for this stat so far
                              '(${_calculateCost(score)} pts)',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.end,
                            )
                          : const SizedBox.shrink(),
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
