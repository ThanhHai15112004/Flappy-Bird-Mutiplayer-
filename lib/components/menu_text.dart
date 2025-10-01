import 'dart:async';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/game.dart';

class MenuText extends PositionComponent with HasGameRef<FlappyBirdGame> {
  MenuText() : super();

  @override
  FutureOr<void> onLoad() async {
    final titleText = TextComponent(
      text: 'FLAPPY BIRD',
      textRenderer: TextPaint(
        style: TextStyle(
          color: const Color(0xFFFFCC00),
          fontSize: 56, // Kích thước lớn hơn
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          shadows: [
            Shadow(
              offset: const Offset(5, 5),
              blurRadius: 0,
              color: Colors.black.withOpacity(0.9),
            ),
          ],
        ),
      ),
    );

    final instructionText = TextComponent(
      text: 'TAP TO START',
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(2, 2),
              blurRadius: 4,
              color: Colors.black54,
            ),
          ],
        ),
      ),
      position: Vector2(0, titleText.height + 40),
    );

    add(titleText);
    add(instructionText);

    await super.onLoad();

    instructionText.x = (titleText.width - instructionText.width) / 2;

    size = Vector2(titleText.width, instructionText.y + instructionText.height);

    position = Vector2(
      (gameRef.size.x - size.x) / 2,
      (gameRef.size.y - size.y) / 2,
    );
  }
}
