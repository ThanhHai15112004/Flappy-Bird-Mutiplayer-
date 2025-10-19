const double birdStartXPercent = 0.15;
const double birdStartYPercent = 0.5;

const double birdStartX = 50;
const double birdStartY = 50;

const double birdWidth = 50;
const double birdHeight = 30;

const double groundY = 550;

const double gravity = 1200.0;
const double jumpStrength = -400.0;

const double groundHeight = 150;
const double groundScrollingSpeed = 100;

const double pipeInterval = 2.2;
const double pipeGap = 250;
const double minPipeHeight = 50;
const double pipeWeight = 60;

enum GameState { menu, playing, gameOver }

const double canonicalWidth = 700.0;
const double canonicalHeight = 600.0;

double normalizeX(double pixelX, double screenWidth) {
  return pixelX / screenWidth;
}

double normalizeY(double pixelY, double screenHeight) {
  return pixelY / screenHeight;
}

double denormalizeX(double normalizedX, double screenWidth) {
  return normalizedX * screenWidth;
}

double denormalizeY(double normalizedY, double screenHeight) {
  return normalizedY * screenHeight;
}

class NetworkConfig {
  static const bool useClientAuthoritative = true;

  static const double positionDriftThreshold = 20.0;
  static const double velocityDriftThreshold = 50.0;

  static const double maxVelocity = 800.0;
  static const double maxPositionJumpPerMs = 2.0;
  static const int minScoreIntervalMs = 1500;

  static const int positionCorrectionIntervalMs = 10000;
}
