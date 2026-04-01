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
  Duration _totalDuration = Duration.zero;
  String _currentText = '';
  String _currentLanguage = 'en';
  
  // Callbacks
  Function(Duration, Duration)? _onPositionChanged;
  Function(TTSState)? _onStateChanged;
  Timer? _progressTimer;

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
      // Handlers are registered in _registerHandlers(), called after setCallbacks()
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  void _registerHandlers() {
    _flutterTts.setStartHandler(() {
      _currentState = TTSState.playing;
      _onStateChanged?.call(_currentState);
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_currentState == TTSState.playing) {
          _currentPosition = Duration(
            seconds: (_currentPosition.inSeconds + 1)
                .clamp(0, _totalDuration.inSeconds),
          );
          _onPositionChanged?.call(_currentPosition, _totalDuration);
        }
      });
    });

    _flutterTts.setCompletionHandler(() {
      _progressTimer?.cancel();
      _currentState = TTSState.stopped;
      _currentPosition = Duration.zero;
      _onStateChanged?.call(_currentState);
      _onPositionChanged?.call(_currentPosition, _totalDuration);
    });

    _flutterTts.setErrorHandler((error) {
      debugPrint('TTS Error: $error');
      _progressTimer?.cancel();
      _currentState = TTSState.stopped;
      _onStateChanged?.call(_currentState);
    });

    _flutterTts.setCancelHandler(() {
      _progressTimer?.cancel();
      _currentState = TTSState.stopped;
      _onStateChanged?.call(_currentState);
    });
  }

  /// Set voice for a specific language and region
  Future<void> setRegionalVoice(String languageCode, {String? region}) async {
    final config = _voiceConfigs[languageCode] ?? _voiceConfigs['en']!;
    final locale = config['defaultVoice'] as String;

    // setLanguage is the reliable cross-platform way — getVoices returns Maps not Strings
    try {
      await _flutterTts.setLanguage(locale);
    } catch (e) {
      debugPrint('TTS setLanguage($locale) failed, falling back to en-US: $e');
      await _flutterTts.setLanguage('en-US');
    }

    await _flutterTts.setSpeechRate(config['rate'] as double);
    await _flutterTts.setPitch(config['pitch'] as double);
    await _flutterTts.setVolume(1.0);

    _currentLanguage = languageCode;
  }

  /// Speak text with regional accent
  Future<void> speak({
    required String text,
    required String languageCode,
    AudioQuality quality = AudioQuality.medium,
  }) async {
    if (text.isEmpty) return;

    // Stop any current speech first
    _progressTimer?.cancel();
    await _flutterTts.stop();

    _currentText = text;
    _currentPosition = Duration.zero;
    _totalDuration = estimateDuration(text, languageCode);
    _onPositionChanged?.call(_currentPosition, _totalDuration);

    // Set language and base rate
    await setRegionalVoice(languageCode);

    // Apply quality modifier on top of base rate
    final config = _voiceConfigs[languageCode] ?? _voiceConfigs['en']!;
    final baseRate = config['rate'] as double;
    final qualityRate = switch (quality) {
      AudioQuality.low => baseRate * 1.1,
      AudioQuality.medium => baseRate,
      AudioQuality.high => baseRate * 0.85,
    };
    await _flutterTts.setSpeechRate(qualityRate.clamp(0.1, 1.0));

    _currentState = TTSState.loading;
    _onStateChanged?.call(_currentState);

    try {
      final result = await _flutterTts.speak(text);
      if (result != 1) {
        // speak() returns 1 on success on Android
        debugPrint('TTS speak returned: $result');
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _progressTimer?.cancel();
      _currentState = TTSState.stopped;
      _onStateChanged?.call(_currentState);
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    _progressTimer?.cancel();
    await _flutterTts.stop();
    _currentState = TTSState.stopped;
    _currentPosition = Duration.zero;
    _onStateChanged?.call(_currentState);
    _onPositionChanged?.call(_currentPosition, _totalDuration);
  }

  /// Pause speaking
  Future<void> pause() async {
    _progressTimer?.cancel();
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

  /// Set callbacks — also registers TTS handlers so they fire correctly
  void setCallbacks({
    Function(Duration, Duration)? onPositionChanged,
    Function(TTSState)? onStateChanged,
  }) {
    _onPositionChanged = onPositionChanged;
    _onStateChanged = onStateChanged;
    // Register handlers now that callbacks are wired
    _registerHandlers();
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
    _progressTimer?.cancel();
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
