import 'package:flutter_flappy_bird/game.dart';
import 'package:flutter_flappy_bird/scenes/base_scene.dart';
import 'package:flutter_flappy_bird/scenes/menu_scene.dart';
import 'package:flutter_flappy_bird/scenes/gameplay_scene.dart';

enum SceneType { menu, gameplay }

class SceneManager {
  final FlappyBirdGame game;
  BaseScene? _currentScene;

  SceneManager(this.game);

  BaseScene? get currentScene => _currentScene;

  Future<void> switchTo(SceneType type, {Map<String, dynamic>? params}) async {
    await _exitCurrentScene();

    _currentScene = switch (type) {
      SceneType.menu => MenuScene(),
      SceneType.gameplay => GameplayScene(
        isMultiplayer: params?['isMultiplayer'] ?? false,
      ),
    };

    await game.add(_currentScene!);
  }

  Future<void> reset() async {
    await _exitCurrentScene();
    _currentScene = null;
  }

  // Helper: Thoát scene hiện tại
  Future<void> _exitCurrentScene() async {
    if (_currentScene == null) return;
    await _currentScene!.onExit();
    _currentScene!.removeFromParent();
  }
}
