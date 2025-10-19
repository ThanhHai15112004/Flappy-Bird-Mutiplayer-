import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/game.dart';

class Pipe extends SpriteComponent
    with CollisionCallbacks, HasGameRef<FlappyBirdGame> {
  Pipe({
    required Vector2 position,
    required Vector2 size,
    required this.isTopPipe,
  }) : super(position: position, size: size);

  final bool isTopPipe;
  bool scored = false;

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load(isTopPipe ? 'pipe-top.png' : 'pipe-bottom.png');
    add(RectangleHitbox());
  }
}
