import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/components/pipe.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class PipeManager extends Component with HasGameRef<FlappyBirdGame> {
  double pipeSpawnTimer = 0;
  final List<Pipe> _activePipes = [];

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState != GameState.playing) return;

    _handlePipeSpawning(dt);
    _updatePipes(dt);
    _removeOffscreenPipes();
  }

  void _handlePipeSpawning(double dt) {
    if (gameRef.isMultiplayer) return;

    pipeSpawnTimer += dt;
    if (pipeSpawnTimer > pipeInterval) {
      pipeSpawnTimer = 0;
      spawnPipe();
    }
  }

  void _updatePipes(double dt) {
    for (final pipe in _activePipes) {
      pipe.position.x -= groundScrollingSpeed * dt * gameRef.speedMultiplier;

      if (!pipe.scored && pipe.position.x < gameRef.bird.position.x) {
        pipe.scored = true;
        if (pipe.isTopPipe && (!gameRef.isMultiplayer || gameRef.myAlive)) {
          gameRef.incrementScore();
          gameRef.pointPool.start(volume: 0.6);
        }
      }
    }
  }

  void _removeOffscreenPipes() {
    _activePipes.removeWhere((pipe) {
      if (pipe.position.x + pipe.size.x <= 0) {
        pipe.removeFromParent();
        return true;
      }
      return false;
    });
  }

  void spawnPipe() {
    final screenHeight = gameRef.size.y;
    final maxHeight = screenHeight - groundHeight - pipeGap - minPipeHeight;

    final bottomHeight =
        minPipeHeight + Random().nextDouble() * (maxHeight - minPipeHeight);
    final topHeight = screenHeight - groundHeight - bottomHeight - pipeGap;

    _createPipePair(
      x: gameRef.size.x,
      bottomHeight: bottomHeight,
      topHeight: topHeight,
    );
  }

  void spawnRemotePipe(
    int id,
    double xNormalized,
    double gapYNormalized, {
    double? serverTime,
  }) {
    final screenWidth = gameRef.size.x;
    final screenHeight = gameRef.size.y;

    double x = denormalizeX(xNormalized, screenWidth);

    if (serverTime != null) {
      final latency = DateTime.now().millisecondsSinceEpoch - serverTime;
      x -= groundScrollingSpeed * gameRef.speedMultiplier * (latency / 1000.0);
    }

    final playableHeight = screenHeight - groundHeight;
    final gapCenterY = gapYNormalized * playableHeight;

    final bottomHeight = (gapCenterY - pipeGap / 2).clamp(
      minPipeHeight,
      playableHeight - pipeGap - minPipeHeight,
    );
    final topHeight = playableHeight - bottomHeight - pipeGap;

    if (bottomHeight < minPipeHeight || topHeight < minPipeHeight) return;

    _createPipePair(x: x, bottomHeight: bottomHeight, topHeight: topHeight);
  }

  void _createPipePair({
    required double x,
    required double bottomHeight,
    required double topHeight,
  }) {
    final screenHeight = gameRef.size.y;

    final bottomPipe = Pipe(
      position: Vector2(x, screenHeight - groundHeight - bottomHeight),
      size: Vector2(pipeWeight, bottomHeight),
      isTopPipe: false,
    );

    final topPipe = Pipe(
      position: Vector2(x, 0),
      size: Vector2(pipeWeight, topHeight),
      isTopPipe: true,
    );

    add(bottomPipe);
    add(topPipe);
    _activePipes.add(bottomPipe);
    _activePipes.add(topPipe);
  }
}
