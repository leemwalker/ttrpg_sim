import 'package:flutter/material.dart';
import 'package:ttrpg_sim/core/database/database.dart';

class Imagin8CardWidget extends StatelessWidget {
  final Imagin8Card card;
  final VoidCallback? onTap;
  final bool isSelectable;

  const Imagin8CardWidget({
    super.key,
    required this.card,
    this.onTap,
    this.isSelectable = true,
  });

  Color _getBorderColor(String type) {
    switch (type.toLowerCase()) {
      case 'ability':
        return Colors.purple;
      case 'item':
        return Colors.blue;
      case 'skill':
        return Colors.green;
      case 'trait':
        return Colors.amber;
      case 'drawback':
        return Colors.red;
      case 'origin':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor(card.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        height: 240,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: Text(
                card.type.toUpperCase(),
                style: TextStyle(
                  color: borderColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          card.description,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
