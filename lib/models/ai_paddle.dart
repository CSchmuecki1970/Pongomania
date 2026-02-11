import 'dart:math';
import 'game_objects.dart';

class AIPaddle {
  final Random random = Random();
  late double targetY;
  double updateCounter = 0;
  static const int UPDATE_INTERVAL =
      10; // Update target every ~10 frames for steady movement
  double difficulty = 1.0; // 0.0 = very dumb, 1.0 = very smart

  AIPaddle({this.difficulty = 0.8}) {
    // Initialize targetY to avoid late initialization errors
    targetY = 0.0;
  }

  void update(Paddle paddle, Ball ball, double screenHeight) {
    updateCounter++;

    if (updateCounter >= UPDATE_INTERVAL) {
      updateCounter = 0;

      // Calculate target position
      // Perfect prediction would put paddle center at ball center
      final ballCenterY = ball.y;

      // Add some randomness based on difficulty
      final randomError =
          (1.0 - difficulty) * 50.0 * (random.nextDouble() - 0.5);
      targetY = ballCenterY + randomError;

      // Clamp target to keep paddle visible on screen
      // Paddle center must be at least paddle.height/2 from edges
      targetY = targetY.clamp(
        paddle.height / 2,
        screenHeight - paddle.height / 2,
      );
    }

    // Move paddle towards target
    final paddleCenterY = paddle.y + paddle.height / 2;
    final distanceToTarget = targetY - paddleCenterY;

    // Smooth movement - move one step per frame toward target
    if (distanceToTarget.abs() > 2) {
      // Only move if significantly off target - prevents jitter
      if (distanceToTarget > 0) {
        paddle.moveDown(screenHeight);
      } else {
        paddle.moveUp();
      }
    }
  }
}
