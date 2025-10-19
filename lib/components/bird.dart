import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/components/ground.dart';
import 'package:flutter_flappy_bird/components/pipe.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class Bird extends SpriteComponent
    with CollisionCallbacks, HasGameRef<FlappyBirdGame> {
  Bird()
    : super(
        position: Vector2(birdStartX, birdStartY),
        size: Vector2(birdWidth, birdHeight),
      );

  double velocity = 0;
  int lastScoreTime = 0;

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('bird.png');
    add(RectangleHitbox());

    final screenWidth = gameRef.size.x;
    final screenHeight = gameRef.size.y;
    position.x = screenWidth * birdStartXPercent;
    position.y = screenHeight * birdStartYPercent;
  }

  void flap() {
    velocity = jumpStrength;
    gameRef.wingPool.start(volume: 0.7);

    if (!gameRef.isMultiplayer) return;

    if (NetworkConfig.useClientAuthoritative) {
      _sendPhysicsEvent('PLAYER_FLAP', extra: {});
    } else {
      gameRef.nakamaManager.sendFlap(position.y, velocity);
    }
  }

  void _sendPhysicsEvent(String eventType, {Map<String, dynamic>? extra}) {
    if (!gameRef.isMultiplayer) return;

    final normalizedY = normalizeY(position.y, gameRef.size.y);

    final event = {
      'yNormalized': normalizedY,
      'velocity': velocity,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...?extra,
    };

    gameRef.nakamaManager.sendPhysicsEvent(eventType, event);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState != GameState.playing) return;

    velocity += gravity * dt;
    position.y += velocity * dt;

    if (position.y <= 0) _handleDeath();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (gameRef.gameState != GameState.playing) return;

    if (other is Ground || other is Pipe) _handleDeath();
  }

  void _handleDeath() {
    if (gameRef.isMultiplayer) {
      if (gameRef.gameState == GameState.playing && gameRef.myAlive) {
        if (NetworkConfig.useClientAuthoritative) {
          _sendPhysicsEvent(
            'PLAYER_DIED',
            extra: {'finalScore': gameRef.score},
          );
        } else {
          gameRef.nakamaManager.sendDied();
        }
        gameRef.enterSpectatorMode();
      }
    } else {
      gameRef.gameOver();
    }
  }

  void onPipePassed(int pipeId) {
    if (!gameRef.isMultiplayer ||
        gameRef.gameState != GameState.playing ||
        !gameRef.myAlive)
      return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastScoreTime > 0 &&
        (now - lastScoreTime) < NetworkConfig.minScoreIntervalMs) {
      return;
    }
    lastScoreTime = now;

    if (NetworkConfig.useClientAuthoritative) {
      _sendPhysicsEvent(
        'PLAYER_SCORED',
        extra: {'score': gameRef.score, 'pipeId': pipeId},
      );
    }
  }
}
