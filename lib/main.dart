import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/Widgets/spectator_overlay.dart';
import 'package:flutter_flappy_bird/game.dart';
import 'package:flutter_flappy_bird/nakama_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final nakamaManager = NakamaManager();
  nakamaManager.initialize();
  await nakamaManager.authenticate();

  runApp(MyApp(nakamaManager: nakamaManager));
}

class MyApp extends StatelessWidget {
  final NakamaManager nakamaManager;
  const MyApp({super.key, required this.nakamaManager});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {}
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameWidget(
        game: FlappyBirdGame(nakamaManager: nakamaManager),
        overlayBuilderMap: {
          'SpectatorOverlay': (_, game) => const SpectatorOverlay(),
        },
      ),
    );
  }
}
