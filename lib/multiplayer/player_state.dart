class PlayerState {
  final String userId;
  final String username;
  final double birdY;
  final double velocity;
  final bool isAlive;
  final int score;

  PlayerState({
    required this.userId,
    required this.username,
    required this.birdY,
    required this.velocity,
    required this.isAlive,
    required this.score,
  });

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      birdY: (json['birdY'] ?? json['y'] ?? 300).toDouble(),
      velocity: (json['velocity'] ?? 0).toDouble(),
      isAlive: json['isAlive'] ?? true,
      score: json['score'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'birdY': birdY,
    'velocity': velocity,
    'isAlive': isAlive,
    'score': score,
  };

  PlayerState copyWith({
    String? userId,
    String? username,
    double? birdY,
    double? velocity,
    bool? isAlive,
    int? score,
  }) {
    return PlayerState(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      birdY: birdY ?? this.birdY,
      velocity: velocity ?? this.velocity,
      isAlive: isAlive ?? this.isAlive,
      score: score ?? this.score,
    );
  }
}
