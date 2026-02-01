import 'package:flutter/material.dart';
import 'dart:math';
import 'game_objects.dart';

class GameManager {
  late Paddle leftPaddle;
  late Paddle rightPaddle;
  late List<Ball> balls;
  late List<Brick> bricks;
  late GoldenBar? goldenBar;
  int leftScore = 0;
  int rightScore = 0;
  int leftBrickScore = 0; // Points from destroyed bricks
  int rightBrickScore = 0; // Points from destroyed bricks
  bool gameRunning = true;

  // Track which player hit the ball last
  String lastPaddleHit = 'right'; // 'left' or 'right'

  late double screenWidth;
  late double screenHeight;

  int frameCount = 0;
  static const int BRICK_SPAWN_DELAY = 300; // ~5 seconds at 60fps
  static const int BRICK_SPAWN_INTERVAL =
      120; // Spawn every ~2 seconds after first spawn
  static const int BRICK_SPAWN_INTERVAL_FAST =
      60; // Spawn every ~1 second after difficulty increase
  static const int DIFFICULTY_INCREASE_TIME =
      1800; // ~30 seconds at 60fps (double brick spawn rate)
  static const int BALL_SPAWN_INTERVAL =
      3600; // ~60 seconds at 60fps (one more ball per minute)
  final Random random = Random();

  GameManager({required this.screenWidth, required this.screenHeight}) {
    initialize();
  }

  void initialize() {
    leftPaddle = Paddle(x: 20, y: screenHeight / 2 - 50);
    rightPaddle = Paddle(x: screenWidth - 30, y: screenHeight / 2 - 50);
    balls = [Ball(x: screenWidth / 2, y: screenHeight / 2)];
    bricks = [];
    goldenBar = null;
    frameCount = 0;
    lastPaddleHit = 'right';
  }

