import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttrpg_sim/features/settings/homebrew_manager_screen.dart';
import 'package:ttrpg_sim/features/settings/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // Sync controller with state if it's empty and we have a key
    // But be careful not to overwrite user typing.
    // Ideally, we only set it once or if the state changes externally.
    // For simplicity, we'll just initialize it with the current value if the widget is rebuilding and the text is empty/different?
    // Actually, handling text controllers with Riverpod needs care.
    // We'll just set the text if the controller is empty and there is a value initially.
    if (_apiKeyController.text.isEmpty && settings.apiKey != null) {
      _apiKeyController.text = settings.apiKey!;
    }
    // Also if the user clears it, we want it explicitly empty.
    // Let's just listen to onChanged and update the provider.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.wb_sunny),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.nightlight_round),
              ),
            ],
            selected: {settings.theme},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              notifier.setTheme(newSelection.first);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('AI Engine'),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'Enter custom API Key',
              border: OutlineInputBorder(),
              helperText: 'Leave empty to use default environment key',
            ),
            obscureText: true,
            onChanged: (value) {
              notifier.setApiKey(value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: settings.modelName,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'gemini-1.5-flash',
                child: Text('Gemini 1.5 Flash'),
              ),
              DropdownMenuItem(
                value: 'gemini-1.5-pro',
                child: Text('Gemini 1.5 Pro'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                notifier.setModel(value);
              }
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Homebrew'),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Manage Custom Content'),
            subtitle: const Text('Add custom Species and Classes'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const HomebrewManagerScreen(),
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
