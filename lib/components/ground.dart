import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class Ground extends SpriteComponent
    with HasGameRef<FlappyBirdGame>, CollisionCallbacks {
  Ground() : super();

  @override
  Future<void> onLoad() async {
    size = Vector2(2 * gameRef.size.x, groundHeight);
    position = Vector2(0, gameRef.size.y - groundHeight);
    sprite = await Sprite.load('ground.png');
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState != GameState.playing) return;

    // Tăng tốc độ theo thời gian chơi
    position.x -= groundScrollingSpeed * dt * gameRef.speedMultiplier;

    if (position.x <= -gameRef.size.x) {
      position.x = 0;
    }
  }
}
