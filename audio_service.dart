import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _player = AudioPlayer();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  Future<void> playSuccessSound() async {
    try {
      await _player.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      print('Error playing success sound: $e');
    }
  }

  Future<void> playFailureSound() async {
    try {
      await _player.play(AssetSource('sounds/failure.mp3'));
    } catch (e) {
      print('Error playing failure sound: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
} 