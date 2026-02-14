import 'package:flutter/material.dart';
import '../services/sound_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SoundManager _soundManager = SoundManager();
  late bool _musicEnabled;
  late bool _sfxEnabled;
  late double _musicVolume;
  late double _sfxVolume;

  @override
  void initState() {
    super.initState();
    _musicEnabled = _soundManager.musicEnabled;
    _sfxEnabled = _soundManager.sfxEnabled;
    _musicVolume = _soundManager.musicVolume;
    _sfxVolume = _soundManager.sfxVolume;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Stack(
          children: [
            Text(
              '▬ SETTINGS ▬',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4
                  ..color = const Color(0xFF00FFFF).withOpacity(0.5),
              ),
            ),
            const Text(
              '▬ SETTINGS ▬',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FFFF),
                shadows: [
                  Shadow(blurRadius: 10, color: Color(0xFF00FFFF)),
                  Shadow(blurRadius: 20, color: Color(0xFF00FFFF)),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF00FFFF)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('🎵 MUSIC'),
            const SizedBox(height: 20),
            _buildToggle(
              label: 'ENABLE MUSIC',
              value: _musicEnabled,
              color: const Color(0xFF00FF00),
              onChanged: (value) async {
                setState(() => _musicEnabled = value);
                await _soundManager.setMusicEnabled(value);
              },
            ),
            const SizedBox(height: 15),
            _buildSlider(
              label: 'MUSIC VOLUME',
              value: _musicVolume,
              color: const Color(0xFF00FF00),
              enabled: _musicEnabled,
              onChanged: (value) async {
                setState(() => _musicVolume = value);
                await _soundManager.setMusicVolume(value);
              },
            ),
            const SizedBox(height: 40),
            _buildSectionHeader('🔊 SOUND EFFECTS'),
            const SizedBox(height: 20),
            _buildToggle(
              label: 'ENABLE SFX',
              value: _sfxEnabled,
              color: const Color(0xFFFF00FF),
              onChanged: (value) async {
                setState(() => _sfxEnabled = value);
                await _soundManager.setSfxEnabled(value);
              },
            ),
            const SizedBox(height: 15),
            _buildSlider(
              label: 'SFX VOLUME',
              value: _sfxVolume,
              color: const Color(0xFFFF00FF),
              enabled: _sfxEnabled,
              onChanged: (value) async {
                setState(() => _sfxVolume = value);
                await _soundManager.setSfxVolume(value);
              },
            ),
            const SizedBox(height: 40),
            _buildSectionHeader('🎮 SOUND PREVIEW'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildTestButton(
                  label: 'PADDLE',
                  color: const Color(0xFF00FFFF),
                  onPressed: () => _soundManager.playPaddleHit(),
                ),
                _buildTestButton(
                  label: 'WALL',
                  color: const Color(0xFFFFFF00),
                  onPressed: () => _soundManager.playWallHit(),
                ),
                _buildTestButton(
                  label: 'BRICK',
                  color: const Color(0xFFFF00FF),
                  onPressed: () => _soundManager.playBrickExplosion(),
                ),
                _buildTestButton(
                  label: 'WIN',
                  color: const Color(0xFF00FF00),
                  onPressed: () => _soundManager.playPlayerWin(),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '═══════════════════',
                style: TextStyle(
                  color: const Color(0xFF00FFFF).withOpacity(0.3),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF00FFFF), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FFFF).withOpacity(0.3),
              blurRadius: 15,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00FFFF),
            letterSpacing: 3,
            shadows: [Shadow(blurRadius: 10, color: Color(0xFF00FFFF))],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 2,
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                color: value ? color : Colors.black,
                border: Border.all(color: color, width: 2),
                boxShadow: value
                    ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]
                    : null,
              ),
              child: Center(
                child: Text(
                  value ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: value ? Colors.black : color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required Color color,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: color, width: 2),
          boxShadow: enabled
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: color.withOpacity(0.3),
                thumbColor: color,
                overlayColor: color.withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                onChanged: enabled ? onChanged : null,
                min: 0.0,
                max: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
