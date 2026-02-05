import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';

class QuestLogWidget extends ConsumerWidget {
  final int worldId;
  const QuestLogWidget({super.key, required this.worldId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(gameDaoProvider);

    return StreamBuilder<List<Quest>>(
      stream: dao.watchQuests(worldId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final quests = snapshot.data!;
        if (quests.isEmpty) {
          return const Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text("No quests found.", style: TextStyle(color: Colors.grey)),
            ],
          ));
        }

        final active = quests.where((q) => q.status == 'active').toList();
        final completed = quests
            .where((q) => q.status == 'completed' || q.status == 'failed')
            .toList();

        // Sort active by newest first (descending ID)
        active.sort((a, b) => b.id.compareTo(a.id));
        completed.sort((a, b) => b.id.compareTo(a.id));

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.deepPurple,
                tabs: [
                  Tab(text: "Active"),
                  Tab(text: "Completed"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildQuestList(active),
                    _buildQuestList(completed),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestList(List<Quest> quests) {
    if (quests.isEmpty) {
      return const Center(
          child: Text("None", style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final q = quests[index];
        final isFailed = q.status == 'failed';
        final isCompleted = q.status == 'completed';

        Color statusColor = Colors.blue;
        if (isFailed) statusColor = Colors.red;
        if (isCompleted) statusColor = Colors.green;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(
                isFailed
                    ? Icons.close
                    : (isCompleted ? Icons.check : Icons.assignment),
                color: statusColor,
              ),
            ),
            title: Text(q.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(q.description),
              ],
            ),
            trailing: isCompleted || isFailed
                ? Chip(
                    label: Text(q.status.toUpperCase(),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: statusColor,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          ),
        );
      },
    );
  }
}
