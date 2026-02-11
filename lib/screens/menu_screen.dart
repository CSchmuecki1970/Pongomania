import 'package:flutter/material.dart';
import '../particles/particle_system.dart';
import '../main.dart';

enum GameModeSelection { menu, singlePlayer, twoPlayer }

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late ParticleSystem particleSystem;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        particleSystem = ParticleSystem(
          screenWidth: size.width,
          screenHeight: size.height,
        );
        setState(() {
          _initialized = true;
        });

        animationController.addListener(() {
          if (_initialized && mounted) {
            setState(() {
              particleSystem.update(16); // 16ms per frame
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isLandscape = size.width > size.height;
    final isCompactLandscape = isLandscape && size.height < 450;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0a0a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
              ),
            ),
          ),
          // Particle system
          if (_initialized)
            CustomPaint(
              painter: ParticlePainter(particleSystem: particleSystem),
              size: Size.infinite,
            ),
          // Menu content
          if (isCompactLandscape)
            Center(
              child: SingleChildScrollView(
                child: _buildMenuColumn(
                  size,
                  isMobile,
                  isLandscape,
                  isCompactLandscape,
                ),
              ),
            )
          else
            Center(
              child: _buildMenuColumn(
                size,
                isMobile,
                isLandscape,
                isCompactLandscape,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuColumn(
    Size size,
    bool isMobile,
    bool isLandscape,
    bool isCompactLandscape,
  ) {
    if (isCompactLandscape) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildMenuButton(
                  label: 'SINGLE\nPLAYER',
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const PongGameScreen(
                          gameMode: GameModeSelection.singlePlayer,
                        ),
                      ),
                    );
                  },
                  primaryColor: Colors.green,
                  secondaryColor: Colors.lime,
                  isMobile: isMobile,
                  isCompactLandscape: isCompactLandscape,
                ),
              ),
              SizedBox(width: 12),
              Flexible(
                child: _buildMenuButton(
                  label: 'TWO\nPLAYER',
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const PongGameScreen(
                          gameMode: GameModeSelection.twoPlayer,
                        ),
                      ),
                    );
                  },
                  primaryColor: Colors.deepOrange,
                  secondaryColor: Colors.orange,
                  isMobile: isMobile,
                  isCompactLandscape: isCompactLandscape,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'PONG',
          style: TextStyle(
            fontSize: isCompactLandscape ? 40 : (isMobile ? 60 : 96),
            fontWeight: FontWeight.bold,
            color: Colors.cyan,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: Colors.cyan.withOpacity(0.8),
                offset: const Offset(0, 0),
              ),
              Shadow(
                blurRadius: 20,
                color: Colors.cyan.withOpacity(0.4),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompactLandscape ? 5 : (isMobile ? 20 : 40)),
        // Subtitle
        if (!isLandscape || !isMobile)
          Text(
            '80s ARCADE REVIVAL',
            style: TextStyle(
              fontSize: isMobile ? 14 : 24,
              color: Colors.deepPurple[300],
              fontStyle: FontStyle.italic,
              letterSpacing: 4,
            ),
          ),
        SizedBox(height: isCompactLandscape ? 10 : (isMobile ? 30 : 80)),
        // Game Mode Buttons
        if (isMobile)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: // Single Player Button
                _buildMenuButton(
                  label: 'SINGLE\nPLAYER',
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const PongGameScreen(
                          gameMode: GameModeSelection.singlePlayer,
                        ),
                      ),
                    );
                  },
                  primaryColor: Colors.green,
                  secondaryColor: Colors.lime,
                  isMobile: isMobile,
                  isCompactLandscape: isCompactLandscape,
                ),
              ),
              SizedBox(width: 15),
              Flexible(
                child: // Two Player Button
                _buildMenuButton(
                  label: 'TWO\nPLAYER',
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const PongGameScreen(
                          gameMode: GameModeSelection.twoPlayer,
                        ),
                      ),
                    );
                  },
                  primaryColor: Colors.deepOrange,
                  secondaryColor: Colors.orange,
                  isMobile: isMobile,
                  isCompactLandscape: isCompactLandscape,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              // Single Player Button
              _buildMenuButton(
                label: 'SINGLE PLAYER',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const PongGameScreen(
                        gameMode: GameModeSelection.singlePlayer,
                      ),
                    ),
                  );
                },
                primaryColor: Colors.green,
                secondaryColor: Colors.lime,
                isMobile: isMobile,
                isCompactLandscape: isCompactLandscape,
              ),
              SizedBox(height: 30),
              // Two Player Button
              _buildMenuButton(
                label: 'TWO PLAYER',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const PongGameScreen(
                        gameMode: GameModeSelection.twoPlayer,
                      ),
                    ),
                  );
                },
                primaryColor: Colors.deepOrange,
                secondaryColor: Colors.orange,
                isMobile: isMobile,
                isCompactLandscape: isCompactLandscape,
              ),
            ],
          ),
        SizedBox(height: isCompactLandscape ? 10 : (isMobile ? 30 : 60)),
        // Footer text with effect
        if (!isLandscape)
          Text(
            '↑ USE ARROW KEYS & W/S TO CONTROL ↑',
            style: TextStyle(
              fontSize: isMobile ? 10 : 14,
              color: const Color(0xFFFF00FF).withOpacity(0.7),
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (true) ...[
          SizedBox(height: isCompactLandscape ? 6 : (isMobile ? 10 : 16)),
          Text(
            'Pong`s 80s Revival (C) C Schmücker',
            style: TextStyle(
              fontSize: isCompactLandscape ? 10 : (isMobile ? 11 : 14),
              color: Colors.cyan.withOpacity(0.6),
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMenuButton({
    required String label,
    required VoidCallback onPressed,
    required Color primaryColor,
    required Color secondaryColor,
    required bool isMobile,
    required bool isCompactLandscape,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompactLandscape ? 30 : (isMobile ? 24 : 44),
              vertical: isCompactLandscape ? 15 : (isMobile ? 12 : 22),
            ),
            decoration: BoxDecoration(
              border: Border.all(color: primaryColor, width: 2),
              color: primaryColor.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompactLandscape ? 20 : (isMobile ? 16 : 30),
                fontWeight: FontWeight.bold,
                color: secondaryColor,
                letterSpacing: 2,
                shadows: [
                  Shadow(blurRadius: 5, color: secondaryColor.withOpacity(0.8)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final ParticleSystem particleSystem;

  ParticlePainter({required this.particleSystem});

  @override
  void paint(Canvas canvas, Size size) {
    particleSystem.draw(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
