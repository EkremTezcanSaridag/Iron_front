import 'package:audioplayers/audioplayers.dart';

class Sfx {
  Sfx._();

  static final AudioPlayer _music = AudioPlayer();
  static final Map<String, AudioPlayer> _fx = {};
  static bool muted = false;
  static String? _currentMusic;

  static Future<void> play(String name) async {
    if (muted) return;
    try {
      final p = _fx.putIfAbsent(name, AudioPlayer.new);
      await p.stop();
      final file = _fileFor(name);
      await p.play(AssetSource(file), volume: 0.7);
    } catch (_) {}
  }

  static Future<void> playMusic(String name) async {
    if (muted) return;
    if (_currentMusic == name) return;
    _currentMusic = name;
    try {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.35);
      await _music.play(AssetSource(_fileFor(name)));
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
    _currentMusic = null;
    await _music.stop();
  }

  static String _fileFor(String name) {
    if (name == 'ambient' || name == 'menu_ambient') {
      return 'audio/$name.wav';
    }
    return 'audio/$name.ogg';
  }
}
