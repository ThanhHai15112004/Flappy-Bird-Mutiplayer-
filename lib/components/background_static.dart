import 'dart:async';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/game.dart';

class BackgroundStatic extends SpriteComponent with HasGameRef<FlappyBirdGame> {
  BackgroundStatic(Vector2 size) : super(size: size, position: Vector2(0, 0));

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('background.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
  }
}
