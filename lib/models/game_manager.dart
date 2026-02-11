import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'game_objects.dart';
import 'ai_paddle.dart';
import '../particles/particle_system.dart';

enum GameMode { pong, shooter }

class GameManager {
  late Paddle leftPaddle;
  late Paddle rightPaddle;
  late Ball ball;
  late List<Brick> bricks;
  late List<ShooterBall> shooterBalls;
  late GoldenBar? goldenBar;
  int leftScore = 0;
  int rightScore = 0;
  int leftBrickScore = 0; // Points from destroyed bricks
  int rightBrickScore = 0; // Points from destroyed bricks
  bool gameRunning = true;
  GameMode gameMode = GameMode.pong;
  bool isSinglePlayer = false; // Single player mode flag
  late AIPaddle? aiPaddle; // AI opponent for single player

  // Freeze timers for shooter mode
  int leftFreezeFrames = 0;
  int rightFreezeFrames = 0;
  static const int FREEZE_DURATION = 60; // 1 second at 60fps

  // Track which player hit the ball last
  String lastPaddleHit = 'right'; // 'left' or 'right'

  late double screenWidth;
  late double screenHeight;
  late ParticleSystem particleSystem;

  int frameCount = 0;
  static const int BRICK_SPAWN_DELAY = 300; // ~5 seconds at 60fps
  static const int BRICK_SPAWN_INTERVAL =
      120; // Spawn every ~2 seconds after first spawn
  static const int BRICK_SPAWN_INTERVAL_FAST =
      60; // Spawn every ~1 second after difficulty increase
  static const int DIFFICULTY_INCREASE_TIME =
      1800; // ~30 seconds at 60fps (double brick spawn rate)
  static const int SHOOTER_MODE_THRESHOLD =
      20; // Bricks to trigger shooter mode
  static const int WALL_SPAWN_MIN_INTERVAL = 2400; // ~40 seconds minimum
  static const int WALL_SPAWN_MAX_INTERVAL = 4800; // ~80 seconds maximum
  static const int GOLDEN_BAR_COOLDOWN = 3600; // 1 minute at 60fps

  late int nextWallSpawnTime; // Time when next wall should spawn
  int lastGoldenBarDestroyedFrame =
      -GOLDEN_BAR_COOLDOWN; // Initialize so golden bar can spawn immediately
  final Random random = Random();

  GameManager({
    required this.screenWidth,
    required this.screenHeight,
    this.isSinglePlayer = false,
  }) {
    initialize();
  }

