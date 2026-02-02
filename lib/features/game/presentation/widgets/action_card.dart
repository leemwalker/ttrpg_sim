import 'package:flutter/material.dart';

/// A unified action card widget for displaying combat actions, spells, and skill checks.
///
/// Used in:
/// - GrimoireTab: Display spells
/// - Skill Check Options: Display the "Three Card" skill check choices
/// - Combat Actions: Display attack/ability options (future)
class ActionCard extends StatelessWidget {
  /// The main title of the action (e.g., "Fireball", "Force Open")
  final String title;

  /// Secondary description or subtitle
  final String? subtitle;

  /// Icon to display (defaults to a generic action icon)
  final IconData icon;

  /// Color theme for the card accent
  final Color? accentColor;

  /// Stats or details to show (e.g., "1d8 Fire", "DC 15")
  final String? stats;

  /// Badge text (e.g., "Level 2", "STR")
  final String? badge;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Whether the card is currently disabled
  final bool disabled;

  /// Whether to show a compact version
  final bool compact;

  const ActionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.flash_on,
    this.accentColor,
    this.stats,
    this.badge,
    this.onTap,
    this.disabled = false,
    this.compact = false,
  });

  /// Factory constructor for skill check options
  factory ActionCard.skillCheck({
    Key? key,
    required String label,
    required String skill,
    required String attribute,
    required int difficulty,
    required VoidCallback onTap,
  }) {
    return ActionCard(
      key: key,
      title: label,
      subtitle: skill,
      icon: _getAttributeIcon(attribute),
      accentColor: _getAttributeColor(attribute),
      stats: 'DC $difficulty',
      badge: attribute,
      onTap: onTap,
    );
  }

  /// Factory constructor for spells
  factory ActionCard.spell({
    Key? key,
    required String name,
    required String effect,
    required int manaCost,
    String? damage,
    VoidCallback? onTap,
    bool disabled = false,
  }) {
    return ActionCard(
      key: key,
      title: name,
      subtitle: effect,
      icon: Icons.auto_awesome,
      accentColor: Colors.purple,
      stats: damage,
      badge: '$manaCost MP',
      onTap: onTap,
      disabled: disabled,
    );
  }

  static IconData _getAttributeIcon(String attribute) {
    switch (attribute.toUpperCase()) {
      case 'STR':
        return Icons.fitness_center;
      case 'DEX':
        return Icons.speed;
      case 'CON':
        return Icons.shield;
      case 'INT':
        return Icons.psychology;
      case 'WIS':
        return Icons.visibility;
      case 'CHA':
        return Icons.record_voice_over;
      default:
        return Icons.flash_on;
    }
  }

  static Color _getAttributeColor(String attribute) {
    switch (attribute.toUpperCase()) {
      case 'STR':
        return Colors.red;
      case 'DEX':
        return Colors.green;
      case 'CON':
        return Colors.orange;
      case 'INT':
        return Colors.blue;
      case 'WIS':
        return Colors.teal;
      case 'CHA':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;
    final cardColor = disabled
        ? theme.colorScheme.surfaceContainerHighest.withAlpha(128)
        : theme.colorScheme.surfaceContainerHighest;

    return Card(
      elevation: disabled ? 0 : 2,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onTap,
        splashColor: color.withAlpha(50),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: disabled ? Colors.grey : color,
                width: 4,
              ),
            ),
          ),
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (disabled ? Colors.grey : color).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: disabled ? Colors.grey : color,
                  size: compact ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: disabled ? Colors.grey : null,
                      ),
                    ),
                    if (subtitle != null && !compact)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: disabled
                              ? Colors.grey
                              : theme.textTheme.bodySmall?.color
                                  ?.withAlpha(180),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Stats & Badge
              if (stats != null || badge != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stats != null)
                      Text(
                        stats!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: disabled ? Colors.grey : color,
                        ),
                      ),
                    if (badge != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (disabled ? Colors.grey : color).withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: disabled ? Colors.grey : color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
