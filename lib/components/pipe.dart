import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class Pipe extends SpriteComponent
    with CollisionCallbacks, HasGameRef<FlappyBirdGame> {
  //determine if the pipe is top or bottom
  final bool isTopPipe;

  //score
  bool scored = false;

  //init
  Pipe(Vector2 position, Vector2 size, {required this.isTopPipe})
    : super(position: position, size: size);

  /*
  
  Load

  */

  @override
  Future<void> onLoad() async {
    // load sprite image
    sprite = await Sprite.load(isTopPipe ? 'pipe-top.png' : 'pipe-bottom.png');
    // add hit box collision
    add(RectangleHitbox());
  }

  /*
  
  update

  */

  @override
  void update(double dt) {
    if (gameRef.gameState != GameState.playing) return;
    // scroll pipe to left
    position.x -= groundScrollingSpeed * dt;

    //check if the bird has passed pipe
    if (!scored && position.x + size.x < gameRef.bird.position.x) {
      scored = true;

      if (isTopPipe) {
        gameRef.incrementScore();
        FlameAudio.play('point.mp3');
      }
    }

    //remove pipe if it goes off the screen
    if (position.x + size.x <= 0) {
      removeFromParent();
    }
  }
}