  void update() {
    if (!gameRunning) return;

    frameCount++;

    // Update paddle speeds based on ball velocity
    _updatePaddleSpeeds();

    // Spawn additional ball every minute
    if (frameCount > 0 && frameCount % BALL_SPAWN_INTERVAL == 0) {
      spawnBall();
    }

    // Spawn bricks periodically with increasing frequency after 30 seconds
    if (frameCount >= BRICK_SPAWN_DELAY) {
      final brickInterval = frameCount >= DIFFICULTY_INCREASE_TIME
          ? BRICK_SPAWN_INTERVAL_FAST
          : BRICK_SPAWN_INTERVAL;
      if ((frameCount - BRICK_SPAWN_DELAY) % brickInterval == 0) {
        spawnBrick();
      }
    }

    // Update all balls
    for (int i = 0; i < balls.length; i++) {
      final ball = balls[i];
      ball.update(screenWidth, screenHeight);

      // Check paddle collisions - only collide if ball is moving toward the paddle
      if (checkCollision(ball.getRect(), leftPaddle.getRect())) {
        // Only bounce if ball is moving left (toward the paddle)
        if (ball.velocityX < 0) {
          lastPaddleHit = 'left';
          ball.velocityX = -ball.velocityX;
          ball.x = leftPaddle.x + leftPaddle.width + ball.radius;
          ball.velocityY +=
              (ball.y - (leftPaddle.y + leftPaddle.height / 2)) * 0.05;
        }
      }

      if (checkCollision(ball.getRect(), rightPaddle.getRect())) {
        // Only bounce if ball is moving right (toward the paddle)
        if (ball.velocityX > 0) {
          lastPaddleHit = 'right';
          ball.velocityX = -ball.velocityX;
          ball.x = rightPaddle.x - ball.radius;
          ball.velocityY +=
              (ball.y - (rightPaddle.y + rightPaddle.height / 2)) * 0.05;
        }
      }

      // Check golden bar collision with paddles
      if (goldenBar != null &&
          checkCollision(ball.getRect(), goldenBar!.getRect())) {
        // Golden bar is a bonus! Takes 5 points from the opponent
        if (lastPaddleHit == 'left') {
          rightBrickScore = (rightBrickScore - 5)
              .clamp(0, double.infinity)
              .toInt();
        } else {
          leftBrickScore = (leftBrickScore - 5)
              .clamp(0, double.infinity)
              .toInt();
        }
        // Remove golden bar after hit
        goldenBar = null;
      }

      // Check brick collisions
      bricks.removeWhere((brick) {
        if (checkCollision(ball.getRect(), brick.getRect())) {
          final brickRect = brick.getRect();

          // Award points to the player who hit the ball last
          if (lastPaddleHit == 'left') {
            leftBrickScore++;
          } else {
            rightBrickScore++;
          }

          // Apply speed boost based on brick color
          _applyBrickSpeedBoost(ball, brick.color);

          // Determine which side was hit by calculating overlap depth
          final overlapLeft = (ball.x) - (brickRect.left);
          final overlapRight = (brickRect.right) - (ball.x);
          final overlapTop = (ball.y) - (brickRect.top);
          final overlapBottom = (brickRect.bottom) - (ball.y);

          // Find minimum overlap to determine which side was hit
          final minOverlapX = overlapLeft < overlapRight
              ? overlapLeft
              : overlapRight;
          final minOverlapY = overlapTop < overlapBottom
              ? overlapTop
              : overlapBottom;

          // If X overlap is smaller (hit left/right side)
          if (minOverlapX < minOverlapY) {
            // Ball hit the left or right side of the brick
            ball.velocityX = -ball.velocityX;
            if (overlapLeft < overlapRight) {
              ball.x = brickRect.left - ball.radius;
            } else {
              ball.x = brickRect.right + ball.radius;
            }
          }
          // If Y overlap is smaller (hit top/bottom side)
          else {
            // Ball hit the top or bottom side of the brick
            ball.velocityY = -ball.velocityY;
            if (overlapTop < overlapBottom) {
              ball.y = brickRect.top - ball.radius;
            } else {
              ball.y = brickRect.bottom + ball.radius;
            }
          }

          return true; // Remove the brick
        }
        return false;
      });

      // Check if ball went out of bounds
      if (ball.x < 0) {
        rightScore++;
        // Spawn a new ball at center instead of just removing it
        balls[i] = Ball(x: screenWidth / 2, y: screenHeight / 2);
      } else if (ball.x > screenWidth) {
        leftScore++;
        // Spawn a new ball at center instead of just removing it
        balls[i] = Ball(x: screenWidth / 2, y: screenHeight / 2);
      }
    }

    // Check ball-to-ball collisions and ensure minimum of 1 ball
    for (int i = 0; i < balls.length; i++) {
      for (int j = i + 1; j < balls.length; j++) {
        if (checkCollision(balls[i].getRect(), balls[j].getRect())) {
          // Only remove a ball if we have more than 1 ball
          if (balls.length > 1) {
            // Remove the second ball in the collision
            balls.removeAt(j);
            j--;
          }
        }
      }
    }

    // Spawn golden bar if too many bricks on field
    if (bricks.length > 10 && goldenBar == null) {
      spawnGoldenBar();
    }

    // Update golden bar if it exists
    if (goldenBar != null) {
      goldenBar!.update(screenHeight);
    }
  }

  void spawnBall() {
    // Add a new ball at the center of the screen
    balls.add(Ball(x: screenWidth / 2, y: screenHeight / 2));
  }

