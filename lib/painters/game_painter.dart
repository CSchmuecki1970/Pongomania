import 'package:flutter/material.dart';
import 'dart:math';
import '../models/game_manager.dart';
import '../models/game_objects.dart';

class GamePainter extends CustomPainter {
  final GameManager gameManager;

  GamePainter({required this.gameManager});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1a1a1a),
    );

    // Draw boundary around game field
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Draw center line
    final centerLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 10),
        centerLinePaint,
      );
    }

    // Draw paddles dynamically based on ball count
    _drawDynamicPaddles(canvas);

    // Draw shooter mode paddles if active
    if (gameManager.gameMode == GameMode.shooter) {
      // Left paddle as ">" shape
      _drawShooterPaddle(
        canvas,
        gameManager.leftPaddle,
        '>',
        Colors.blue,
        gameManager.isLeftPaddleFrozen(),
      );

      // Right paddle as "<" shape
      _drawShooterPaddle(
        canvas,
        gameManager.rightPaddle,
        '<',
        Colors.red,
        gameManager.isRightPaddleFrozen(),
      );

      // Draw shooter balls
      for (var sBall in gameManager.shooterBalls) {
        final color = sBall.owner == 'left' ? Colors.blue : Colors.red;
        canvas.drawCircle(
          Offset(sBall.x, sBall.y),
          sBall.radius,
          Paint()..color = color,
        );
      }
    }

    // Draw bricks with glow effect and shape-specific rendering
    for (var brick in gameManager.bricks) {
      _drawBrickWithShape(canvas, brick);
    }

    // Draw golden bar if it exists - special trigger for the brick wall!
    if (gameManager.goldenBar != null) {
      final goldenRect = gameManager.goldenBar!.getRect();

      // Draw a pulsing aura/glow
      canvas.drawRect(
        goldenRect.inflate(4),
        Paint()
          ..color = Colors.yellow.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
      );

      // Draw the main bar
      canvas.drawRect(goldenRect, Paint()..color = Colors.amber);

      // Draw a bright shiny border with more visibility
      canvas.drawRect(
        goldenRect,
        Paint()
          ..color = Colors.yellow
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }

    // Draw the single ball
    final ball = gameManager.ball;
    canvas.drawCircle(
      Offset(ball.x, ball.y),
      ball.radius,
      Paint()..color = Colors.white,
    );

    // Draw particle effects
    gameManager.particleSystem.draw(canvas);

    // Draw left player score and brick count together
    final leftScorePainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${gameManager.leftScore}',
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: ' (${gameManager.leftBrickScore})',
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 20,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    leftScorePainter.layout();
    leftScorePainter.paint(canvas, const Offset(20, 20));

    // Draw right player score and brick count together
    final rightScorePainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${gameManager.rightScore}',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: ' (${gameManager.rightBrickScore})',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 20,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    rightScorePainter.layout();
    rightScorePainter.paint(
      canvas,
      Offset(size.width - rightScorePainter.width - 20, 20),
    );

    // Draw brick count at top center
    final brickCountPainter = TextPainter(
      text: TextSpan(
        text: 'Bricks: ${gameManager.bricks.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    brickCountPainter.layout();
    brickCountPainter.paint(
      canvas,
      Offset(size.width / 2 - brickCountPainter.width / 2, 25),
    );

    // Draw pause status
    if (!gameManager.gameRunning) {
      final pausePainter = TextPainter(
        text: const TextSpan(
          text: 'PAUSED',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pausePainter.layout();
      pausePainter.paint(
        canvas,
        Offset(
          size.width / 2 - pausePainter.width / 2,
          size.height / 2 - pausePainter.height / 2,
        ),
      );
    }

    // Draw game mode indicator
    if (gameManager.isSinglePlayer) {
      final modePainter = TextPainter(
        text: const TextSpan(
          text: 'SINGLE PLAYER',
          style: TextStyle(
            color: Colors.lime,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      modePainter.layout();
      modePainter.paint(
        canvas,
        Offset(size.width / 2 - modePainter.width / 2, size.height - 30),
      );
    }
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;

  void _drawBrickWallPaddle(Canvas canvas, Paddle paddle) {
    // Draw the paddle as a brick wall texture
    final rect = paddle.getRect();

    // Draw main body as a series of brick tiles
    final brickWidth = 8.0;
    final brickHeight = 8.0;
    final colors = [
      Colors.deepOrange,
      Colors.orange,
      Colors.deepOrange,
      Colors.amber,
    ];

    for (double x = rect.left; x < rect.right; x += brickWidth) {
      for (double y = rect.top; y < rect.bottom; y += brickHeight) {
        final colorIndex =
            ((x - rect.left).toInt() + (y - rect.top).toInt()) ~/ 8;
        canvas.drawRect(
          Rect.fromLTWH(x, y, brickWidth - 0.5, brickHeight - 0.5),
          Paint()..color = colors[colorIndex % colors.length],
        );
      }
    }

    // Draw border
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawShooterPaddle(
    Canvas canvas,
    Paddle paddle,
    String symbol,
    Color color,
    bool isFrozen,
  ) {
    // Draw larger paddle in shooter mode with transparency if frozen
    final rect = paddle.getRect();
    final paint = Paint()
      ..color = isFrozen ? color.withOpacity(0.5) : color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw a larger rectangular paddle
    canvas.drawRect(rect, paint);

    // Draw the symbol (> or <) in the center with larger font size for visibility
    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: isFrozen ? color.withOpacity(0.5) : color,
          fontSize: 72,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawBrickWithShape(Canvas canvas, Brick brick) {
    final rect = brick.getRect();

    // Draw a glowing aura around the brick
    canvas.drawRect(
      rect.inflate(2),
      Paint()
        ..color = brick.color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3),
    );

    // Draw the brick based on its shape
    switch (brick.shape) {
      case BrickShape.square:
        // Standard rectangle
        canvas.drawRect(rect, Paint()..color = brick.color);
      case BrickShape.verticalBar:
        // Vertical bar - draw as a tall rectangle with a vertical line pattern
        canvas.drawRect(rect, Paint()..color = brick.color);
        // Add vertical stripes for visual distinction
        final stripeWidth = 2.0;
        final stripePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = stripeWidth;
        for (double x = rect.left; x < rect.right; x += 8) {
          canvas.drawLine(
            Offset(x, rect.top),
            Offset(x, rect.bottom),
            stripePaint,
          );
        }
      case BrickShape.horizontalBar:
        // Horizontal bar - draw as a wide rectangle with a horizontal line pattern
        canvas.drawRect(rect, Paint()..color = brick.color);
        // Add horizontal stripes for visual distinction
        final stripeHeight = 2.0;
        final hStripePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = stripeHeight;
        for (double y = rect.top; y < rect.bottom; y += 5) {
          canvas.drawLine(
            Offset(rect.left, y),
            Offset(rect.right, y),
            hStripePaint,
          );
        }
      case BrickShape.star:
        // Draw a 5-pointed star
        _drawStar(canvas, rect.center, rect.width / 2, brick.color);
      case BrickShape.circle:
        // Draw a circle
        canvas.drawCircle(
          rect.center,
          rect.width / 2,
          Paint()..color = brick.color,
        );
        // Add radial lines for visual effect
        final radius = rect.width / 2;
        final linePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = 1.5;
        for (int i = 0; i < 8; i++) {
          final angle = (i * 3.14159 * 2) / 8;
          final endX = rect.center.dx + radius * cos(angle);
          final endY = rect.center.dy + radius * sin(angle);
          canvas.drawLine(
            Offset(
              rect.center.dx + (radius * 0.3) * cos(angle),
              rect.center.dy + (radius * 0.3) * sin(angle),
            ),
            Offset(endX, endY),
            linePaint,
          );
        }
    }

    // Draw a bright border for 80s arcade effect
    switch (brick.shape) {
      case BrickShape.circle:
        // Draw circle border
        canvas.drawCircle(
          rect.center,
          rect.width / 2,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      case BrickShape.star:
        // Star border is drawn as part of the star shape
        break;
      default:
        // Rectangle border for other shapes
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    // Draw a 5-pointed star
    final points = <Offset>[];
    const numPoints = 5;
    const innerRadiusRatio = 0.4;

    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * pi) / numPoints - pi / 2;
      final r = (i.isEven) ? radius : radius * innerRadiusRatio;
      points.add(
        Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)),
      );
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    // Draw the star filled
    canvas.drawPath(path, Paint()..color = color);

    // Draw the star outline
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawDynamicPaddles(Canvas canvas) {
    // Always draw a single paddle per side
    canvas.drawRect(
      gameManager.leftPaddle.getRect(),
      Paint()..color = Colors.blue,
    );
    canvas.drawRect(
      gameManager.rightPaddle.getRect(),
      Paint()..color = Colors.red,
    );
  }

  void _drawPaddlesFromRects(
    Canvas canvas,
    List<Rect> paddleRects,
    Color color,
  ) {
    for (final rect in paddleRects) {
      canvas.drawRect(rect, Paint()..color = color);
    }
  }
}
