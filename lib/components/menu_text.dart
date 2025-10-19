import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/constants.dart' show GameState;
import 'package:flutter_flappy_bird/game.dart';
import 'package:flutter_flappy_bird/scenes/scene_manager.dart';

class MenuText extends PositionComponent with HasGameRef<FlappyBirdGame> {
  static const _buttonSpacing = 20.0;
  static const _titleButtonSpacing = 60.0;

  @override
  FutureOr<void> onLoad() async {
    final titleText = _createTitleText();
    add(titleText);

    final buttonWidth = titleText.width * 0.8;
    final playOfflineButton = PlayOfflineButton(
      position: Vector2(0, titleText.height + _titleButtonSpacing),
      buttonWidth: buttonWidth,
    );
    add(playOfflineButton);

    final findMatchButton = FindMatchButton(
      position: Vector2(
        0,
        playOfflineButton.y + playOfflineButton.height + _buttonSpacing,
      ),
      buttonWidth: buttonWidth,
    );
    add(findMatchButton);

    _centerButtons(titleText, [playOfflineButton, findMatchButton]);
    _positionMenu(titleText, findMatchButton);
  }

  TextComponent _createTitleText() {
    return TextComponent(
      text: 'FLAPPY BIRD',
      textRenderer: TextPaint(
        style: TextStyle(
          color: const Color(0xFFFFCC00),
          fontSize: 56,
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
  }

  void _centerButtons(TextComponent title, List<PositionComponent> buttons) {
    for (final button in buttons) {
      button.x = (title.width - button.size.x) / 2;
    }
  }

  void _positionMenu(TextComponent title, PositionComponent lastButton) {
    size = Vector2(title.width, lastButton.y + lastButton.height);
    position = Vector2(
      (gameRef.size.x - size.x) / 2,
      (gameRef.size.y - size.y) / 2,
    );
  }
}

abstract class MenuButton extends PositionComponent
    with TapCallbacks, HasGameRef<FlappyBirdGame> {
  static const _buttonHeight = 60.0;
  static const _borderRadius = 15.0;
  static const _fontSize = 28.0;
  static const _borderWidth = 3.0;

  final double buttonWidth;
  bool isPressed = false;

  MenuButton({required super.position, required this.buttonWidth})
    : super(size: Vector2.zero(), priority: 100);

  String get buttonText;
  Color get buttonColor;
  void onButtonTap();

  @override
  FutureOr<void> onLoad() async {
    size = Vector2(buttonWidth, _buttonHeight);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(_borderRadius),
    );

    _drawShadow(canvas, rect);
    _drawButton(canvas, rect);
    _drawBorder(canvas, rect);
    _drawText(canvas);
  }

  void _drawShadow(Canvas canvas, RRect rect) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rect.shift(const Offset(0, 4)), shadowPaint);
  }

  void _drawButton(Canvas canvas, RRect rect) {
    final buttonPaint = Paint()
      ..color = isPressed ? buttonColor.withOpacity(0.8) : buttonColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, buttonPaint);
  }

  void _drawBorder(Canvas canvas, RRect rect) {
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;
    canvas.drawRRect(rect, borderPaint);
  }

  void _drawText(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: buttonText,
        style: TextStyle(
          color: Colors.white,
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(2, 2),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    isPressed = true;
    onButtonTap();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    isPressed = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    isPressed = false;
  }
}

class PlayOfflineButton extends MenuButton {
  PlayOfflineButton({required super.position, required super.buttonWidth});

  @override
  String get buttonText => 'CHƠI OFFLINE';

  @override
  Color get buttonColor => Colors.green.shade600;

  @override
  void onButtonTap() {
    if (gameRef.gameState == GameState.menu) {
      gameRef.sceneManager.switchTo(
        SceneType.gameplay,
        params: {'isMultiplayer': false},
      );
    }
  }
}

class FindMatchButton extends MenuButton {
  FindMatchButton({required super.position, required super.buttonWidth});

  @override
  String get buttonText => 'TÌM TRẬN ĐẤU';

  @override
  Color get buttonColor => Colors.blue.shade600;

  @override
  void onButtonTap() {
    gameRef.startMatchmaking();
  }
}
