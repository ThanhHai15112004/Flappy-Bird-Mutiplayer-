import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/components/pipe.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class PipeManager extends Component with HasGameRef<FlappyBirdGame> {
  /*

    Update -> every second

    spaw pipe

  */

  double pipeSpawnTimer = 0;

  @override
  void update(double dt) {
    if (gameRef.gameState != GameState.playing) return;
    // generate new pipe
    pipeSpawnTimer += dt;

    if (pipeSpawnTimer > pipeInterval) {
      pipeSpawnTimer = 0;
      spawPipe();
    }
  }

  /*

    spaw new pipe

  */

  void spawPipe() {
    final double screenHeight = gameRef.size.y;

    /*

      Calculate pipe heights

    */

    //max possible heights
    final double maxPipeHeight =
        screenHeight - groundHeight - pipeGap - minPipeHeight;

    //height of bottom pipe -> random  selec min or max
    final double bottomPipeHeight =
        minPipeHeight + Random().nextDouble() * (maxPipeHeight - minPipeHeight);

    //height of top pipe
    final double topPipeHeight =
        screenHeight - groundHeight - bottomPipeHeight - pipeGap;

    /*

      create bottom pipe

    */

    final bottomPipe = Pipe(
      //position
      Vector2(gameRef.size.x, screenHeight - groundHeight - bottomPipeHeight),
      //size
      Vector2(pipeWeight, bottomPipeHeight),
      isTopPipe: false,
    );

    /*

      create top pipe

    */

    final topPipe = Pipe(
      //posstion
      Vector2(gameRef.size.x, 0),
      //size
      Vector2(pipeWeight, topPipeHeight),
      isTopPipe: true,
    );

    gameRef.add(bottomPipe);
    gameRef.add(topPipe);
  }
}
