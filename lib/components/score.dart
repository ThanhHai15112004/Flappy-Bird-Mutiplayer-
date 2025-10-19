import 'dart:async';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_flappy_bird/game.dart';

class ScoreText extends TextComponent with HasGameRef<FlappyBirdGame> {
  ScoreText()
    : super(
        text: '0',
        textRenderer: TextPaint(
          style: TextStyle(
            color: const Color(0xFF424242),
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  @override
  FutureOr<void> onLoad() {
    position = Vector2((gameRef.size.x - size.x) / 2, gameRef.size.y * 0.9);
  }

  @override
  void update(double dt) {
    if (text != gameRef.score.toString()) {
      text = gameRef.score.toString();
    }
  }
}
