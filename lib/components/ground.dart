import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class Ground extends SpriteComponent
    with HasGameRef<FlappyBirdGame>, CollisionCallbacks {
  // khởi tạo
  Ground() : super();

  /*

    load

  */

  @override
  Future<void> onLoad() async {
    // set size position
    size = Vector2(2 * gameRef.size.x, groundHeight);
    position = Vector2(0, gameRef.size.y - groundHeight);
    //load ảnh ground
    sprite = await Sprite.load('ground.png');
    //add a collision box
    add(RectangleHitbox());
  }

  /*

    update

  */

  @override
  void update(double dt) {
    // move ground to left
    position.x -= groundScrollingSpeed * dt;

    //resst ground
    if (position.x + size.x / 2 <= 0) {
      position.x = 0;
    }
  }
}
