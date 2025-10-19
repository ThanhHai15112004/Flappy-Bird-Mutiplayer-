import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class OpponentBird extends SpriteComponent with HasGameRef<FlappyBirdGame> {
  static const double _smoothFactor = 0.4;
  static const double _driftThreshold = 30.0;
  static const double _snapThreshold = 100.0;

  final String playerId;
  final String username;

  double velocity = 0;
  bool isAlive = true;
  int lastEventTimestamp = 0;

  double _targetY = 300.0;
  double _currentY = 300.0;
  double _targetVelocity = 0.0;

  late TextComponent nameLabel;

  OpponentBird({
    required this.playerId,
    required this.username,
    required Vector2 position,
  }) : super(
         position: position,
         size: Vector2(birdWidth, birdHeight),
         priority: 5,
       ) {
    _currentY = position.y;
    _targetY = position.y;
  }

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('bird.png');
    _updatePaintColor();

    nameLabel = TextComponent(
      text: username,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(birdWidth / 2, -10),
    );
    add(nameLabel);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isAlive) return;

    if (NetworkConfig.useClientAuthoritative) {
      _updateLocalPhysics(dt);
    } else {
      _updateInterpolation(dt);
    }
  }

  void _updateLocalPhysics(double dt) {
    velocity += gravity * dt;
    position.y += velocity * dt;

    if (position.y < 0) {
      position.y = 0;
      velocity = 0;
    }
  }

  void _updateInterpolation(double dt) {
    _currentY += (_targetY - _currentY) * _smoothFactor;
    velocity += (_targetVelocity - velocity) * _smoothFactor;
    position.y = _currentY;
  }

  void _updatePaintColor() {
    paint = Paint()
      ..color = isAlive
          ? Colors.white.withOpacity(0.5)
          : Colors.red.withOpacity(0.3);
  }

  void updateRemoteState({
    required double y,
    required double velocity,
    required bool isAlive,
  }) {
    _targetY = y;
    _targetVelocity = velocity;
    this.isAlive = isAlive;

    if ((y - _currentY).abs() > _snapThreshold) {
      _currentY = y;
      position.y = y;
    }

    _updatePaintColor();
  }

  void handleRemoteEvent(String eventType, Map<String, dynamic> data) {
    final timestamp = data['timestamp'] as int? ?? 0;
    if (timestamp > 0 && timestamp < lastEventTimestamp) return;
    if (timestamp > 0) lastEventTimestamp = timestamp;

    switch (eventType) {
      case 'PLAYER_FLAP':
        _handleFlapEvent(data);
      case 'PLAYER_DIED':
        _handleDeathEvent(data);
      case 'PLAYER_SCORED':
        _handleScoredEvent(data);
      case 'POSITION_CORRECTION':
        _handleCorrectionEvent(data);
    }
  }

  double _denormalizeY(double normalized) {
    return denormalizeY(normalized, gameRef.size.y);
  }

  void _applySyncIfNeeded(double? normalizedY, double? serverVelocity) {
    if (normalizedY == null) return;

    final serverY = _denormalizeY(normalizedY);
    final drift = (serverY - position.y).abs();

    if (drift > _driftThreshold) {
      position.y = serverY;
      if (serverVelocity != null) velocity = serverVelocity;
    }
  }

  void _handleFlapEvent(Map<String, dynamic> data) {
    final normalizedY = (data['yNormalized'] as num?)?.toDouble();
    final serverVelocity = (data['velocity'] as num?)?.toDouble() ?? velocity;

    if (normalizedY != null) {
      final serverY = _denormalizeY(normalizedY);
      final drift = (serverY - position.y).abs();
      if (drift > _driftThreshold) position.y = serverY;
    }

    velocity = serverVelocity;
  }

  void _handleDeathEvent(Map<String, dynamic> data) {
    isAlive = false;
    velocity = 0;

    final normalizedY = (data['yNormalized'] as num?)?.toDouble();
    if (normalizedY != null) position.y = _denormalizeY(normalizedY);

    _updatePaintColor();
  }

  void _handleScoredEvent(Map<String, dynamic> data) {
    _applySyncIfNeeded(
      (data['yNormalized'] as num?)?.toDouble(),
      (data['velocity'] as num?)?.toDouble(),
    );
  }

  void _handleCorrectionEvent(Map<String, dynamic> data) {
    final normalizedY = (data['yNormalized'] as num?)?.toDouble();
    final serverVelocity = (data['velocity'] as num?)?.toDouble();

    if (normalizedY != null) position.y = _denormalizeY(normalizedY);
    if (serverVelocity != null) velocity = serverVelocity;
  }
}
