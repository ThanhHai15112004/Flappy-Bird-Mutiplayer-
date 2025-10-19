import 'dart:async';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/Widgets/matchmaking_overlay.dart';
import 'package:flutter_flappy_bird/Widgets/update_account_overlay.dart';
import 'package:flutter_flappy_bird/components/background.dart';
import 'package:flutter_flappy_bird/components/bird.dart';
import 'package:flutter_flappy_bird/components/ground.dart';
import 'package:flutter_flappy_bird/components/opponent_bird.dart';
import 'package:flutter_flappy_bird/components/score.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/nakama_manager.dart';
import 'package:flutter_flappy_bird/scenes/scene_manager.dart';
import 'package:nakama/nakama.dart';
import 'components/pipe_manager.dart';

class FlappyBirdGame extends FlameGame with TapDetector, HasCollisionDetection {
  GameState gameState = GameState.menu;
  int score = 0;

  // Tốc độ game tăng dần
  double gameTimeElapsed = 0.0;
  double get speedMultiplier => (1.0 + gameTimeElapsed / 60.0).clamp(1.0, 2.0);

  late SceneManager sceneManager;

  late Bird bird;
  late Background background;
  late Ground ground;
  late PipeManager pipeManager;
  late ScoreText scoreText;

  late AudioPool wingPool;
  late AudioPool pointPool;
  late AudioPool hitPool;
  late AudioPool diePool;

  final NakamaManager nakamaManager;
  late Account account;

  Map<String, OpponentBird> opponentBirds = {};
  bool myAlive = true;
  bool isMultiplayer = false;

  FlappyBirdGame({required this.nakamaManager});

  void enterSpectatorMode() {
    myAlive = false;
    overlays.add('SpectatorOverlay');
  }

  @override
  Future<void> onLoad() async {
    try {
      await nakamaManager.connectSocket();

      final client = nakamaManager.client;
      final session = nakamaManager.session;
      if (client == null || session == null) return;

      account = await client.getAccount(session);

      await _loadBackground();
      await _loadAudio();

      sceneManager = SceneManager(this);
      await sceneManager.switchTo(SceneType.menu);

      nakamaManager.joinedNotifier.addListener(_onMatchJoined);
    } catch (e) {
      debugPrint('[Load] Lỗi khi khởi tạo game: $e');
    }
  }

  void _onMatchJoined() {
    if (nakamaManager.joinedNotifier.value && gameState == GameState.menu) {
      startMultiplayerGame();
    }
  }

  Future<void> _loadBackground() async {
    await add(background = Background(size));
  }

  Future<void> _loadAudio() async {
    await FlameAudio.audioCache.loadAll([
      'wing.mp3',
      'point.mp3',
      'hit.mp3',
      'die.mp3',
    ]);

    final pools = await Future.wait<AudioPool>([
      FlameAudio.createPool('wing.mp3', minPlayers: 2, maxPlayers: 4),
      FlameAudio.createPool('point.mp3', minPlayers: 2, maxPlayers: 5),
      FlameAudio.createPool('hit.mp3', minPlayers: 1, maxPlayers: 2),
      FlameAudio.createPool('die.mp3', minPlayers: 1, maxPlayers: 2),
    ]);

    wingPool = pools[0];
    pointPool = pools[1];
    hitPool = pools[2];
    diePool = pools[3];
  }

  Future<void> startMatchmaking() async {
    showMatchmakingOverlay();
    final displayName = account.user.displayName?.isNotEmpty == true
        ? account.user.displayName!
        : account.user.username ?? 'Me';
    await nakamaManager.findOrCreateMatch(displayName);
  }

  Future<void> cancelMatchmaking() async {
    await nakamaManager.cancelMatchmaking();
  }

