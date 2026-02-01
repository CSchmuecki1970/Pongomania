import 'package:flutter/material.dart';
import '../models/game_manager.dart';

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

    // Draw left paddle
    canvas.drawRect(
      gameManager.leftPaddle.getRect(),
      Paint()..color = Colors.blue,
    );

    // Draw right paddle
    canvas.drawRect(
      gameManager.rightPaddle.getRect(),
      Paint()..color = Colors.red,
    );

    // Draw bricks
    for (var brick in gameManager.bricks) {
      canvas.drawRect(brick.getRect(), Paint()..color = brick.color);

      // Draw a border to make different shapes visually distinct
      canvas.drawRect(
        brick.getRect(),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // Draw golden bar if it exists
    if (gameManager.goldenBar != null) {
      canvas.drawRect(
        gameManager.goldenBar!.getRect(),
        Paint()..color = Colors.amber,
      );
      // Draw a shiny border
      canvas.drawRect(
        gameManager.goldenBar!.getRect(),
        Paint()
          ..color = Colors.yellow
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    // Draw all balls
    for (var ball in gameManager.balls) {
      canvas.drawCircle(
        Offset(ball.x, ball.y),
        ball.radius,
        Paint()..color = Colors.white,
      );
    }

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
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
