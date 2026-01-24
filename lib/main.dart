import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
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
      home: const Scaffold(
        body: Center(
          child: Text('TTRPG Sim Initialized'),
        ),
      ),
    );
  }
}
