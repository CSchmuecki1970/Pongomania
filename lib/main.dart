import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/game_manager.dart';
import 'painters/game_painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pong Game',
      theme: ThemeData.dark(),
      home: const PongGameScreen(),
    );
  }
}

class PongGameScreen extends StatefulWidget {
  const PongGameScreen({Key? key}) : super(key: key);

  @override
  State<PongGameScreen> createState() => _PongGameScreenState();
}

class _PongGameScreenState extends State<PongGameScreen>
    with SingleTickerProviderStateMixin {
  late GameManager gameManager;
  late AnimationController animationController;
  final Set<LogicalKeyboardKey> pressedKeys = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    animationController.addListener(() {
      if (_initialized) {
        setState(() {
          gameManager.update();
          handleInput();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        initializeGame();
      }
    });
  }

  void initializeGame() {
    final size = MediaQuery.of(context).size;
    gameManager = GameManager(
      screenWidth: size.width,
      screenHeight: size.height,
    );
    setState(() {
      _initialized = true;
    });
  }

  void handleInput() {
    if (pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      gameManager.moveLeftPaddleUp();
    }
    if (pressedKeys.contains(LogicalKeyboardKey.keyS)) {
      gameManager.moveLeftPaddleDown();
    }
    if (pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      gameManager.moveRightPaddleUp();
    }
    if (pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      gameManager.moveRightPaddleDown();
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          pressedKeys.add(event.logicalKey);
          if (event.logicalKey == LogicalKeyboardKey.space) {
            gameManager.togglePause();
          }
        } else if (event is RawKeyUpEvent) {
          pressedKeys.remove(event.logicalKey);
        }
        return KeyEventResult.handled;
      },
      child: Scaffold(
        body: _initialized
            ? CustomPaint(
                painter: GamePainter(gameManager: gameManager),
                child: Container(),
              )
            : const Center(child: CircularProgressIndicator()),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'pause',
              onPressed: () {
                setState(() {
                  gameManager.togglePause();
                });
              },
              tooltip: 'Pause',
              child: Icon(
                _initialized && gameManager.gameRunning
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: 'reset',
              onPressed: () {
                setState(() {
                  gameManager.resetGame();
                });
              },
              tooltip: 'Reset',
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}
