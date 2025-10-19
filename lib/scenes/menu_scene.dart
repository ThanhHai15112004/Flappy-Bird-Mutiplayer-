import 'package:flutter_flappy_bird/components/account_info.dart';
import 'package:flutter_flappy_bird/components/menu_text.dart';
import 'package:flutter_flappy_bird/constants.dart';
import 'package:flutter_flappy_bird/scenes/base_scene.dart';
import 'package:flutter_flappy_bird/scenes/scene_manager.dart';

class MenuScene extends BaseScene {
  late MenuText menuText;
  late AccountInfo accountInfo;

  @override
  Future<void> onEnter() async {
    gameRef.gameState = GameState.menu;
    gameRef.paused = false;

    menuText = MenuText();
    accountInfo = AccountInfo();

    await add(menuText);
    await add(accountInfo);
  }

  void startSinglePlayer() {
    gameRef.sceneManager.switchTo(
      SceneType.gameplay,
      params: {'isMultiplayer': false},
    );
  }

  void startMultiplayer() {
    gameRef.showMatchmakingOverlay();
  }

  @override
  Future<void> onExit() async {
    menuText.removeFromParent();
    accountInfo.removeFromParent();
  }
}