  void spawnBrick() {
    // Random shape
    final shapes = BrickShape.values;
    final shape = shapes[random.nextInt(shapes.length)];

    // Random color
    final colors = [
      Colors.yellow,
      Colors.cyan,
      Colors.lime,
      Colors.orange,
      Colors.pink,
      Colors.purple,
    ];
    final color = colors[random.nextInt(colors.length)];

    // Get brick dimensions based on shape
    double width = 60;
    double height = 20;

    switch (shape) {
      case BrickShape.square:
        width = 60;
        height = 20;
        break;
      case BrickShape.verticalBar:
        width = 20;
        height = 60;
        break;
      case BrickShape.horizontalBar:
        width = 80;
        height = 15;
        break;
    }

    // Spawn brick across wider area - use 80% of screen width
    final minX = screenWidth * 0.1;
    final maxX = screenWidth * 0.9 - width;
    final minY = screenHeight * 0.15;
    final maxY = screenHeight * 0.85 - height;

    // Try to find a position that doesn't overlap with existing bricks
    late double x, y;
    bool foundValidPosition = false;
    int attempts = 0;
    const maxAttempts = 20;

    while (!foundValidPosition && attempts < maxAttempts) {
      x = minX + random.nextDouble() * (maxX - minX);
      y = minY + random.nextDouble() * (maxY - minY);

      final newBrickRect = Rect.fromLTWH(x, y, width, height);

      // Check if this position overlaps with any existing brick
      bool overlaps = false;
      for (final existingBrick in bricks) {
        if (checkCollision(newBrickRect, existingBrick.getRect())) {
          overlaps = true;
          break;
        }
      }

      if (!overlaps) {
        foundValidPosition = true;
      }

      attempts++;
    }

    // Only spawn the brick if we found a valid position
    if (foundValidPosition) {
      final brick = Brick(
        x: x,
        y: y,
        width: width,
        height: height,
        shape: shape,
        color: color,
      );

      bricks.add(brick);
    }
  }

  void spawnGoldenBar() {
    // Spawn golden bar in the middle area
    final x = screenWidth / 2 - 7.5; // Center horizontally
    final y = random.nextDouble() * (screenHeight - 60);
    final velocityY = (random.nextBool() ? 1.0 : -1.0) * 3;

    goldenBar = GoldenBar(x: x, y: y, velocityY: velocityY);
  }

  bool checkCollision(Rect rect1, Rect rect2) {
    return rect1.overlaps(rect2);
  }

  void _updatePaddleSpeeds() {
    // Calculate paddle speed based on average ball velocity
    // Higher ball speed = faster paddle movement
    // Min speed: 15, Max speed: 35
    if (balls.isNotEmpty) {
      double totalSpeed = 0;
      for (final ball in balls) {
        totalSpeed += (ball.velocityX.abs() + ball.velocityY.abs()) / 2;
      }
      final avgBallSpeed = totalSpeed / balls.length;
      final paddleSpeed = (15 + (avgBallSpeed * 1.5).clamp(0, 20)).toDouble();
      leftPaddle.setSpeed(paddleSpeed);
      rightPaddle.setSpeed(paddleSpeed);
    }
  }

  void _applyBrickSpeedBoost(Ball ball, Color brickColor) {
    // Speed boost based on brick color
    double speedMultiplier = 1.0;

    if (brickColor == Colors.yellow) {
      speedMultiplier = 1.05; // 5% increase
    } else if (brickColor == Colors.cyan) {
      speedMultiplier = 1.08; // 8% increase
    } else if (brickColor == Colors.lime) {
      speedMultiplier = 1.1; // 10% increase
    } else if (brickColor == Colors.orange) {
      speedMultiplier = 1.12; // 12% increase
    } else if (brickColor == Colors.pink) {
      speedMultiplier = 1.15; // 15% increase
    } else if (brickColor == Colors.purple) {
      speedMultiplier = 1.2; // 20% increase
    }

    // Apply the speed boost with speed limits
    // Max speed cap: 15 for each velocity component
    const maxSpeed = 15.0;
    const minSpeed = 3.0;

    ball.velocityX = (ball.velocityX * speedMultiplier)
        .clamp(-maxSpeed, maxSpeed)
        .toDouble();
    ball.velocityY = (ball.velocityY * speedMultiplier)
        .clamp(-maxSpeed, maxSpeed)
        .toDouble();
  }

  void moveLeftPaddleUp() {
    leftPaddle.moveUp();
  }

  void moveLeftPaddleDown() {
    leftPaddle.moveDown(screenHeight);
  }

  void moveRightPaddleUp() {
    rightPaddle.moveUp();
  }

  void moveRightPaddleDown() {
    rightPaddle.moveDown(screenHeight);
  }

  void resetGame() {
    leftScore = 0;
    rightScore = 0;
    leftBrickScore = 0;
    rightBrickScore = 0;
    gameRunning = true;
    initialize();
  }

  void togglePause() {
    gameRunning = !gameRunning;
  }
}
