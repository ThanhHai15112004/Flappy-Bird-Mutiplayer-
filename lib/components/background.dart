import 'dart:async';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class Background extends PositionComponent with HasGameRef<FlappyBirdGame> {
  Background(Vector2 size) : super(size: size, position: Vector2(0, 0));

  late SpriteComponent _bg1;
  late SpriteComponent _bg2;

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load('background.png');

    _bg1 = SpriteComponent(
      sprite: sprite,
      size: size,
      position: Vector2.zero(),
    );
    await add(_bg1);

    _bg2 = SpriteComponent(
      sprite: sprite,
      size: size,
      position: Vector2(size.x, 0),
    );
    await add(_bg2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.gameState != GameState.playing) return;

    final scrollSpeed =
        groundScrollingSpeed * dt * 0.2 * gameRef.speedMultiplier;

    _bg1.position.x -= scrollSpeed;
    _bg2.position.x -= scrollSpeed;

    if (_bg1.position.x <= -size.x) {
      _bg1.position.x = _bg2.position.x + size.x;
    }

    if (_bg2.position.x <= -size.x) {
      _bg2.position.x = _bg1.position.x + size.x;
    }
  }
}
