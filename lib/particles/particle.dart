import 'package:flutter/material.dart';
import 'dart:math';

class Particle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late double size;
  late Color color;
  late double life; // 0.0 to 1.0
  late double maxLife;

  Particle({
    required double startX,
    required double startY,
    required double screenWidth,
    required double screenHeight,
  }) {
    final random = Random();
    x = startX;
    y = startY;

    // Random velocity in all directions - much faster explosive burst
    final angle = random.nextDouble() * 2 * pi;
    final speed = 3.5 + random.nextDouble() * 6.5; // Even faster burst
    vx = cos(angle) * speed;
    vy = sin(angle) * speed;

    // Smaller particles for explosive effect
    size = 0.8 + random.nextDouble() * 2.5;

    // Bright neon colors for 80s arcade style
    final colors = [
      const Color(0xFF00FF00), // Neon green
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFFFF0080), // Hot pink
      const Color(0xFF00FF80), // Neon teal
      const Color(0xFFFF6600), // Neon orange
      const Color(0xFFFF0000), // Bright red
      const Color(0xFF00FF00), // Lime green
      const Color(0xFFFF33FF), // Bright magenta
    ];
    color = colors[random.nextInt(colors.length)];

    maxLife = 1.5 + random.nextDouble() * 2.5; // 1.5-4 seconds
    life = maxLife;
  }

  void update(double deltaTime, double screenWidth, double screenHeight) {
    x += vx;
    y += vy;

    // Slow decay
    vy += 0.05; // Slight gravity effect

    life -= deltaTime / 1000.0;
  }

  bool isAlive() => life > 0;

  double get opacity => (life / maxLife).clamp(0.0, 1.0);

  bool isOutOfBounds(double screenWidth, double screenHeight) {
    return x < -100 ||
        x > screenWidth + 100 ||
        y < -100 ||
        y > screenHeight + 100;
  }
}
