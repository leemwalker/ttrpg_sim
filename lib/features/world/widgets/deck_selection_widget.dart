import 'package:flutter/material.dart';

class DeckSelectionWidget extends StatefulWidget {
  final List<String> availableDecks;
  final ValueChanged<List<String>> onSelectionChanged;

  const DeckSelectionWidget({
    super.key,
    this.availableDecks = const [
      'Fantasy',
      'Sci-Fi',
      'Horror',
      'Noir',
      'Steampunk'
    ],
    required this.onSelectionChanged,
  });

  @override
  State<DeckSelectionWidget> createState() => _DeckSelectionWidgetState();
}

class _DeckSelectionWidgetState extends State<DeckSelectionWidget> {
  final Set<String> _selectedDecks = {};

  void _toggleDeck(String deck) {
    setState(() {
      if (_selectedDecks.contains(deck)) {
        _selectedDecks.remove(deck);
      } else {
        _selectedDecks.add(deck);
      }
      widget.onSelectionChanged(_selectedDecks.toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Card Decks",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: widget.availableDecks.map((deck) {
            final isSelected = _selectedDecks.contains(deck);
            return FilterChip(
              label: Text(deck),
              selected: isSelected,
              onSelected: (_) => _toggleDeck(deck),
            );
          }).toList(),
        ),
        if (_selectedDecks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Please select at least one deck.",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