  void showMatchmakingOverlay() {
    final ctx = buildContext;
    if (ctx == null) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => MatchmakingOverlay(
        playersListenable: nakamaManager.playersNotifier,
        joinedListenable: nakamaManager.joinedNotifier,
        onCancel: () async {
          await nakamaManager.cancelMatchmaking();
          if (Navigator.of(dialogCtx).canPop()) {
            Navigator.of(dialogCtx).pop();
          }
        },
        onReady: () async {
          nakamaManager.sendReady();
        },
        onCancelReady: () async {
          nakamaManager.sendCancelReady();
        },
      ),
    );
  }

  void startMultiplayerGame() {
    final ctx = buildContext;
    if (ctx != null && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();

    Future.delayed(const Duration(milliseconds: 100), () {
      sceneManager.switchTo(
        SceneType.gameplay,
        params: {'isMultiplayer': true},
      );
    });
  }

  void showWinnerDialog(String winnerName) {
    if (buildContext == null) return;

    final isWinner =
        nakamaManager.myUserId != null &&
        nakamaManager.lastWinnerId == nakamaManager.myUserId;
    final winColor = isWinner ? Colors.green : Colors.orange;

    paused = true;
    hitPool.start(volume: 0.5);

    showDialog(
      context: buildContext!,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [winColor.shade50, winColor.shade100],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: winColor.shade600, width: 4),
              boxShadow: [
                BoxShadow(
                  color: winColor.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon chiến thắng/thua
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: winColor.shade600,
                    boxShadow: [
                      BoxShadow(
                        color: winColor.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isWinner ? Icons.emoji_events : Icons.sentiment_neutral,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  isWinner ? "BẠN THẮNG!" : "THUA RỒI",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: winColor.shade700,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Tên người thắng
                _buildInfoCard(
                  icon: Icons.person,
                  iconColor: winColor.shade600,
                  text: winnerName,
                ),
                const SizedBox(height: 15),

                // Điểm số
                _buildInfoCard(
                  icon: Icons.star,
                  iconColor: Colors.amber.shade600,
                  text: "Điểm của bạn: $score",
                ),
                const SizedBox(height: 30),

                // Button về menu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      resetGame();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: winColor.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 8,
                      shadowColor: winColor.withOpacity(0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home, size: 28),
                        SizedBox(width: 10),
                        Text(
                          "VỀ MENU",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tạo info card
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void showUpdateAccountOverlay() {
    if (buildContext == null) return;
    showDialog(
      context: buildContext!,
      builder: (context) => UpdateAccountOverlay(game: this),
    );
  }

  @override
  void onRemove() {
    FlameAudio.audioCache.clearAll();
    super.onRemove();
  }

  @override
  void onTap() {
    switch (gameState) {
      case GameState.menu:
        break;
      case GameState.playing:
        if (isMultiplayer && !myAlive) return;
        bird.flap();
        break;
      case GameState.gameOver:
        break;
    }
  }

  void incrementScore() {
    if (isMultiplayer && !myAlive) return;
    score += 1;
    if (isMultiplayer) {
      nakamaManager.sendScore(score);
    }
  }

  void gameOver() {
    if (gameState == GameState.gameOver) return;

    gameState = GameState.gameOver;
    paused = true;
    hitPool.start(volume: 0.5);

    showDialog(
      context: buildContext!,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.red.shade600, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title GAME OVER
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: Colors.red.shade600, size: 40),
                  const SizedBox(width: 10),
                  const Text(
                    "GAME OVER",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Điểm số
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.amber.shade600,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Điểm: $score",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 2 Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildGameOverButton(
                      context: context,
                      icon: Icons.home,
                      label: "MENU",
                      color: Colors.orange.shade600,
                      onPressed: () {
                        Navigator.pop(context);
                        sceneManager.switchTo(SceneType.menu);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildGameOverButton(
                      context: context,
                      icon: Icons.refresh,
                      label: "CHƠI LẠI",
                      color: Colors.green.shade600,
                      onPressed: () {
                        Navigator.pop(context);
                        restartGame();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tạo button game over
  Widget _buildGameOverButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void restartGame() {
    score = 0;
    sceneManager.switchTo(SceneType.gameplay, params: {'isMultiplayer': false});
  }

  Future<void> resetGame() async {
    if (isMultiplayer && nakamaManager.currentMatchId != null) {
      try {
        await nakamaManager.socket?.leaveMatch(nakamaManager.currentMatchId!);
      } catch (_) {}
    }

    nakamaManager.resetLobbyState();
    nakamaManager.currentMatchId = null;
    isMultiplayer = false;
    myAlive = true;
    overlays.remove('SpectatorOverlay');
    score = 0;
    paused = false;

    for (final opponent in opponentBirds.values) {
      opponent.removeFromParent();
    }
    opponentBirds.clear();

    await sceneManager.switchTo(SceneType.menu);
  }
}