  void initialize() {
    leftPaddle = Paddle(
      x: 10,
      y: screenHeight / 2 - 40,
    ); // Centered with new height
    rightPaddle = Paddle(x: screenWidth - 40, y: screenHeight / 2 - 40);
    ball = Ball(x: screenWidth / 2, y: screenHeight / 2);
    bricks = [];
    shooterBalls = [];
    goldenBar = null;
    frameCount = 0;
    lastPaddleHit = 'right';
    gameMode = GameMode.pong;
    leftFreezeFrames = 0;
    rightFreezeFrames = 0;
    particleSystem = ParticleSystem(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    nextWallSpawnTime =
        WALL_SPAWN_MIN_INTERVAL +
        random.nextInt(WALL_SPAWN_MAX_INTERVAL - WALL_SPAWN_MIN_INTERVAL);
    lastGoldenBarDestroyedFrame =
        -GOLDEN_BAR_COOLDOWN; // Reset cooldown tracker

    // Initialize AI if single player mode
    if (isSinglePlayer) {
      aiPaddle = AIPaddle(
        difficulty: 1.0,
      ); // Maximum difficulty for most responsive AI
    }
  }

  void update() {
    if (!gameRunning) return;

    frameCount++;

    // Update particle system
    particleSystem.update(16.67); // ~60fps, ~16.67ms per frame

    // Update paddle speeds based on ball velocity
    _updatePaddleSpeeds();

    // Update AI paddle in single player mode
    if (isSinglePlayer && aiPaddle != null) {
      aiPaddle!.update(rightPaddle, ball, screenHeight);
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

    // Surprise wall spawn - now triggered by golden bar
    // Spawn golden bar periodically as a special bonus
    if (frameCount >= nextWallSpawnTime) {
      // Check if cooldown has elapsed since last golden bar destruction
      final cooldownElapsed =
          frameCount - lastGoldenBarDestroyedFrame >= GOLDEN_BAR_COOLDOWN;
      if (goldenBar == null && cooldownElapsed) {
        // Spawn golden bar if it doesn't exist and cooldown has passed
        spawnGoldenBar();
      }
      nextWallSpawnTime =
          frameCount +
          WALL_SPAWN_MIN_INTERVAL +
          random.nextInt(WALL_SPAWN_MAX_INTERVAL - WALL_SPAWN_MIN_INTERVAL);
    }

    // Check if we should transition to shooter mode
    if (gameMode == GameMode.pong && bricks.length >= SHOOTER_MODE_THRESHOLD) {
      gameMode = GameMode.shooter;
    }

    // If in shooter mode and all bricks are gone, return to pong mode
    if (gameMode == GameMode.shooter && bricks.isEmpty) {
      gameMode = GameMode.pong;
      leftFreezeFrames = 0;
      rightFreezeFrames = 0;
      shooterBalls.clear();
    }

    // Update freeze timers
    if (leftFreezeFrames > 0) leftFreezeFrames--;
    if (rightFreezeFrames > 0) rightFreezeFrames--;
    // Update shooter balls
    if (gameMode == GameMode.shooter) {
      for (int i = shooterBalls.length - 1; i >= 0; i--) {
        final sBall = shooterBalls[i];
        sBall.update(screenWidth, screenHeight);

        // Check if out of bounds
        if (sBall.isOutOfBounds(screenWidth)) {
          shooterBalls.removeAt(i);
          continue;
        }

        // Check collision with other player paddles
        // Check collision with right paddle
        if (sBall.owner == 'left' &&
            checkCollision(sBall.getRect(), rightPaddle.getRect())) {
          rightFreezeFrames = FREEZE_DURATION;
          shooterBalls.removeAt(i);
          continue;
        }

        // Check collision with left paddle
        if (sBall.owner == 'right' &&
            checkCollision(sBall.getRect(), leftPaddle.getRect())) {
          leftFreezeFrames = FREEZE_DURATION;
          shooterBalls.removeAt(i);
          continue;
        }

        // Check brick collisions
        for (int j = bricks.length - 1; j >= 0; j--) {
          if (checkCollision(sBall.getRect(), bricks[j].getRect())) {
            if (sBall.owner == 'left') {
              leftBrickScore++;
            } else {
              rightBrickScore++;
            }

            // Spawn particle effects at brick center
            final brickRect = bricks[j].getRect();
            particleSystem.spawnBurstAtPosition(
              brickRect.center.dx,
              brickRect.center.dy,
              15, // Number of particles
            );

            bricks.removeAt(j);
            shooterBalls.removeAt(i);
            break;
          }
        }
      }
    }

    // Update all balls
    ball.update(screenWidth, screenHeight);

    // Check paddle collisions with left paddles
    // In single player mode, keep left paddle as single paddle (player controls it)
    // In two player mode, it can split into 2 paddles based on ball count
    if (checkCollision(ball.getRect(), leftPaddle.getRect())) {
      if (ball.velocityX < 0) {
        lastPaddleHit = 'left';
        ball.velocityX = -ball.velocityX;
        ball.x = leftPaddle.x + leftPaddle.width + ball.radius;
        ball.velocityY += (ball.y - (leftPaddle.getRect().center.dy)) * 0.05;
      }
    }

    // Check paddle collisions with right paddles
    // In single player mode, right paddle is always a single paddle (AI)
    // In two player mode, it can split into 2 paddles based on ball count
    if (checkCollision(ball.getRect(), rightPaddle.getRect())) {
      if (ball.velocityX > 0) {
        lastPaddleHit = 'right';
        ball.velocityX = -ball.velocityX;
        ball.x = rightPaddle.x - ball.radius;
        ball.velocityY += (ball.y - (rightPaddle.getRect().center.dy)) * 0.05;
      }
    }

    // Check golden bar collision with paddles
    if (goldenBar != null &&
        checkCollision(ball.getRect(), goldenBar!.getRect())) {
      // Golden bar triggers a random wall surprise!
      spawnRandomWall();
      goldenBar = null;
      lastGoldenBarDestroyedFrame =
          frameCount; // Mark when golden bar was destroyed
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

        // Spawn particle effects at brick center
        particleSystem.spawnBurstAtPosition(
          brickRect.center.dx,
          brickRect.center.dy,
          15, // Number of particles
        );

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
      ball = Ball(x: screenWidth / 2, y: screenHeight / 2);
    } else if (ball.x > screenWidth) {
      leftScore++;
      ball = Ball(x: screenWidth / 2, y: screenHeight / 2);
    }

    // Check ball-to-ball collisions and ensure minimum of 1 ball
    // No multi-ball collision logic needed

    // Update golden bar if it exists
    if (goldenBar != null) {
      goldenBar!.update(screenHeight);
    }
  }

  void spawnBall() {
    // Add a new ball at the center of the screen
    // Removed: multi-ball logic deleted
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
      case BrickShape.star:
        width = 40;
        height = 40;
        break;
      case BrickShape.circle:
        width = 40;
        height = 40;
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
      final brick = Brick.forPlatform(
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

  // Multi-paddle logic removed; always use single paddle per side

  void _updatePaddleSpeeds() {
    // Calculate paddle speed based on average ball velocity
    // Higher ball speed = faster paddle movement
    // On Android: slower, more manageable speeds
    final avgBallSpeed = (ball.velocityX.abs() + ball.velocityY.abs()) / 2;
    final maxPaddleSpeed = Platform.isAndroid ? 12.0 : 35.0;
    final paddleSpeed = (8 + (avgBallSpeed * 0.5)).clamp(8.0, maxPaddleSpeed);
    leftPaddle.setSpeed(paddleSpeed);
    rightPaddle.setSpeed(paddleSpeed);
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
    // Reduced max speed cap for Android playability
    final maxSpeed = Platform.isAndroid ? 8.0 : 15.0;
    const minSpeed = 3.0;

    ball.velocityX = (ball.velocityX * speedMultiplier)
        .clamp(-maxSpeed, maxSpeed)
        .toDouble();
    ball.velocityY = (ball.velocityY * speedMultiplier)
        .clamp(-minSpeed, maxSpeed)
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

  // Direct position-based paddle control for touch input
  void setLeftPaddlePosition(double y) {
    // Center the paddle on the given Y position
    double newY = y - (leftPaddle.height / 2);
    newY = newY.clamp(0, screenHeight - leftPaddle.height);
    leftPaddle.y = newY;
  }

  void setRightPaddlePosition(double y) {
    // Center the paddle on the given Y position
    double newY = y - (rightPaddle.height / 2);
    newY = newY.clamp(0, screenHeight - rightPaddle.height);
    rightPaddle.y = newY;
  }

  // Shooting methods for shooter mode
  void shootFromLeftPaddle(double shootDirection) {
    // shootDirection: negative = up, positive = down
    final shootSpeed = 6.0;
    final ball = ShooterBall(
      x: leftPaddle.x + leftPaddle.width,
      y: leftPaddle.y + leftPaddle.height / 2,
      velocityX: 5.0,
      velocityY: shootDirection * shootSpeed,
      owner: 'left',
    );
    shooterBalls.add(ball);
  }

  void shootFromRightPaddle(double shootDirection) {
    // shootDirection: negative = up, positive = down
    final shootSpeed = 6.0;
    final ball = ShooterBall(
      x: rightPaddle.x,
      y: rightPaddle.y + rightPaddle.height / 2,
      velocityX: -5.0,
      velocityY: shootDirection * shootSpeed,
      owner: 'right',
    );
    shooterBalls.add(ball);
  }

  bool isLeftPaddleFrozen() {
    return leftFreezeFrames > 0;
  }

  bool isRightPaddleFrozen() {
    return rightFreezeFrames > 0;
  }

  void spawnBrickWall() {
    // Clear all existing bricks and golden bar
    bricks.clear();
    goldenBar = null; // Remove golden bar so it doesn't get re-triggered

    // Create 4 vertical layers of vertical bricks (verticalBar shape)
    final brickWidth = 20.0; // Width of vertical bar
    final brickHeight = 60.0; // Height of vertical bar
    final numLayers = 4;

    // Colors for the wall (gradient effect with neon 80s style)
    final colors = [Colors.purple, Colors.pink, Colors.lime, Colors.cyan];

    // Calculate spacing for 4 layers across screen width
    final layerSpacing = screenWidth / (numLayers + 1);

    // For each layer (vertical column)
    for (int layer = 0; layer < numLayers; layer++) {
      final layerX = layerSpacing * (layer + 1) - brickWidth / 2;
      final layerColor = colors[layer];

      // Calculate how many vertical bricks fit in each column
      final numBricksInLayer = (screenHeight / brickHeight).ceil();

      // Spawn vertical bricks from top to bottom
      for (int i = 0; i < numBricksInLayer; i++) {
        final y = i * brickHeight;

        final brick = Brick.forPlatform(
          x: layerX,
          y: y,
          width: brickWidth,
          height: brickHeight,
          shape: BrickShape.verticalBar,
          color: layerColor,
        );
        bricks.add(brick);
      }
    }

    // No need to ensure player balls; only one ball is supported
  }

  void spawnRandomWall() {
    // Randomly choose between the wall types
    final wallTypes = ['brick', 'star', 'circle', 'middle'];
    final randomType = wallTypes[random.nextInt(wallTypes.length)];

    switch (randomType) {
      case 'star':
        spawnStarWall();
      case 'circle':
        spawnCircleWall();
      case 'middle':
        spawnMiddleWall();
      default:
        spawnBrickWall();
    }
  }

  void spawnStarWall() {
    // Clear all existing bricks and golden bar
    bricks.clear();
    goldenBar = null;

    // Create a star pattern with bricks radiating from center
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;
    final brickSize = 30.0;
    final numPoints = 5; // 5-pointed star
    final radius = screenHeight * 0.25;

    for (int i = 0; i < numPoints; i++) {
      // Calculate angle for each point
      final angle = (i * 2 * 3.14159) / numPoints - 3.14159 / 2;

      // Create line of bricks from center outward
      for (int j = 0; j < 3; j++) {
        final distance = radius * (0.3 + (j * 0.35));
        final x = centerX + (distance * cos(angle)) - brickSize / 2;
        final y = centerY + (distance * sin(angle)) - brickSize / 2;

        final brick = Brick.forPlatform(
          x: x,
          y: y,
          width: brickSize,
          height: brickSize,
          shape: BrickShape.star,
          color: Colors.yellow,
        );
        bricks.add(brick);
      }
    }

    // No need to ensure player balls; only one ball is supported
  }

  void spawnMiddleWall() {
    // Clear all existing bricks and golden bar
    bricks.clear();
    goldenBar = null;

    // Create a vertical wall in the middle with 4 bricks thick
    final centerX = screenWidth / 2;
    final brickWidth = 20.0;
    final brickHeight = 60.0;
    final numLayers = 4; // 4 bricks thick
    final colors = [Colors.green, Colors.lime, Colors.cyan, Colors.blue];

    // Create vertical columns from top to bottom
    final numRows = (screenHeight / brickHeight).ceil() + 1;

    for (int layer = 0; layer < numLayers; layer++) {
      // Offset each layer to the sides of center
      final offsetX = centerX + (layer - (numLayers - 1) / 2) * brickWidth;

      for (int row = 0; row < numRows; row++) {
        final brick = Brick.forPlatform(
          x: offsetX,
          y: row * brickHeight,
          width: brickWidth,
          height: brickHeight,
          shape: BrickShape.verticalBar,
          color: colors[layer],
        );
        bricks.add(brick);
      }
    }
  }

  void spawnCircleWall() {
    // Clear all existing bricks and golden bar
    bricks.clear();
    goldenBar = null;

    // Create concentric circles of bricks
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;
    final brickSize = 25.0;
    final numCircles = 3;
    final maxRadius = screenHeight * 0.3;

    final colors = [Colors.pink, Colors.cyan, Colors.lime];

    for (int circle = 0; circle < numCircles; circle++) {
      final circleRadius = maxRadius * (0.4 + (circle * 0.3));
      final circumference = 2 * 3.14159 * circleRadius;
      final bricksInCircle = (circumference / brickSize).ceil();

      for (int i = 0; i < bricksInCircle; i++) {
        final angle = (i * 2 * 3.14159) / bricksInCircle;
        final x = centerX + (circleRadius * cos(angle)) - brickSize / 2;
        final y = centerY + (circleRadius * sin(angle)) - brickSize / 2;

        final brick = Brick.forPlatform(
          x: x,
          y: y,
          width: brickSize,
          height: brickSize,
          shape: BrickShape.circle,
          color: colors[circle % colors.length],
        );
        bricks.add(brick);
      }
    }

    // No need to ensure player balls; only one ball is supported
  }

  // _ensurePlayerBalls removed: only one ball is supported

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
