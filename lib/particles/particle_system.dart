import 'package:flutter/material.dart';
import 'dart:math';
import 'particle.dart';

class ParticleSystem {
  final List<Particle> particles = [];
  final double screenWidth;
  final double screenHeight;
  final Random random = Random();
  int frameCount = 0;

  ParticleSystem({required this.screenWidth, required this.screenHeight});

  void update(double deltaTime) {
    frameCount++;

    // Spawn new particles continuously
    if (frameCount % 5 == 0) {
      spawnRandomParticle();
    }

    // Update all particles
    for (int i = particles.length - 1; i >= 0; i--) {
      particles[i].update(deltaTime, screenWidth, screenHeight);

      if (!particles[i].isAlive() ||
          particles[i].isOutOfBounds(screenWidth, screenHeight)) {
        particles.removeAt(i);
      }
    }
  }

  void spawnRandomParticle() {
    // Spawn particles from random edges
    late double x, y;

    final edge = random.nextInt(4);
    switch (edge) {
      case 0: // Top
        x = random.nextDouble() * screenWidth;
        y = -5;
      case 1: // Bottom
        x = random.nextDouble() * screenWidth;
        y = screenHeight + 5;
      case 2: // Left
        x = -5;
        y = random.nextDouble() * screenHeight;
      case 3: // Right
        x = screenWidth + 5;
        y = random.nextDouble() * screenHeight;
      default:
        x = screenWidth / 2;
        y = screenHeight / 2;
    }

    particles.add(
      Particle(
        startX: x,
        startY: y,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      ),
    );
  }

  void spawnBurstAtPosition(double x, double y, int count) {
    // Make more particles with smaller size for explosive effect
    final particleCount = count * 2; // Double the particles
    for (int i = 0; i < particleCount; i++) {
      final particle = Particle(
        startX: x,
        startY: y,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      particles.add(particle);
    }
  }

  void draw(Canvas canvas) {
    for (var particle in particles) {
      final pos = Offset(particle.x, particle.y);

      // Draw outer glow for neon effect
      canvas.drawCircle(
        pos,
        particle.size + 2,
        Paint()
          ..color = particle.color.withValues(alpha: particle.opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Draw the bright particle core
      canvas.drawCircle(
        pos,
        particle.size,
        Paint()
          ..color = particle.color.withValues(alpha: particle.opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  void clear() {
    particles.clear();
  }
}
