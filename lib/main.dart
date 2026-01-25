import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ttrpg_sim/features/menu/main_menu_screen.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const ProviderScope(child: TtrpgSimApp()));
}

class TtrpgSimApp extends StatelessWidget {
  const TtrpgSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTRPG Sim',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
