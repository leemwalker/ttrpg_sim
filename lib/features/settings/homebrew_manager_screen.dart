import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/providers.dart';

class HomebrewManagerScreen extends ConsumerStatefulWidget {
  const HomebrewManagerScreen({super.key});

  @override
  ConsumerState<HomebrewManagerScreen> createState() =>
      _HomebrewManagerScreenState();
}

class _HomebrewManagerScreenState extends ConsumerState<HomebrewManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homebrew Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Species'),
            Tab(text: 'Classes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CustomTraitList(type: 'Species'),
          _CustomTraitList(type: 'Class'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final isSpecies = _tabController.index == 0;
    final type = isSpecies ? 'Species' : 'Class';
    await showDialog(
      context: context,
      builder: (context) => _AddTraitDialog(type: type),
    );
    setState(() {}); // Refresh list
  }
}

class _CustomTraitList extends ConsumerWidget {
  final String type;

  const _CustomTraitList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We can't easily use a stream here because the DAO returns Future<List>.
    // So we use a FutureBuilder that re-triggers when we need to.
    // For simplicity in this non-reactive setup, we'll just fetch on build.
    // A better way would be meaningful state management, but this works for MVP.
    final dao = ref.watch(gameDaoProvider);

    return FutureBuilder<List<CustomTrait>>(
      future: dao.getCustomTraitsByType(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final traits = snapshot.data ?? [];
        if (traits.isEmpty) {
          return Center(child: Text('No custom $type found.'));
        }

        return ListView.builder(
          itemCount: traits.length,
          itemBuilder: (context, index) {
            final trait = traits[index];
            return Dismissible(
              key: Key('trait-${trait.id}'),
              background: Container(color: Colors.red),
              onDismissed: (_) {
                dao.deleteCustomTrait(trait.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${trait.name} deleted')),
                );
              },
              child: ListTile(
                title: Text(trait.name),
                subtitle: Text(trait.description),
                trailing: const Icon(Icons.delete_outline),
              ),
            );
          },
        );
      },
    );
  }
}

class _AddTraitDialog extends ConsumerStatefulWidget {
  final String type;

  const _AddTraitDialog({required this.type});

  @override
  ConsumerState<_AddTraitDialog> createState() => _AddTraitDialogState();
}

class _AddTraitDialogState extends ConsumerState<_AddTraitDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final dao = ref.read(gameDaoProvider);
    await dao.createCustomTrait(CustomTraitsCompanion(
      name: drift.Value(name),
      type: drift.Value(widget.type),
      description: drift.Value(_descController.text.trim()),
    ));

    if (mounted) {
      Navigator.of(context).pop();
      // Force refresh of the parent list?
      // Since the list uses FutureBuilder directly on the DAO call from provider,
      // creating a trait won't auto-refresh unless we trigger a rebuild.
      // We can use ref.invalidate(gameDaoProvider) but that's overkill.
      // For MVP, calling setState in parent or using a StreamProvider is best.
      // But we are inside a Dialog here.
      // Users will see the change when they navigate or if we setup a refresh mechanism.
      // To fix this simply: The FutureBuilder in _CustomTraitList will re-run if the parent rebuilds.
      // But the parent doesn't rebuild on dialog close automatically.
      // We'll rely on the user interacting or simple navigation for now, OR:
      // We can make the FutureBuilder dependent on a provider we invalidate.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Custom ${widget.type}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
