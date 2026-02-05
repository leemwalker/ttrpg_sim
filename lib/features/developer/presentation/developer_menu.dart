import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:ttrpg_sim/core/database/database.dart';

class DeveloperMenu extends ConsumerStatefulWidget {
  const DeveloperMenu({super.key});

  @override
  ConsumerState<DeveloperMenu> createState() => _DeveloperMenuState();
}

class _DeveloperMenuState extends ConsumerState<DeveloperMenu> {
  bool _isLoading = false;
  String? _statusMessage;
  String _selectedSystem = 'd20';

  void _runOperation(String name, Future<void> Function() operation) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Running $name...";
    });

    try {
      final stopwatch = Stopwatch()..start();
      await operation();
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _statusMessage =
              "$name completed in ${stopwatch.elapsedMilliseconds}ms";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "$name completed in ${stopwatch.elapsedMilliseconds}ms")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<int?> _getLastCharacterId() async {
    final dao = ref.read(gameDaoProvider);
    final chars = await dao.getAllCharacters();
    if (chars.isEmpty) return null;
    return chars.last.id;
  }

  Future<int?> _getWorldIdForCharacter(int charId) async {
    final dao = ref.read(gameDaoProvider);
    final char = await dao.getCharacterById(charId);
    return char?.worldId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Developer Tools"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.grey.shade200,
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            const Text(
              "Stress Tests",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runOperation("Inject 1,000 Turns", () async {
                        final charId = await _getLastCharacterId();
                        if (charId == null) throw "No character found";
                        final worldId = await _getWorldIdForCharacter(charId);
                        if (worldId == null) throw "No world found";

                        await ref
                            .read(stressTestServiceProvider)
                            .generateCampaignData(
                              turnCount: 1000,
                              worldId: worldId,
                              characterId: charId,
                            );
                      }),
              child: const Text("Inject 1,000 Turns (Novel)"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runOperation("Inject 5,000 Turns", () async {
                        final charId = await _getLastCharacterId();
                        if (charId == null) throw "No character found";
                        final worldId = await _getWorldIdForCharacter(charId);
                        if (worldId == null) throw "No world found";

                        await ref
                            .read(stressTestServiceProvider)
                            .generateCampaignData(
                              turnCount: 5000,
                              worldId: worldId,
                              characterId: charId,
                            );
                      }),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Inject 5,000 Turns (Saga) - WARNING"),
            ),
            const SizedBox(height: 16),
            const Text(
              "World Population",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runOperation("Populate World", () async {
                        final charId = await _getLastCharacterId();
                        if (charId == null) throw "No character found";
                        final worldId = await _getWorldIdForCharacter(charId);
                        if (worldId == null) throw "No world found";

                        await ref.read(stressTestServiceProvider).populateWorld(
                              locationCount: 50,
                              npcCount: 500,
                              worldId: worldId,
                            );
                      }),
              child: const Text("Populate 500 NPCs"),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runOperation("Spam Quests", () async {
                        final charId = await _getLastCharacterId();
                        if (charId == null) throw "No character found";
                        final worldId = await _getWorldIdForCharacter(charId);
                        if (worldId == null) throw "No world found";

                        await ref.read(stressTestServiceProvider).spamQuests(
                              count: 1000,
                              worldId: worldId,
                            );
                      }),
              child: const Text("Inject 1,000 Quests"),
            ),
            const SizedBox(height: 16),
            const Text(
              "Benchmarks",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runOperation("Context Benchmark", () async {
                        final charId = await _getLastCharacterId();
                        if (charId == null) throw "No character found";
                        final worldId = await _getWorldIdForCharacter(charId);
                        if (worldId == null) throw "No world found";

                        final result = await ref
                            .read(benchmarkServiceProvider)
                            .measureContextLoad(worldId, charId);

                        // We update status in _runOperation, but here we return helpful string?
                        // _runOperation measures time of execution.
                        // But measureContextLoad returns a string report.
                        // We should probably show that report.

                        if (mounted) {
                          setState(() {
                            _statusMessage = result;
                          });
                        }
                      }),
              child: const Text("Run Context Benchmark"),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Text(
              "Campaign Management",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("System: "),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedSystem,
                  items: ['d20', 'imagin8']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSystem = val);
                  },
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _runOperation("Create Test Campaign", () async {
                        final dao = ref.read(gameDaoProvider);
                        final worldId =
                            await dao.createWorld(WorldsCompanion.insert(
                          name: "Test ${_selectedSystem.toUpperCase()} World",
                          genre: "Fantasy",
                          description: "Stress test world",
                          system: Value(_selectedSystem),
                          selectedDecks: Value(_selectedSystem == 'imagin8'
                              ? '["Fantasy"]'
                              : null),
                        ));

                        await dao
                            .updateCharacterStats(CharacterCompanion.insert(
                          name: "Test Hero",
                          worldId: Value(worldId),
                          level: 1,
                          currentHp: 10,
                          maxHp: 10,
                          gold: 100,
                          location: "Start",
                          species: const Value("Human"),
                          origin: const Value("Adventurer"),
                        ));

                        if (mounted) {
                          setState(() {
                            _statusMessage =
                                "Created $_selectedSystem campaign (World ID: $worldId)";
                          });
                        }
                      }),
              child: const Text("Create Test Campaign"),
            ),
          ],
        ),
      ),
    );
  }
}
