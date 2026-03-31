/// Regional TTS Service for Storytelling
/// Provides regionally accented text-to-speech for temple audio guides
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Audio quality levels
enum AudioQuality {
  low,
  medium,
  high,
}

/// TTS state
enum TTSState {
  playing,
  paused,
  stopped,
  loading,
}

/// TTS Service for regional accents
class RegionalTTSService {
  final FlutterTts _flutterTts;
  
  // Voice configurations for Indian languages
  final Map<String, Map<String, dynamic>> _voiceConfigs = {
    'en': {
      'voices': ['en-US', 'en-GB', 'en-IN'],
      'defaultVoice': 'en-US',
      'rate': 0.9,
      'pitch': 1.0,
    },
    'hi': {
      'voices': ['hi-IN'],
      'defaultVoice': 'hi-IN',
      'rate': 0.8,
      'pitch': 1.0,
    },
    'ta': {
      'voices': ['ta-IN'],
      'defaultVoice': 'ta-IN',
      'rate': 0.75,
      'pitch': 1.0,
    },
    'te': {
      'voices': ['te-IN'],
      'defaultVoice': 'te-IN',
      'rate': 0.75,
      'pitch': 1.0,
    },
    'kn': {
      'voices': ['kn-IN'],
      'defaultVoice': 'kn-IN',
      'rate': 0.75,
      'pitch': 1.0,
    },
    'ml': {
      'voices': ['ml-IN'],
      'defaultVoice': 'ml-IN',
      'rate': 0.75,
      'pitch': 1.0,
    },
    'bn': {
      'voices': ['bn-IN'],
      'defaultVoice': 'bn-IN',
      'rate': 0.8,
      'pitch': 1.0,
    },
    'mr': {
      'voices': ['mr-IN'],
      'defaultVoice': 'mr-IN',
      'rate': 0.8,
      'pitch': 1.0,
    },
  };

  TTSState _currentState = TTSState.stopped;
  Duration _currentPosition = Duration.zero;
  final Duration _totalDuration = Duration.zero;
  String _currentText = '';
  String _currentLanguage = 'en';
  
  // Callbacks
  Function(Duration, Duration)? _onPositionChanged;
  Function(TTSState)? _onStateChanged;

