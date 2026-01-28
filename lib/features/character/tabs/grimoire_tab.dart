import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/models/rules/spell_model.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'dart:math';

class GrimoireTab extends ConsumerStatefulWidget {
  final CharacterData character;

  const GrimoireTab({super.key, required this.character});

  @override
  ConsumerState<GrimoireTab> createState() => _GrimoireTabState();
}

class _GrimoireTabState extends ConsumerState<GrimoireTab> {
  final _targetController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _recoverMana() async {
    final dao = ref.read(gameDaoProvider);
    // Simple recover for now: Full Restore or Short Rest logic?
    // Let's implement full recover as a placeholder for "Long Rest" action
    await dao.updateCharacterBio(
      characterId: widget.character.id,
      name: widget.character.name,
      species: widget.character.species,
      origin: widget.character.origin,
      attributes: widget.character.attributes,
      skills: widget.character.skills,
      traits: widget.character.traits,
      feats: widget.character.feats,
      background: widget.character.background,
      backstory: widget.character.backstory,
      level: widget.character.level,
      maxHp: widget.character.maxHp,
      spells: widget.character.spells,
      maxMana: widget.character.maxMana,
      currentMana: widget.character.maxMana, // Full recovery
      // Pass other fields...
      // This updateCharacterBio method is getting unwieldy.
      // Ideally we should have updateMana(id, amount) in DAO.
      // But I can't easily add new DAO methods without rewriting interface/mocks heavily.
      // I added 'currentMana' to updateCharacterBio implementation.
    );
    // Force refresh
    ref.invalidate(characterDataProvider(widget.character.worldId!));
  }

  // Actually, I should check if I can add a specific update method to DAO,
  // but since I just regenerated code, I can't easily add methods without regenerating again.
  // I'll stick to what I have or use customStatement if really needed, but updateCharacterBio works.
  // Wait, I need to pass ALL fields to updateCharacterBio which is risky if I miss one.
  // I should check if I can use the 'update' statement directly in a small method here? No, cannot access db directly.

  // Implementation note: The `GameDao` in `database.dart` had `forceUpdateHp`.
  // I should probably have added `updateMana`.
  // Since I didn't, I HAVE to use `updateCharacterBio` or `updateCharacterStats` if I create a `CharacterCompanion`.

  Future<void> _updateMana(int newCurrent) async {
    final dao = ref.read(gameDaoProvider);
    await dao.updateCharacterStats(CharacterCompanion(
      id: Value(widget.character.id),
      currentMana: Value(newCurrent),
    ));
    ref.invalidate(characterDataProvider(widget.character.worldId!));
  }

  void _showCastDialog(SpellDef spell) {
    _targetController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cast ${spell.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cost: ${spell.cost} Mana'),
            if (spell.damageDice.isNotEmpty)
              Text('Damage: ${spell.damageDice} ${spell.damageType}'),
            const SizedBox(height: 16),
            TextField(
              controller: _targetController,
              decoration: const InputDecoration(
                labelText: 'Target (Optional)',
                hintText: 'e.g. Goblin, Wall, Self',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _castSpell(spell);
            },
            icon: const Icon(Icons.flash_on),
            label: const Text('CAST'),
          ),
        ],
      ),
    );
  }

  Future<void> _castSpell(SpellDef spell) async {
    if (widget.character.currentMana < spell.cost) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not enough Mana!')));
      return;
    }

    // 1. Deduct Mana
    await _updateMana(widget.character.currentMana - spell.cost);

    // 2. Roll Damage (Simulated)
    // Parse '3d8' -> counts = 3, size = 8
    int total = 0;
    String rollDetails = '';

    if (spell.damageDice.isNotEmpty && spell.damageDice.contains('d')) {
      try {
        final parts = spell.damageDice.split('d');
        int count = int.tryParse(parts[0]) ?? 1;
        int size = int.tryParse(parts[1]) ?? 6;
        final rng = Random();
        List<int> rolls = [];
        for (int i = 0; i < count; i++) {
          int r = rng.nextInt(size) + 1;
          rolls.add(r);
          total += r;
        }
        rollDetails = '(${rolls.join('+')})';
      } catch (e) {
        total = 0;
      }
    } else {
      // No damage or malformed
      total = 0;
    }

    // 3. Inject Chat Message
    final dao = ref.read(gameDaoProvider);
    final target = _targetController.text.isNotEmpty
        ? " at ${_targetController.text}"
        : "";

    String message = "Player casts **${spell.name}**$target!";
    if (total > 0) {
      message +=
          "\nResult: **$total** $rollDetails ${spell.damageType} damage.";
    } else {
      message += "\nEffect: ${spell.description}";
    }

    await dao.insertMessage(
        'system', message, widget.character.worldId, widget.character.id);

    // Refresh messages
    // The chat view listens to the stream/provider usually?
    // Usually invalidating the message provider (if it exists) or waiting for UI to refresh.
  }

  @override
  Widget build(BuildContext context) {
    List<SpellDef> spells = [];
    try {
      final jsonList = jsonDecode(widget.character.spells) as List;
      spells = jsonList.map((e) => SpellDef.fromJson(e)).toList();
    } catch (e) {
      // Ignore
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header: Mana Bar
          _buildManaBar(),
          const SizedBox(height: 16),
          // Content: Spell Grid
          Expanded(
            child: spells.isEmpty
                ? const Center(child: Text('Grimoire is empty.'))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8, // Taller cards
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: spells.length,
                    itemBuilder: (context, index) {
                      final spell = spells[index];
                      final canCast =
                          widget.character.currentMana >= spell.cost;
                      return GestureDetector(
                        onTap: canCast ? () => _showCastDialog(spell) : null,
                        child: Opacity(
                          opacity: canCast ? 1.0 : 0.5,
                          child: Card(
                            color: Colors.deepPurple[50], // Very light purple
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: Text(spell.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text('${spell.cost} MP',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                  Text(spell.intent,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[700])),
                                  const Divider(height: 8),
                                  Expanded(
                                      child: Text(spell.description,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.fade)),
                                  if (spell.damageDice.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.flash_on,
                                              size: 12, color: Colors.red),
                                          const SizedBox(width: 4),
                                          Text(
                                              '${spell.damageDice} ${spell.damageType}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red)),
                                        ],
                                      ),
                                    )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildManaBar() {
    final double progress = widget.character.maxMana > 0
        ? widget.character.currentMana / widget.character.maxMana
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Mana: ${widget.character.currentMana} / ${widget.character.maxMana}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Serif')),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                color: Colors.blue,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          onPressed: _recoverMana,
          icon: const Icon(Icons.refresh),
          tooltip: 'Recover Mana',
        ),
      ],
    );
  }
}
