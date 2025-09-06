import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/mode_selection_screen.dart';
import 'services/elevenlabs_service.dart';

void main() {
  print('🚀 Flutter app starting...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ElevenLabsService(),
      child: MaterialApp(
        title: 'ElevenLabs Flutter Chat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const ModeSelectionScreen(),
      ),
    );
  }
}