  RegionalTTSService({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts() {
    _initTTS();
  }

  /// Initialize TTS engine
  Future<void> _initTTS() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.9);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setStartHandler(() {
        _currentState = TTSState.playing;
        _onStateChanged?.call(_currentState);
      });
      
      _flutterTts.setCompletionHandler(() {
        _currentState = TTSState.stopped;
        _currentPosition = Duration.zero;
        _onStateChanged?.call(_currentState);
      });
      
      _flutterTts.setErrorHandler((error) {
        debugPrint('TTS Error: $error');
        _currentState = TTSState.stopped;
        _onStateChanged?.call(_currentState);
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  /// Set voice for a specific language and region
  Future<void> setRegionalVoice(String languageCode, {String? region}) async {
    final config = _voiceConfigs[languageCode];
    if (config == null) {
      debugPrint('No voice config for language: $languageCode');
      return;
    }

    final voices = config['voices'] as List<String>;
    final defaultVoice = config['defaultVoice'] as String;
    final voice = region != null ? '$languageCode-$region' : defaultVoice;

    // Check if voice is available
    final availableVoices = await _flutterTts.getVoices;
    if (availableVoices.contains(voice)) {
      await _flutterTts.setVoice({'name': voice, 'locale': voice});
    } else {
      // Use default voice for language
      await _flutterTts.setLanguage(defaultVoice);
    }

    await _flutterTts.setSpeechRate(config['rate'] as double);
    await _flutterTts.setPitch(config['pitch'] as double);
    
    _currentLanguage = languageCode;
  }

  /// Speak text with regional accent
  Future<void> speak({
    required String text,
    required String languageCode,
    AudioQuality quality = AudioQuality.medium,
  }) async {
    if (text.isEmpty) return;

    _currentText = text;
    
    // Set voice for language
    await setRegionalVoice(languageCode);
    
    // Adjust quality settings
    switch (quality) {
      case AudioQuality.low:
        await _flutterTts.setSpeechRate(1.0);
        break;
      case AudioQuality.medium:
        await _flutterTts.setSpeechRate(0.9);
        break;
      case AudioQuality.high:
        await _flutterTts.setSpeechRate(0.7);
        break;
    }

    _currentState = TTSState.loading;
    _onStateChanged?.call(_currentState);

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _currentState = TTSState.stopped;
      _onStateChanged?.call(_currentState);
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
    _currentState = TTSState.stopped;
    _currentPosition = Duration.zero;
    _onStateChanged?.call(_currentState);
  }

  /// Pause speaking
  Future<void> pause() async {
    await _flutterTts.pause();
    _currentState = TTSState.paused;
    _onStateChanged?.call(_currentState);
  }

  /// Resume speaking
  Future<void> resume() async {
    await _flutterTts.speak(_currentText);
    _currentState = TTSState.playing;
    _onStateChanged?.call(_currentState);
  }

  /// Get available voices for a language
  Future<List<String>> getAvailableVoices(String languageCode) async {
    try {
      final voices = await _flutterTts.getVoices;
      return voices.where((v) => v.toLowerCase().contains(languageCode)).toList();
    } catch (e) {
      debugPrint('Error getting voices: $e');
      return [];
    }
  }

  /// Estimate duration of text
  Duration estimateDuration(String text, String languageCode) {
    // Average speaking rate: ~150 words per minute
    // Average word length: ~5 characters
    final wordCount = text.split(' ').length;
    final minutes = wordCount / 150;
    return Duration(seconds: (minutes * 60).round());
  }

  /// Pre-generate audio for offline use
  Future<List<Uint8List>> preGenerateAudio({
    required List<String> texts,
    required String languageCode,
    AudioQuality quality = AudioQuality.medium,
  }) async {
    final audioFiles = <Uint8List>[];
    
    await setRegionalVoice(languageCode);
    
    for (final text in texts) {
      try {
        await _flutterTts.speak(text);
        // FlutterTts.speak() does not return audio bytes on this platform
      } catch (e) {
        debugPrint('Pre-generation error: $e');
      }
    }
    
    return audioFiles;
  }

  /// Get TTS state
  TTSState get currentState => _currentState;

  /// Get current position
  Duration get currentPosition => _currentPosition;

  /// Get total duration
  Duration get totalDuration => _totalDuration;

  /// Get current text
  String get currentText => _currentText;

  /// Get current language
  String get currentLanguage => _currentLanguage;

  /// Set callbacks
  void setCallbacks({
    Function(Duration, Duration)? onPositionChanged,
    Function(TTSState)? onStateChanged,
  }) {
    _onPositionChanged = onPositionChanged;
    _onStateChanged = onStateChanged;
  }

  /// Check if TTS is available
  Future<bool> isAvailable() async {
    try {
      await _flutterTts.getLanguages;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Configure TTS for mantra recitation
  Future<void> configureForMantras(String languageCode) async {
    await setRegionalVoice(languageCode);
    await _flutterTts.setSpeechRate(0.5); // Slower for clarity
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
  }

  /// Configure TTS for storytelling
  Future<void> configureForStorytelling(String languageCode) async {
    await setRegionalVoice(languageCode);
    await _flutterTts.setSpeechRate(0.85);
    await _flutterTts.setPitch(1.0);
  }

  /// Dispose TTS
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}

/// Audio playback controller for storytelling
class AudioPlaybackController {
  final RegionalTTSService _ttsService;
  Timer? _positionTimer;
  
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  Function(Duration, Duration)? onPositionChanged;
  Function(TTSState)? onStateChanged;

  AudioPlaybackController({required RegionalTTSService ttsService})
    : _ttsService = ttsService {
    _ttsService.setCallbacks(
      onPositionChanged: (position, total) {
        _currentPosition = position;
        _totalDuration = total;
        onPositionChanged?.call(_currentPosition, _totalDuration);
      },
      onStateChanged: (state) {
        _startPositionTimer(state);
        onStateChanged?.call(state);
      },
    );
  }

  void _startPositionTimer(TTSState state) {
    _positionTimer?.cancel();
    
    if (state == TTSState.playing) {
      _positionTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          _currentPosition = Duration(seconds: _currentPosition.inSeconds + 1);
          onPositionChanged?.call(_currentPosition, _totalDuration);
        },
      );
    }
  }

  Future<void> play(String text, String language) async {
    _totalDuration = _ttsService.estimateDuration(text, language);
    _currentPosition = Duration.zero;
    await _ttsService.speak(text: text, languageCode: language);
  }

  Future<void> pause() async {
    await _ttsService.pause();
    _positionTimer?.cancel();
  }

  Future<void> resume() async {
    await _ttsService.resume();
  }

  Future<void> stop() async {
    await _ttsService.stop();
    _positionTimer?.cancel();
    _currentPosition = Duration.zero;
  }

  void seek(Duration position) {
    // TTS doesn't support seeking, so we need to restart
    _currentPosition = position;
  }

  Duration get position => _currentPosition;
  Duration get duration => _totalDuration;
  TTSState get state => _ttsService.currentState;

  void dispose() {
    _positionTimer?.cancel();
  }
}
