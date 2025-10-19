import 'package:flame/components.dart';
import 'package:flutter_flappy_bird/game.dart';

abstract class BaseScene extends Component with HasGameRef<FlappyBirdGame> {
  Future<void> onEnter() async {}
  Future<void> onExit() async {}

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await onEnter();
  }
}
