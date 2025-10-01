import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_flappy_bird/components/ground.dart';
import 'package:flutter_flappy_bird/components/pipe.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/game.dart';

class Bird extends SpriteComponent with CollisionCallbacks {
  //khởi tạo vị trí và kích thước của chim
  Bird()
    : super(
        position: Vector2(birdStartX, birdStartY),
        size: Vector2(birdWidth, birdHeight),
      );
  //Khởi tạo tạo physics(trọng lực)
  double veloctity = 0;

  /*
  
    load


  */
  @override
  Future<void> onLoad() async {
    //load bird image
    sprite = await Sprite.load('bird.png');

    //add hit box
    add(RectangleHitbox());
  }

  /*
  
    jump / flag


  */
  void flap() {
    veloctity = jumpStrength;
    FlameAudio.play('wing.mp3');
  }

  /*
  
    update

  */

  @override
  void update(double dt) {
    // Only apply physics when game is playing
    final game = parent as FlappyBirdGame;
    if (game.gameState == GameState.playing) {
      // Apply gravity
      veloctity += gravity * dt;
      // Update bird position
      position.y += veloctity * dt;
    }
  }

  /*
  
    Collision 

  */
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    final game = parent as FlappyBirdGame;
    if (game.gameState != GameState.playing) return;

    if (other is Ground) {
      FlameAudio.play('die.mp3');
      (parent as FlappyBirdGame).gameOver();
    }

    if (other is Pipe) {
      FlameAudio.play('hit.mp3');
      (parent as FlappyBirdGame).gameOver();
    }
  }
}
