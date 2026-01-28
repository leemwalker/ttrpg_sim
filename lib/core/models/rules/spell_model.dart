class SpellDef {
  final String name;
  final String source; // e.g., "Pyromancy"
  final String intent; // e.g., "Harm", "Ward"
  final int tier; // 1-5
  final int cost; // Calculated based on Tier
  final String description;
  final String damageDice; // e.g., "3d8"
  final String damageType; // e.g., "Fire"

  const SpellDef({
    required this.name,
    required this.source,
    required this.intent,
    required this.tier,
    required this.cost,
    required this.description,
    required this.damageDice,
    required this.damageType,
  });

  factory SpellDef.fromJson(Map<String, dynamic> json) {
    return SpellDef(
      name: json['name'] as String,
      source: json['source'] as String? ?? 'Unknown',
      intent: json['intent'] as String? ?? 'General',
      tier: json['tier'] as int? ?? 1,
      cost: json['cost'] as int? ?? 0,
      description: json['description'] as String,
      damageDice: json['damageDice'] as String? ?? '',
      damageType: json['damageType'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'source': source,
      'intent': intent,
      'tier': tier,
      'cost': cost,
      'description': description,
      'damageDice': damageDice,
      'damageType': damageType,
    };
  }
}
