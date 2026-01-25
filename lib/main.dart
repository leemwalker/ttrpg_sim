import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ttrpg_sim/features/menu/main_menu_screen.dart';
import 'package:ttrpg_sim/features/settings/settings_provider.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const ProviderScope(child: TtrpgSimApp()));
}

class TtrpgSimApp extends ConsumerWidget {
  const TtrpgSimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'TTRPG Sim',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settings.theme,
      home: const MainMenuScreen(),
    );
  }
}
