import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ttrpg_sim/features/game/state/game_controller.dart';

import 'package:ttrpg_sim/features/game/presentation/drawer/character_drawer.dart';

class GameScreen extends ConsumerStatefulWidget {
  final int worldId;
  final int characterId;
  const GameScreen(
      {super.key, required this.worldId, required this.characterId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;
    _textController.clear();
    ref
        .read(
            gameControllerProvider(widget.worldId, widget.characterId).notifier)
        .submitAction(text);
  }

  void _showAnalysisDialog() async {
    final controller = ref.read(
        gameControllerProvider(widget.worldId, widget.characterId).notifier);

    // show loading dialog first or just let the future resolve?
    // Simple FutureBuilder dialog pattern
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Narrative Analysis"),
            content: FutureBuilder<String>(
                future: controller.runStoryAnalysis(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Consulting the oracle..."),
                        ]);
                  }
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }
                  return SingleChildScrollView(
                    child: MarkdownBody(
                        data: snapshot.data ?? "No analysis available."),
                  );
                }),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close")),
            ],
          );
        });
  }

  void _showPublishingStudioDialog(int wordCount) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("LitRPG Book Studio"),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  "You have written $wordCount words! Your story is ready to be immortalized as a novel."),
              const SizedBox(height: 16),
              const Text(
                  "This process will rewrite your chat log into a cohesive narrative, complete with stat boxes and proper formatting."),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    ref
                        .read(gameControllerProvider(
                                widget.worldId, widget.characterId)
                            .notifier)
                        .exportBook();
                  },
                  child: const Text("Generate & Export PDF")),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final gameState =
        ref.watch(gameControllerProvider(widget.worldId, widget.characterId));

    // Listen for errors
    ref.listen(gameControllerProvider(widget.worldId, widget.characterId),
        (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                next.error.toString().replaceFirst('AppBaseException: ', '')),
            backgroundColor: Colors.red,
          ),
        );
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            if (gameState.valueOrNull?.isGeneratingBook == true)
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text("Generating Novel...",
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(gameState.valueOrNull?.generationStatus ?? "",
                          style: const TextStyle(color: Colors.white70)),
                    ]),
              )
            else
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Direct access to state value (or null if loading/error)
                    final stateValue = gameState.valueOrNull;
                    final isLoading = gameState.isLoading;
                    final hasError = gameState.hasError;

                    // Initial loading state (no data yet)
                    if (stateValue == null && isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Error state with no data
                    if (stateValue == null && hasError) {
                      return Center(child: Text("Error: ${gameState.error}"));
                    }

                    // Empty state (data loaded but empty)
                    if (stateValue != null &&
                        stateValue.messages.isEmpty &&
                        !isLoading) {
                      return const Center(
                          child: Text("Start your adventure..."));
                    }

                    final messages = stateValue?.messages ?? [];

                    // items = messages + (optional typing indicator)
                    final itemCount = messages.length + (isLoading ? 1 : 0);

                    return ListView.builder(
                      reverse: true, // Bottom-up
                      padding: const EdgeInsets.all(16.0),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        // Logic: Index 0 is bottom.
                        // If loading, Index 0 is Typing Indicator.
                        // Messages use index - (1 if loading).

                        if (isLoading && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text("Gamemaster is thinking...",
                                    style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey)),
                              ],
                            ),
                          );
                        }

                        final msgIndex = isLoading ? index - 1 : index;
                        // Safe check
                        if (msgIndex < 0 || msgIndex >= messages.length)
                          return const SizedBox();

                        final msg = messages[msgIndex];
                        final isUser = msg.role.name == 'user';
                        final colorScheme = Theme.of(context).colorScheme;

                        final backgroundColor = isUser
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest;

                        final textColor = isUser
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant;

                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
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
                                      MediaQuery.of(context).size.width * 0.8),
                              child: MarkdownBody(
                                data: msg.content,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(color: textColor),
                                  strong: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            if (gameState.valueOrNull?.isGeneratingBook != true)
              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Book Studio Progress Bar
                    if (gameState.valueOrNull != null)
                      InkWell(
                        onTap: () {
                          final wc = gameState.valueOrNull!.wordCount;
                          final comp = gameState.valueOrNull!.bookCompletion;
                          if (comp >= 1.0) {
                            _showPublishingStudioDialog(wc);
                          } else {
                            _showAnalysisDialog();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          "Novel Progress: ${gameState.valueOrNull!.wordCount} words",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      if (gameState
                                              .valueOrNull!.bookCompletion >=
                                          1.0)
                                        const Text("READY TO PUBLISH",
                                            style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10))
                                    ]),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: gameState.valueOrNull!.bookCompletion,
                                  backgroundColor: Colors.grey[800],
                                  // Color shift logic: Red -> Yellow -> Green
                                  color: HSVColor.fromAHSV(
                                          1.0,
                                          (gameState.valueOrNull!
                                                      .bookCompletion *
                                                  120)
                                              .clamp(0, 120)
                                              .toDouble(),
                                          1.0,
                                          1.0)
                                      .toColor(),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ]),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              textInputAction: TextInputAction.send,
                              decoration: const InputDecoration(
                                hintText: 'What do you do?',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: _handleSubmitted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () =>
                                _handleSubmitted(_textController.text),
                            tooltip: 'Send Message',
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
