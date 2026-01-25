import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/providers.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';
import 'package:ttrpg_sim/features/game/state/game_state.dart';

class GameScreen extends ConsumerStatefulWidget {
  final int worldId;
  const GameScreen({super.key, required this.worldId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;
    _textController.clear();
    ref
        .read(gameControllerProvider.notifier)
        .submitAction(text, widget.worldId);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);

    // Auto-scroll when messages change
    ref.listen(gameControllerProvider, (previous, next) {
      if (next is AsyncData<GameState> && previous is AsyncData<GameState>) {
        if (next.value.messages.length > previous.value.messages.length) {
          // Slight delay to allow frame to render new item?
          // Usually plain animateTo works if the list is updated.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('TTRPG Sim'),
      ),
      drawer: CharacterDrawer(worldId: widget.worldId),
      body: Column(
        children: [
          Expanded(
            child: gameState.when(
              data: (state) {
                if (state.messages.isEmpty) {
                  return const Center(child: Text("Start your adventure..."));
                }
                // Use a ListView.builder
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final msg = state.messages[index];
                    final isUser = msg.role.name == 'user';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.7),
                          child: Text(msg.content),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'What do you do?',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _handleSubmitted(_textController.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CharacterDrawer extends ConsumerWidget {
  final int worldId;
  const CharacterDrawer({super.key, required this.worldId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('🎨 DRAWER: Rebuilding...');
    final characterAsync = ref.watch(characterDataProvider(worldId));

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text(
              "Character Sheet",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          characterAsync.when(
            data: (char) {
              if (char == null)
                return const ListTile(title: Text("No Character Data"));

              // Watch inventory only if character exists
              final inventoryAsync = ref.watch(inventoryDataProvider(char.id));

              return Column(
                children: [
                  ListTile(
                    title: Text(char.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${char.heroClass} Level ${char.level}"),
                  ),
                  ListTile(
                    title: Text("HP: ${char.currentHp}/${char.maxHp}"),
                    subtitle: LinearProgressIndicator(
                      value:
                          char.maxHp > 0 ? (char.currentHp / char.maxHp) : 0.0,
                    ),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.monetization_on, color: Colors.amber),
                    title: Text("Gold: ${char.gold}"),
                  ),
                  ListTile(
                    leading: const Icon(Icons.map, color: Colors.green),
                    title: Text("Location: ${char.location}"),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Inventory",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  inventoryAsync.when(
                    data: (items) {
                      if (items.isEmpty)
                        return const ListTile(title: Text("Empty"));
                      return Column(
                        children: items
                            .map((i) => ListTile(
                                  title: Text(i.itemName),
                                  trailing: Text("x${i.quantity}"),
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  )
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => ListTile(title: Text('Error: $err')),
          ),
        ],
      ),
    );
  }
}
