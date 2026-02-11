import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:sensors_plus/sensors_plus.dart';
import 'models/game_manager.dart';
import 'painters/game_painter.dart';
import 'screens/menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
        });
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
      if (_useTiltControls) {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animationController.dispose();
    _tapResetTimer?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
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
            ? Listener(
                onPointerSignal: (event) {
                  // Handle mouse wheel in single player mode
                  if (_isSinglePlayer &&
                      event.runtimeType.toString() == 'PointerScrollEvent') {
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
                  child: CustomPaint(
                    painter: GamePainter(gameManager: gameManager),
                    size: Size.infinite,
                  ),
                ),
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
