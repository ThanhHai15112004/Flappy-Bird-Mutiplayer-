import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/components/bird.dart';
import 'package:flutter_flappy_bird/components/ground.dart';
import 'package:flutter_flappy_bird/components/opponent_bird.dart';
import 'package:flutter_flappy_bird/components/pipe_manager.dart';
import 'package:flutter_flappy_bird/components/score.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/multiplayer/player_state.dart';
import 'package:flutter_flappy_bird/scenes/base_scene.dart';

class GameplayScene extends BaseScene {
  final bool isMultiplayer;

  late Bird bird;
  late Ground ground;
  late PipeManager pipeManager;
  late ScoreText scoreText;

  GameplayScene({required this.isMultiplayer});

  @override
  Future<void> onEnter() async {
    _initializeGameState();
    await _addGameComponents();
    _assignComponentsToGame();

    if (isMultiplayer) _setupMultiplayer();
  }

  // Khởi tạo trạng thái game
  void _initializeGameState() {
    gameRef.gameState = GameState.playing;
    gameRef.isMultiplayer = isMultiplayer;
    gameRef.myAlive = true;
    gameRef.score = 0;
    gameRef.paused = false;
    gameRef.gameTimeElapsed = 0.0;
  }

  // Thêm các components vào scene
  Future<void> _addGameComponents() async {
    bird = Bird();
    ground = Ground();
    pipeManager = PipeManager();
    scoreText = ScoreText();

    await add(bird);
    await add(ground);
    await add(pipeManager);
    await add(scoreText);
  }

  // Gán components vào game reference
  void _assignComponentsToGame() {
    gameRef.bird = bird;
    gameRef.pipeManager = pipeManager;
    gameRef.scoreText = scoreText;
    gameRef.ground = ground;
  }

  void _setupMultiplayer() {
    final nm = gameRef.nakamaManager;

    nm.pipeSpawnNotifier.addListener(_onPipeSpawned);
    nm.countdownNotifier.addListener(_onCountdownChanged);
    nm.playersStateNotifier.addListener(_onPlayersStateChanged);
    nm.winnerNotifier.addListener(_onWinnerAnnounced);

    if (NetworkConfig.useClientAuthoritative) {
      nm.physicsEventNotifier.addListener(_onPhysicsEvent);
    }

    // Spawn existing players
    Future.delayed(const Duration(milliseconds: 100), _onPlayersStateChanged);
  }

  // Xử lý physics events
  void _onPhysicsEvent() {
    final event = gameRef.nakamaManager.physicsEventNotifier.value;
    if (event == null) return;

    final userId = event['userId'] as String?;
    final eventType = event['eventType'] as String?;
    if (userId == null || eventType == null) return;

    gameRef.opponentBirds[userId]?.handleRemoteEvent(eventType, event);
    gameRef.nakamaManager.physicsEventNotifier.value = null;
  }

  void _onPipeSpawned() {
    final evt = gameRef.nakamaManager.pipeSpawnNotifier.value;
    if (evt == null) return;

    pipeManager.spawnRemotePipe(evt.id, evt.xNormalized, evt.gapYNormalized);
    gameRef.nakamaManager.pipeSpawnNotifier.value = null;
  }

  void _onCountdownChanged() {
    // Countdown logic nếu cần
  }

  void _onPlayersStateChanged() {
    final playersState = gameRef.nakamaManager.playersStateNotifier.value;
    final myUserId = gameRef.nakamaManager.myUserId;

    for (final entry in playersState.entries) {
      final userId = entry.key;
      final playerState = entry.value;

      if (userId == myUserId) continue;

      final existing = gameRef.opponentBirds[userId];
      if (existing != null) {
        if (!NetworkConfig.useClientAuthoritative) {
          existing.updateRemoteState(
            y: playerState.birdY,
            velocity: playerState.velocity,
            isAlive: playerState.isAlive,
          );
        }
      } else {
        _spawnOpponentBird(userId, playerState);
      }
    }

    _removeOfflinePlayers(playersState.keys.toSet());
  }

  void _spawnOpponentBird(String userId, PlayerState playerState) {
    final screenWidth = gameRef.size.x;
    final opponentX = (screenWidth * birdStartXPercent) + 50;

    final opponent = OpponentBird(
      playerId: userId,
      username: playerState.username,
      position: Vector2(opponentX, playerState.birdY),
    );
    add(opponent);
    gameRef.opponentBirds[userId] = opponent;

    opponent.updateRemoteState(
      y: playerState.birdY,
      velocity: playerState.velocity,
      isAlive: playerState.isAlive,
    );
  }

  void _removeOfflinePlayers(Set<String> activeIds) {
    final removedIds = gameRef.opponentBirds.keys
        .where((id) => !activeIds.contains(id))
        .toList();

    for (final id in removedIds) {
      gameRef.opponentBirds[id]?.removeFromParent();
      gameRef.opponentBirds.remove(id);
    }
  }

  void _onWinnerAnnounced() {
    final winner = gameRef.nakamaManager.winnerNotifier.value;
    if (winner == null) return;
    gameRef.showWinnerDialog(winner);
  }

  void handleGameOver() {
    if (isMultiplayer) {
      if (gameRef.gameState == GameState.playing && gameRef.myAlive) {
        gameRef.nakamaManager.sendDied();
        gameRef.enterSpectatorMode();
      }
    } else {
      gameRef.gameOver();
    }
  }

  @override
  Future<void> onExit() async {
    _removeGameComponents();
    _removeOpponentBirds();
    if (isMultiplayer) _removeMultiplayerListeners();
  }

  void _removeGameComponents() {
    for (final component in [bird, ground, pipeManager, scoreText]) {
      component.removeFromParent();
    }
  }

  void _removeOpponentBirds() {
    for (final opponent in gameRef.opponentBirds.values) {
      opponent.removeFromParent();
    }
    gameRef.opponentBirds.clear();
  }

  void _removeMultiplayerListeners() {
    final nm = gameRef.nakamaManager;
    nm.pipeSpawnNotifier.removeListener(_onPipeSpawned);
    nm.countdownNotifier.removeListener(_onCountdownChanged);
    nm.playersStateNotifier.removeListener(_onPlayersStateChanged);
    nm.winnerNotifier.removeListener(_onWinnerAnnounced);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Cập nhật thời gian chơi để tăng tốc độ parallax
    if (gameRef.gameState == GameState.playing) {
      gameRef.gameTimeElapsed += dt;
    }
  }
}
