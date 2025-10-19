import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/game.dart';
import 'package:nakama/nakama.dart';

class AccountInfo extends PositionComponent
    with HasGameRef<FlappyBirdGame>, TapCallbacks {
  late TextComponent _nameText;
  late SpriteComponent _birdIcon;

  AccountInfo()
    : super(
        anchor: Anchor.topRight,
        children: [
          MoveEffect.by(
            Vector2(-260, 20),
            EffectController(duration: 0.5, curve: Curves.easeOut),
          ),
        ],
      );

  @override
  FutureOr<void> onLoad() async {
    priority = 10;
    position = Vector2(gameRef.size.x + 250, 20);

    // ✅ FIXED: Get name from NakamaManager first (already loaded)
    final name =
        gameRef.nakamaManager.myUsername ??
        gameRef.account.user.displayName ??
        gameRef.account.user.username ??
        'Guest';

    await _initializeUI(name);

    // ✅ Update UI after a short delay to ensure account is loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (isMounted) {
        _fetchAndSetDisplayName();
      }
    });
  }

  Future<void> _fetchAndSetDisplayName() async {
    final client = gameRef.nakamaManager.client;
    final session = gameRef.nakamaManager.session;
    if (client == null || session == null) return;

    try {
      final Account account = await client.getAccount(session);
      final displayName = account.user.displayName;
      final username = account.user.username;

      // ✅ FIXED: Prioritize displayName, fallback to username, then 'Guest'
      String finalName = 'Guest';
      if (displayName != null && displayName.isNotEmpty) {
        finalName = displayName;
      } else if (username != null && username.isNotEmpty) {
        finalName = username;
      }

      if (finalName != 'Guest' && finalName != _nameText.text) {
        updateName(finalName);
        debugPrint('[AccountInfo] ✅ Updated name: $finalName');
      }
    } catch (e) {
      debugPrint('[AccountInfo] ❌ Error fetching account: $e');
    }
  }

  void updateName(String newName) {
    if (isMounted) {
      _nameText.text = newName;
      _updateLayout();
    }
  }

  Future<void> _initializeUI(String name) async {
    _birdIcon = SpriteComponent(
      sprite: await Sprite.load('bird.png'),
      size: Vector2.all(32),
    );
    _nameText = TextComponent(
      text: name,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
          ],
        ),
      ),
    );
    _updateLayout();
    addAll([_birdIcon, _nameText]);
  }

  void _updateLayout() {
    _birdIcon.position = Vector2(12, 6);
    _nameText.position = Vector2(_birdIcon.x + _birdIcon.width + 10, 12);
    size = Vector2(_nameText.x + _nameText.width + 15, 44);
  }

  @override
  void onTapDown(TapDownEvent event) => gameRef.showUpdateAccountOverlay();

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(22),
    );
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0077B6).withOpacity(0.8),
          const Color(0xFF00B4D8).withOpacity(0.8),
        ],
      ).createShader(rect.outerRect);
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);
  }
}
