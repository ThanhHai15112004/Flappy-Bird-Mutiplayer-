import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class BackgroundParallax extends ParallaxComponent<FlappyBirdGame> {
  @override
  Future<void> onLoad() async {
    position = Vector2.zero();
    size = game.size;

    parallax = await game.loadParallax(
      [ParallaxImageData('background.png')],
      baseVelocity: Vector2(20, 0),
      repeat: ImageRepeat.repeatX,
      fill: LayerFill.height,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (game.gameState == GameState.playing) {
      parallax?.baseVelocity = Vector2(groundScrollingSpeed * 0.2, 0);
    } else {
      parallax?.baseVelocity = Vector2.zero();
    }
  }
}
