import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:sensors_plus/sensors_plus.dart';
import 'models/game_manager.dart';
import 'painters/game_painter.dart';
import 'screens/menu_screen.dart';
import 'services/sound_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sound manager
  await SoundManager().initialize();

  // Lock to landscape orientations only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pong Game',
      theme: ThemeData.dark(),
      home: const MenuScreen(),
    );
  }
}

class PongGameScreen extends StatefulWidget {
  final GameModeSelection gameMode;

  const PongGameScreen({
    super.key,
    this.gameMode = GameModeSelection.twoPlayer,
  });

  @override
  State<PongGameScreen> createState() => _PongGameScreenState();
}

class _PongGameScreenState extends State<PongGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameManager gameManager;
  late AnimationController animationController;
  final Set<LogicalKeyboardKey> pressedKeys = {};
  bool _initialized = false;
  Size? _lastScreenSize;
  bool _buttonsVisible = false;
  int _centerTapCount = 0;
  Timer? _tapResetTimer;
  double? _lastLeftTouchY;
  double? _lastRightTouchY;
  bool _isSinglePlayer = false;

  // Android split-screen touch control state
  bool _isTouchingScreen = false;
  bool _touchInUpperHalf = false;
  double? _lastSwipeY; // Track Y position for swipe-to-shoot detection

  // Game over screen auto-scroll
  late AnimationController _gameOverScrollController;
  late Animation<double> _scrollAnimation;
  final ScrollController _gameOverScrollCtrl = ScrollController();

  // Accelerometer variables for tilt controls
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _accelerometerX = 0.0;
  double _accelerometerY = 0.0;
  double _accelerometerZ = 0.0;
  bool _useTiltControls = false; // Only on mobile devices

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    animationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    animationController.addListener(() {
      if (_initialized) {
        setState(() {
          gameManager.update();
          handleInput();

          // Start auto-scroll animation when game over
          if (gameManager.gameOver && !_gameOverScrollController.isAnimating) {
            _startGameOverScroll();
          }
        });
      }
    });

    // Initialize game over scroll animation
    _gameOverScrollController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _scrollAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _gameOverScrollController,
        curve: Curves.easeInOut,
      ),
    );

    _scrollAnimation.addListener(() {
      if (_gameOverScrollCtrl.hasClients) {
        final maxScroll = _gameOverScrollCtrl.position.maxScrollExtent;
        final scrollPos = maxScroll * _scrollAnimation.value;
        _gameOverScrollCtrl.jumpTo(scrollPos);
      }
    });

    // Set game mode based on passed parameter
    _isSinglePlayer = widget.gameMode == GameModeSelection.singlePlayer;

    // Initialize tilt controls for mobile devices
    _initializeTiltControls();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        initializeGame();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle when app returns from background
    if (state == AppLifecycleState.resumed && _initialized) {
      final size = MediaQuery.of(context).size;
      if (_lastScreenSize != size) {
        // Screen size changed, reinitialize
        initializeGame();
      }
    }
  }

  @override
  void didChangeMetrics() {
    // Called when screen orientation changes or size changes
    super.didChangeMetrics();
    if (_initialized && mounted) {
      final size = MediaQuery.of(context).size;
      if (_lastScreenSize != size) {
        // Orientation changed, reinitialize game with new dimensions
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            initializeGame();
          }
        });
      }
    }
  }

  void initializeGame() {
    final size = MediaQuery.of(context).size;
    _lastScreenSize = size;

    // Use full screen size
    gameManager = GameManager(
      screenWidth: size.width,
      screenHeight: size.height,
      isSinglePlayer: _isSinglePlayer,
    );
    setState(() {
      _initialized = true;
    });
    
    // Start background music and play game start sound
    SoundManager().playBackgroundMusic();
    SoundManager().playGameStart();
  }

  void _initializeTiltControls() {
    // Only enable tilt controls on mobile devices (Android/iOS)
    if (Platform.isAndroid || Platform.isIOS) {
      _useTiltControls = true;
      _accelerometerSubscription = accelerometerEvents.listen((
        AccelerometerEvent event,
      ) {
        setState(() {
          _accelerometerX = event.x;
          _accelerometerY = event.y;
          _accelerometerZ = event.z;
        });
      });
    }
  }

  void handleInput() {
    if (_isSinglePlayer) {
      // Single player mode: only left paddle controls are active

      // Android split-screen touch controls (takes priority)
      if (Platform.isAndroid && _isTouchingScreen) {
        if (_touchInUpperHalf) {
          gameManager.moveLeftPaddleUp();
        } else {
          gameManager.moveLeftPaddleDown();
        }
      } else if (_useTiltControls) {
        // Use tilt controls for left paddle - X axis for landscape mode
        double tiltThreshold = 2.0; // Minimum tilt to register movement
        if (_accelerometerX > tiltThreshold) {
          gameManager.moveLeftPaddleDown();
        } else if (_accelerometerX < -tiltThreshold) {
          gameManager.moveLeftPaddleUp();
        }
      } else {
        // Keyboard controls
        if (pressedKeys.contains(LogicalKeyboardKey.keyW)) {
          gameManager.moveLeftPaddleUp();
        }
        if (pressedKeys.contains(LogicalKeyboardKey.keyS)) {
          gameManager.moveLeftPaddleDown();
        }
      }
      // Shooter mode for left paddle only
      if (pressedKeys.contains(LogicalKeyboardKey.keyD)) {
        double shootAngle = 0.0;
        if (pressedKeys.contains(LogicalKeyboardKey.keyW)) {
          shootAngle = -1.0; // Shoot up
        } else if (pressedKeys.contains(LogicalKeyboardKey.keyS)) {
          shootAngle = 1.0; // Shoot down
        }
        gameManager.shootFromLeftPaddle(shootAngle);
      }
    } else {
      // Two player mode: both paddle controls are active
      if (_useTiltControls) {
        // Use tilt controls for both paddles - X axis for landscape mode
        double tiltThreshold = 2.0; // Minimum tilt to register movement
        if (_accelerometerX > tiltThreshold) {
          gameManager.moveLeftPaddleDown();
          gameManager.moveRightPaddleDown();
        } else if (_accelerometerX < -tiltThreshold) {
          gameManager.moveLeftPaddleUp();
          gameManager.moveRightPaddleUp();
        }
      } else {
        // Keyboard controls
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
      // Windows single-player controls (both paddles)
      if (pressedKeys.contains(LogicalKeyboardKey.keyT)) {
        gameManager.moveLeftPaddleUp();
        gameManager.moveRightPaddleUp();
      }
      if (pressedKeys.contains(LogicalKeyboardKey.keyG)) {
        gameManager.moveLeftPaddleDown();
        gameManager.moveRightPaddleDown();
      }
      // Shooter mode controls - vary angle with movement keys
      if (pressedKeys.contains(LogicalKeyboardKey.keyD)) {
        double shootAngle = 0.0;
        if (pressedKeys.contains(LogicalKeyboardKey.keyW)) {
          shootAngle = -1.0; // Shoot up
        } else if (pressedKeys.contains(LogicalKeyboardKey.keyS)) {
          shootAngle = 1.0; // Shoot down
        }
        gameManager.shootFromLeftPaddle(shootAngle);
      }
      // Windows single-player shoot (L key - shoots from both paddles)
      if (pressedKeys.contains(LogicalKeyboardKey.keyL)) {
        double shootAngle = 0.0;
        if (pressedKeys.contains(LogicalKeyboardKey.keyT)) {
          shootAngle = -1.0; // Shoot up
        } else if (pressedKeys.contains(LogicalKeyboardKey.keyG)) {
          shootAngle = 1.0; // Shoot down
        }
        gameManager.shootFromLeftPaddle(shootAngle);
        gameManager.shootFromRightPaddle(shootAngle);
      }
      if (pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
        double shootAngle = 0.0;
        if (pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
          shootAngle = -1.0; // Shoot up
        } else if (pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
          shootAngle = 1.0; // Shoot down
        }
        gameManager.shootFromRightPaddle(shootAngle);
      }
    }
  }

  void handleTouchInput(Offset position, Size canvasSize) {
    // For Android single-player, use split-screen controls in both modes
    // Top half = move up, bottom half = move down
    if (Platform.isAndroid && _isSinglePlayer) {
      _isTouchingScreen = true;
      _touchInUpperHalf = position.dy < canvasSize.height / 2;

      // In shooter mode, also detect swipe gestures for shooting
      if (gameManager.gameMode == GameMode.shooter &&
          !gameManager.isLeftPaddleFrozen()) {
        if (_lastSwipeY != null) {
          final deltaY = position.dy - _lastSwipeY!;
          if (deltaY.abs() > 30) {
            // Slightly larger threshold for deliberate swipes
            gameManager.shootFromLeftPaddle(deltaY > 0 ? 1 : -1);
            _lastSwipeY = null; // Reset to prevent rapid-fire shooting
          }
        } else {
          _lastSwipeY = position.dy;
        }
      }

      return; // Skip the rest of the function for Android single-player
    }

    // Check if tap is in center area (within 25% of center)
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    final tolerance = 150.0; // pixels from center

    if ((position.dx - centerX).abs() < tolerance &&
        (position.dy - centerY).abs() < tolerance) {
      // Center tap detected
      _centerTapCount++;

      // Reset timer on new tap
      _tapResetTimer?.cancel();
      _tapResetTimer = Timer(const Duration(milliseconds: 500), () {
        setState(() {
          _centerTapCount = 0;
        });
      });

      if (_centerTapCount >= 2) {
        setState(() {
          _buttonsVisible = !_buttonsVisible;
          _centerTapCount = 0;
        });
        _tapResetTimer?.cancel();
      }
      return;
    }

    // Check if in shooter mode
    if (gameManager.gameMode == GameMode.shooter) {
      if (!gameManager.isLeftPaddleFrozen()) {
        gameManager.setLeftPaddlePosition(position.dy);

        // Detect shooting gesture - swipe up/down
        if (_lastLeftTouchY != null) {
          final deltaY = position.dy - _lastLeftTouchY!;
          if (deltaY.abs() > 20) {
            // Significant Y movement - shoot
            gameManager.shootFromLeftPaddle(deltaY > 0 ? 1 : -1);
          }
        }
        _lastLeftTouchY = position.dy;
      }

      // In single player mode, don't allow right paddle control (AI controls it)
      if (!_isSinglePlayer && !gameManager.isRightPaddleFrozen()) {
        gameManager.setRightPaddlePosition(position.dy);

        // Detect shooting gesture - swipe up/down
        if (_lastRightTouchY != null) {
          final deltaY = position.dy - _lastRightTouchY!;
          if (deltaY.abs() > 20) {
            // Significant Y movement - shoot
            gameManager.shootFromRightPaddle(deltaY > 0 ? 1 : -1);
          }
        }
        _lastRightTouchY = position.dy;
      }
      return;
    }

    // Normal pong mode paddle control
    // In single player mode, only allow left paddle control (AI controls right)
    if (_isSinglePlayer) {
      // Single player: only left side controls the player paddle
      gameManager.setLeftPaddlePosition(position.dy);
      _lastLeftTouchY = null;
      _lastRightTouchY = null;
    } else {
      // Two player mode: touch position controls corresponding side
      // Left side of screen controls left paddle
      if (position.dx < canvasSize.width / 2) {
        // Direct position mapping: paddle Y follows finger Y
        gameManager.setLeftPaddlePosition(position.dy);
        _lastLeftTouchY = null;
        _lastRightTouchY = null;
      } else {
        // Right side controls right paddle
        gameManager.setRightPaddlePosition(position.dy);
        _lastLeftTouchY = null;
        _lastRightTouchY = null;
      }
    }
  }

  void _startGameOverScroll() {
    if (_gameOverScrollCtrl.hasClients) {
      _gameOverScrollController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animationController.dispose();
    _gameOverScrollController.dispose();
    _gameOverScrollCtrl.dispose();
    _tapResetTimer?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  Widget _buildGameOverScreen() {
    String winnerName;
    if (_isSinglePlayer) {
      winnerName = gameManager.winner == 'left' ? 'YOU WIN!' : 'AI WINS!';
    } else {
      winnerName = gameManager.winner == 'left'
          ? 'PLAYER 1 WINS!'
          : 'PLAYER 2 WINS!';
    }

    final winnerColor = gameManager.winner == 'left'
        ? const Color(0xFF00FF00) // Neon green
        : const Color(0xFFFF00FF); // Neon magenta

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        // 80s grid pattern overlay
        image: DecorationImage(
          image: NetworkImage(''),
          fit: BoxFit.cover,
          opacity: 0.1,
          onError: (exception, stackTrace) {},
        ),
      ),
      child: SingleChildScrollView(
        controller: _gameOverScrollCtrl,
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // GAME OVER title with retro styling
              Stack(
                children: [
                  // Outer glow
                  Text(
                    '▬▬▬ GAME OVER ▬▬▬',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 6
                        ..color = const Color(0xFF00FFFF).withOpacity(0.5),
                      shadows: List.generate(
                        3,
                        (i) => Shadow(
                          blurRadius: 20.0 * (i + 1),
                          color: const Color(0xFF00FFFF),
                        ),
                      ),
                    ),
                  ),
                  // Main text
                  Text(
                    '▬▬▬ GAME OVER ▬▬▬',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00FFFF), // Neon cyan
                      shadows: List.generate(
                        5,
                        (i) => Shadow(
                          blurRadius: 10.0,
                          color: const Color(0xFF00FFFF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Winner announcement
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: winnerColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: winnerColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Glow effect
                    Text(
                      winnerName,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = winnerColor.withOpacity(0.5),
                      ),
                    ),
                    // Main text
                    Text(
                      winnerName,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: winnerColor,
                        shadows: List.generate(
                          3,
                          (i) => Shadow(blurRadius: 15.0, color: winnerColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Score display - retro style
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: const Color(0xFFFFFF00), // Neon yellow
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFFF00).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '═══ FINAL SCORE ═══',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFFF00),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Left player score
                        Column(
                          children: [
                            Text(
                              _isSinglePlayer ? 'YOU' : 'P1',
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(0xFF00FF00),
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${gameManager.leftScore}',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00FF00),
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: const Color(0xFF00FF00),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Divider
                        Text(
                          '│',
                          style: TextStyle(
                            fontSize: 48,
                            color: const Color(0xFFFFFF00).withOpacity(0.5),
                          ),
                        ),
                        // Right player score
                        Column(
                          children: [
                            Text(
                              _isSinglePlayer ? 'AI' : 'P2',
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(0xFFFF00FF),
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${gameManager.rightScore}',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF00FF),
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: const Color(0xFFFF00FF),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Buttons - retro arcade style
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 15,
                runSpacing: 15,
                children: [
                  _buildRetroButton(
                    label: '▶ RESTART',
                    color: const Color(0xFF00FF00),
                    onPressed: () {
                      setState(() {
                        _gameOverScrollController.stop();
                        _gameOverScrollController.reset();
                        if (_gameOverScrollCtrl.hasClients) {
                          _gameOverScrollCtrl.jumpTo(0);
                        }
                        gameManager.resetGame();
                      });
                    },
                  ),
                  _buildRetroButton(
                    label: '■ EXIT',
                    color: const Color(0xFFFF0000),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Retro footer
              Text(
                '▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF00FFFF).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRetroButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 2,
            shadows: [Shadow(blurRadius: 10, color: color)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
            ? Stack(
                children: [
                  // Game canvas
                  Listener(
                    onPointerSignal: (event) {
                      // Handle mouse wheel in single player mode
                      if (_isSinglePlayer &&
                          event.runtimeType.toString() ==
                              'PointerScrollEvent') {
                        final dy = (event as dynamic).scrollDelta.dy as double;
                        if (dy > 0) {
                          gameManager.moveLeftPaddleDown();
                        } else if (dy < 0) {
                          gameManager.moveLeftPaddleUp();
                        }
                      }
                    },
                    child: GestureDetector(
                      onTapDown: (details) {
                        handleTouchInput(details.localPosition, size);
                      },
                      onPanUpdate: (details) {
                        handleTouchInput(details.localPosition, size);
                      },
                      onPanEnd: (_) {
                        // Clear touch state when finger lifts
                        setState(() {
                          _isTouchingScreen = false;
                          _lastSwipeY = null;
                        });
                      },
                      onTapUp: (_) {
                        // Clear touch state when tap ends
                        setState(() {
                          _isTouchingScreen = false;
                          _lastSwipeY = null;
                        });
                      },
                      child: CustomPaint(
                        painter: GamePainter(gameManager: gameManager),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  // Game Over Overlay
                  if (gameManager.gameOver) _buildGameOverScreen(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
        floatingActionButton: _buttonsVisible
            ? Column(
                mainAxisAlignment: MainAxisAlignment.start,
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
                        _gameOverScrollController.stop();
                        _gameOverScrollController.reset();
                        if (_gameOverScrollCtrl.hasClients) {
                          _gameOverScrollCtrl.jumpTo(0);
                        }
                        gameManager.resetGame();
                        _buttonsVisible = false;
                      });
                    },
                    tooltip: 'Reset',
                    child: const Icon(Icons.refresh),
                  ),
                ],
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      ),
    );
  }
}
