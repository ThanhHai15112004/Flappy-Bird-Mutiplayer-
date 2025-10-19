import 'package:flutter_bloc/flutter_bloc.dart';

enum PlayingState {
  menu,
  playing,
  gameOver;

  bool get isMenu => this == PlayingState.menu;
  bool get isPlaying => this == PlayingState.playing;
  bool get isGameOver => this == PlayingState.gameOver;
}

class GameState {
  final PlayingState playingState;
  final int score;
  final bool isMultiplayer;
  final bool isAlive;

  const GameState({
    this.playingState = PlayingState.menu,
    this.score = 0,
    this.isMultiplayer = false,
    this.isAlive = true,
  });

  GameState copyWith({
    PlayingState? playingState,
    int? score,
    bool? isMultiplayer,
    bool? isAlive,
  }) {
    return GameState(
      playingState: playingState ?? this.playingState,
      score: score ?? this.score,
      isMultiplayer: isMultiplayer ?? this.isMultiplayer,
      isAlive: isAlive ?? this.isAlive,
    );
  }
}

class GameCubit extends Cubit<GameState> {
  GameCubit() : super(const GameState());

  void startGame() {
    emit(
      state.copyWith(
        playingState: PlayingState.playing,
        score: 0,
        isMultiplayer: false,
        isAlive: true,
      ),
    );
  }

  void startMultiplayer() {
    emit(
      state.copyWith(
        playingState: PlayingState.playing,
        score: 0,
        isMultiplayer: true,
        isAlive: true,
      ),
    );
  }

  /// Tăng điểm
  void increaseScore() {
    emit(state.copyWith(score: state.score + 1));
  }

  /// Game over
  void gameOver() {
    emit(state.copyWith(playingState: PlayingState.gameOver));
  }

  /// Về menu
  void backToMenu() {
    emit(const GameState());
  }

  /// Chết trong multiplayer
  void died() {
    emit(state.copyWith(isAlive: false));
  }
}
