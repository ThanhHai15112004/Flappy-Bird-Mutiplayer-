import 'dart:async';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/components/background.dart';
import 'package:flutter_flappy_bird/components/bird.dart';
import 'package:flutter_flappy_bird/components/ground.dart';
import 'package:flutter_flappy_bird/components/score.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/components/menu_text.dart';
import 'components/pipe.dart';
import 'components/pipe_manager.dart';

class FlappyBirdGame extends FlameGame with TapDetector, HasCollisionDetection {
  /*

    basic game component:
    -bird
    -background
    -ground
    -pipes
    -score 

  */
  late Bird bird;
  late Background background;
  late Ground ground;
  late PipeManager pipeManager;
  late ScoreText scoreText;
  late MenuText menuText;

  GameState gameState = GameState.menu;
  /*

    Load

  */
  @override
  Future<void> onLoad() async {
    //load background
    background = Background(size);
    add(background);

    //load ground
    ground = Ground();
    add(ground);

    //load bird
    bird = Bird();
    add(bird);

    //pipe manager
    pipeManager = PipeManager();
    add(pipeManager);

    //score text
    scoreText = ScoreText();
    add(scoreText);

    // Menu text
    menuText = MenuText();
    add(menuText);

    await FlameAudio.audioCache.loadAll([
      'wing.mp3',
      'point.mp3',
      'hit.mp3',
      'die.mp3',
    ]);
  }

  /*

    Tap
    
  */

  @override
  void onTap() {
    switch (gameState) {
      case GameState.menu:
        startGame();
        break;
      case GameState.playing:
        bird.flap();
        break;
      case GameState.gameOver:
        // Trong trường hợp này, dialog sẽ handle restart
        break;
    }
  }
  /*

    score
    
  */

  int score = 0;
  void incrementScore() {
    score += 1;
  }

  /*

    startGame
    
  */
  void startGame() {
    gameState = GameState.playing;
    menuText.removeFromParent();
  }

  /*

    game over

  */
  void gameOver() {
    if (gameState == GameState.gameOver) return;

    gameState = GameState.gameOver;

    // Thay thế khối showDialog cũ bằng code sau:

    showDialog(
      context: buildContext!,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            elevation: 15,
            color: Colors.white.withOpacity(0.95),
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade600, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "GAME OVER",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          blurRadius: 5,
                          color: Colors.black38,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Score: $score",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      resetGame();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      "RESTART",
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void resetGame() {
    // Reset bird
    bird.position = Vector2(birdStartX, birdStartY);
    bird.veloctity = 0;

    // Reset game state
    gameState = GameState.menu;
    score = 0;

    // Remove all pipes
    children.whereType<Pipe>().forEach((Pipe pipe) => pipe.removeFromParent());

    // Add menu text back
    if (!children.contains(menuText)) {
      add(menuText);
    }
  }
}
