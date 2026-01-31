import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ttrpg_sim/features/settings/settings_provider.dart';
import 'package:ttrpg_sim/features/settings/paid_key_usage_mode.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _paidApiKeyController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _paidApiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _paidApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // Sync controllers with state
    if (_apiKeyController.text.isEmpty && settings.apiKey != null) {
      _apiKeyController.text = settings.apiKey!;
    }
    if (_paidApiKeyController.text.isEmpty && settings.paidApiKey != null) {
      _paidApiKeyController.text = settings.paidApiKey!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ===== APPEARANCE =====
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

          // ===== AI ENGINE =====
          _buildSectionHeader('AI Engine'),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key (Free)',
              hintText: 'Enter your API Key',
              border: OutlineInputBorder(),
              helperText: 'Required - Get your key at aistudio.google.com',
            ),
            obscureText: true,
            onChanged: (value) {
              notifier.setApiKey(value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: settings.modelName,
            decoration: const InputDecoration(
              labelText: 'AI GM Model',
              border: OutlineInputBorder(),
            ),
            items: _buildModelDropdownItems(settings.modelName),
            onChanged: (value) {
              if (value != null) {
                notifier.setModel(value);
              }
            },
          ),

          const SizedBox(height: 24),

          // ===== PAID API KEY =====
          _buildSectionHeader('Paid API Key'),
          const SizedBox(height: 8),
          TextField(
            controller: _paidApiKeyController,
            decoration: const InputDecoration(
              labelText: 'Paid Gemini API Key',
              hintText: 'Enter paid API Key (optional)',
              border: OutlineInputBorder(),
              helperText: 'Used for ghostwriting or as fallback',
            ),
            obscureText: true,
            onChanged: (value) {
              notifier.setPaidApiKey(value);
            },
          ),
          const SizedBox(height: 16),

          // Usage Mode
          Text('Usage Mode', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          SegmentedButton<PaidKeyUsageMode>(
            segments: PaidKeyUsageMode.values.map((mode) {
              return ButtonSegment(
                value: mode,
                label: Text(mode.displayName),
                tooltip: mode.description,
              );
            }).toList(),
            selected: {settings.paidKeyMode},
            onSelectionChanged: (Set<PaidKeyUsageMode> newSelection) {
              notifier.setPaidKeyMode(newSelection.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            settings.paidKeyMode.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          // Rate Slider (only shown for rate-based mode)
          if (settings.paidKeyMode == PaidKeyUsageMode.rateBased) ...[
            const SizedBox(height: 16),
            Text(
              'Rate: ${settings.paidKeyRate.toStringAsFixed(1)} times/minute',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: settings.paidKeyRate,
              min: 0.1,
              max: 10.0,
              divisions: 99, // 0.1 increments
              label: settings.paidKeyRate.toStringAsFixed(1),
              onChanged: (value) {
                notifier.setPaidKeyRate(value);
              },
            ),
            Text(
              _getRateDescription(settings.paidKeyRate),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],

          const SizedBox(height: 24),

          // ===== GHOSTWRITING =====
          _buildSectionHeader('Ghostwriting (LitRPG Studio)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: settings.ghostwritingModel,
            decoration: const InputDecoration(
              labelText: 'Ghostwriting Model',
              border: OutlineInputBorder(),
              helperText: 'Model used for novel generation',
            ),
            items: _buildModelDropdownItems(settings.ghostwritingModel),
            onChanged: (value) {
              if (value != null) {
                notifier.setGhostwritingModel(value);
              }
            },
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildModelDropdownItems(String currentValue) {
    const standardModels = [
      ('models/gemini-2.5-flash', 'Gemini 2.5 Flash'),
      ('models/gemini-2.5-pro', 'Gemini 2.5 Pro'),
      ('models/gemini-2.0-flash-exp', 'Gemini 2.0 Flash Exp'),
    ];

    final items = standardModels.map((m) {
      return DropdownMenuItem(
        value: m.$1,
        child: Text(m.$2),
      );
    }).toList();

    // Safety fallback: If the stored model isn't in our standard list, add it.
    if (!standardModels.any((m) => m.$1 == currentValue)) {
      items.add(DropdownMenuItem(
        value: currentValue,
        child: Text(currentValue),
      ));
    }

    return items;
  }

  String _getRateDescription(double rate) {
    if (rate < 1.0) {
      final minutes = (1.0 / rate).round();
      return 'Paid key used once every ~$minutes minutes';
    } else if (rate == 1.0) {
      return 'Paid key used once per minute';
    } else {
      final seconds = (60.0 / rate).round();
      return 'Paid key used every ~$seconds seconds';
    }
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
