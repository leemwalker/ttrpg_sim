import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ttrpg_sim/features/game/state/game_controller.dart';
import 'package:ttrpg_sim/features/game/state/game_state.dart';
import 'package:ttrpg_sim/features/game/presentation/drawer/character_drawer.dart';

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
        .read(gameControllerProvider(widget.worldId).notifier)
        .submitAction(text);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider(widget.worldId));

    // Auto-scroll when messages change
    ref.listen(gameControllerProvider(widget.worldId), (previous, next) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: "Exit World",
            onPressed: () => Navigator.pop(context),
          ),
        ],
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
                    final colorScheme = Theme.of(context).colorScheme;

                    final backgroundColor = isUser
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest;

                    final textColor = isUser
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant;

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.7),
                          child: Text(
                            msg.content,
                            style: TextStyle(color: textColor),
                          ),
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
