import 'package:flutter/material.dart';
import 'dart:io';
import '../services/sound_manager.dart';

class Paddle {
  double x;
  double y;
  final double width;
  final double height;
  double baseSpeed = 15;

  Paddle({
    required this.x,
    required this.y,
    this.width = 20,
    this.height = 80, // Shorter paddle for better gameplay
  }) {
    // Adjust for platform
    if (Platform.isAndroid) {
      baseSpeed = 10;
    } else if (Platform.isWindows) {
      baseSpeed = 20; // Faster on Windows
    }
  }

  void moveUp() {
    if (y > 0) {
      y -= baseSpeed;
    }
  }

  void moveDown(double screenHeight) {
    if (y + height < screenHeight) {
      y += baseSpeed;
    }
  }

  void setSpeed(double speed) {
    baseSpeed = speed;
  }

  Rect getRect() {
    return Rect.fromLTWH(x, y, width, height);
  }
}

class Ball {
  double x;
  double y;
  double velocityX;
  double velocityY;
  final double radius;

  static const double DEFAULT_RADIUS = 8;
  static const double ANDROID_RADIUS = 4.8; // 60% of default

  Ball({
    required this.x,
    required this.y,
    this.velocityX = 5,
    this.velocityY = 5,
    double? radius,
  }) : radius =
           radius ?? (Platform.isAndroid ? ANDROID_RADIUS : DEFAULT_RADIUS) {
    // Adjust velocity for platform - make Android much slower for playability
    if (Platform.isAndroid) {
      velocityX *= 0.35; // Further reduced from 0.5 to 0.35
      velocityY *= 0.35;
    } else if (Platform.isWindows) {
      velocityX *= 1.3; // Faster on Windows
      velocityY *= 1.3;
    }
  }

  void update(double screenWidth, double screenHeight) {
    x += velocityX;
    y += velocityY;

    // Bounce off top and bottom
    if (y - radius <= 0 || y + radius >= screenHeight) {
      SoundManager().playWallHit();
      velocityY = -velocityY;
      y = y - radius <= 0 ? radius : screenHeight - radius;
    }
  }

  Rect getRect() {
    return Rect.fromCircle(center: Offset(x, y), radius: radius);
  }

  void reset(double screenWidth, double screenHeight) {
    x = screenWidth / 2;
    y = screenHeight / 2;
    velocityX = (velocityX.abs() + 1) * (velocityX > 0 ? 1 : -1);
    velocityY = 5;
  }
}

class Brick {
  double x;
  double y;
  final double width;
  final double height;
  final BrickShape shape;
  final Color color;

  Brick({
    required this.x,
    required this.y,
    this.width = 60,
    this.height = 20,
    this.shape = BrickShape.square,
    this.color = Colors.yellow,
  });

  // Factory method for platform-sized bricks
  factory Brick.forPlatform({
    required double x,
    required double y,
    double width = 60,
    double height = 20,
    BrickShape shape = BrickShape.square,
    Color color = Colors.yellow,
  }) {
    if (Platform.isAndroid) {
      width *= 0.5;
      height *= 0.5;
    }
    return Brick(
      x: x,
      y: y,
      width: width,
      height: height,
      shape: shape,
      color: color,
    );
  }

  Rect getRect() {
    return Rect.fromLTWH(x, y, width, height);
  }
}

enum BrickShape {
  square, // 60x20
  verticalBar, // 20x60
  horizontalBar, // 80x15
  star, // Star-shaped surprise wall
  circle, // Circle-shaped surprise wall
}

class GoldenBar {
  double x;
  double y;
  final double width;
  final double height;
  double velocityY;

  GoldenBar({
    required this.x,
    required this.y,
    this.width = 15,
    this.height = 60,
    this.velocityY = 3.0,
  }) {
    // Adjust for platform
    if (Platform.isAndroid) {
      velocityY *= 0.7; // Slower movement
    } else if (Platform.isWindows) {
      velocityY *= 1.3; // Faster on Windows
    }
  }

  void update(double screenHeight) {
    y += velocityY;

    // Bounce off top and bottom
    if (y <= 0 || y + height >= screenHeight) {
      velocityY = -velocityY;
      y = y <= 0 ? 0 : screenHeight - height;
    }
  }

  Rect getRect() {
    return Rect.fromLTWH(x, y, width, height);
  }
}

// Shooter ball - smaller ball shot by players in shooter mode
class ShooterBall {
  double x;
  double y;
  double velocityX;
  double velocityY;
  final double radius;
  final String owner; // 'left' or 'right' - which player shot it

  ShooterBall({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    this.radius = 3,
    required this.owner,
  });

  void update(double screenWidth, double screenHeight) {
    x += velocityX;
    y += velocityY;

    // Bounce off top and bottom
    if (y - radius <= 0 || y + radius >= screenHeight) {
      velocityY = -velocityY;
      y = y - radius <= 0 ? radius : screenHeight - radius;
    }
  }

  Rect getRect() {
    return Rect.fromCircle(center: Offset(x, y), radius: radius);
  }

  bool isOutOfBounds(double screenWidth) {
    return x < 0 || x > screenWidth;
  }
}
