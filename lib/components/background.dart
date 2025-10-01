import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame/components.dart';

class Background extends SpriteComponent {
  //khởi tạo vị trí background
  Background(Vector2 size) : super(size: size, position: Vector2(0, 0));
  @override
  Future<void> onLoad() async {
    // load background in sprite
    sprite = await Sprite.load('background.png');
  }
}
