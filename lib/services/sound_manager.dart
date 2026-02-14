import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  double _musicVolume = 0.7;
  double _sfxVolume = 0.8;
  
  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool('music_enabled') ?? true;
    _sfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    _musicVolume = prefs.getDouble('music_volume') ?? 0.7;
    _sfxVolume = prefs.getDouble('sfx_volume') ?? 0.8;
    
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(_musicVolume);
    await _sfxPlayer.setVolume(_sfxVolume);
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', enabled);
    
    if (!enabled) {
      await _musicPlayer.stop();
    } else {
      await playBackgroundMusic();
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sfx_enabled', enabled);
  }

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_volume', volume);
    await _musicPlayer.setVolume(volume);
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sfx_volume', volume);
    await _sfxPlayer.setVolume(volume);
  }

  // Background Music
  Future<void> playBackgroundMusic() async {
    if (!_musicEnabled) return;
    
    try {
      await _musicPlayer.play(AssetSource('sounds/background_music.mp3'));
    } catch (e) {
      // Sound file not found - silent fail for now
    }
  }

  Future<void> stopBackgroundMusic() async {
    await _musicPlayer.stop();
  }

  // Sound Effects
  Future<void> playPaddleHit() async {
    if (!_sfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('sounds/paddle_hit.mp3'));
    } catch (e) {
      // Sound file not found
    }
  }

  Future<void> playWallHit() async {
    if (!_sfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('sounds/wall_hit.mp3'));
    } catch (e) {
      // Sound file not found
    }
  }

  Future<void> playBrickExplosion() async {
    if (!_sfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('sounds/brick_explosion.mp3'));
    } catch (e) {
      // Sound file not found
    }
  }

  Future<void> playPlayerWin() async {
    if (!_sfxEnabled) return;
    
    try {
      await _musicPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/player_win.mp3'));
    } catch (e) {
      // Sound file not found
    }
  }

  Future<void> playAIWin() async {
    if (!_sfxEnabled) return;
    
    try {
      await _musicPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/ai_win.mp3'));
    } catch (e) {
      // Sound file not found
    }
  }

  Future<void> playGameStart() async {
    if (!_sfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('sounds/game_start.mp3'));
    } catch (e) {
      // Sound file not found
    }
  }

  void dispose() {
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
