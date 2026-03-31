/// Language Detection Service
/// Detects and manages supported languages for multilingual storytelling
library;

/// Supported languages for the app
enum SupportedLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'Hindi', 'हिंदी'),
  tamil('ta', 'Tamil', 'தமிழ்'),
  telugu('te', 'Telugu', 'తెలుగు'),
  kannada('kn', 'Kannada', 'ಕನ್ನಡ'),
  malayalam('ml', 'Malayalam', 'മലയാളം'),
  bengali('bn', 'Bengali', 'বাংলা'),
  marathi('mr', 'Marathi', 'मराठी'),
  gujarati('gu', 'Gujarati', 'ગુજરાતી'),
  punjabi('pa', 'Punjabi', 'ਪੰਜਾਬੀ');

  final String code;
  final String displayName;
  final String nativeName;

  const SupportedLanguage(this.code, this.displayName, this.nativeName);

  static SupportedLanguage? fromCode(String code) {
    try {
      return values.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  static List<SupportedLanguage> get all => values;
}

/// Language detection result
class LanguageDetectionResult {
  final SupportedLanguage language;
  final double confidence;
  final bool isReliable;

  LanguageDetectionResult({
    required this.language,
    required this.confidence,
  }) : isReliable = confidence > 0.7;
}

/// Character ranges for language detection
class LanguageCharRanges {
  // Devanagari script (Hindi, Marathi)
  static final devanagari = RegExp(r'[\u0900-\u097F]');
  
  // Tamil script
  static final tamil = RegExp(r'[\u0B80-\u0BFF]');
  
  // Telugu script
  static final telugu = RegExp(r'[\u0C00-\u0C7F]');
  
  // Kannada script
  static final kannada = RegExp(r'[\u0C80-\u0CFF]');
  
  // Malayalam script
  static final malayalam = RegExp(r'[\u0D00-\u0D7F]');
  
  // Bengali script
  static final bengali = RegExp(r'[\u0980-\u09FF]');
  
  // Gujarati script
  static final gujarati = RegExp(r'[\u0A80-\u0AFF]');
  
  // Gurmukhi script (Punjabi)
  static final gurmukhi = RegExp(r'[\u0A00-\u0A7F]');

  // Latin script (English and others)
  static final latin = RegExp(r'[a-zA-Z]');
}

/// Language Detection Service
class LanguageDetectionService {
  /// Detect language from text
  LanguageDetectionResult detectLanguage(String text) {
    if (text.isEmpty) {
      return LanguageDetectionResult(
        language: SupportedLanguage.english,
        confidence: 0.0,
      );
    }

    // Count characters in each script
    final scriptCounts = <SupportedLanguage, int>{};
    
    if (LanguageCharRanges.devanagari.hasMatch(text)) {
      scriptCounts[SupportedLanguage.hindi] = _countMatches(text, LanguageCharRanges.devanagari);
    }
    if (LanguageCharRanges.tamil.hasMatch(text)) {
      scriptCounts[SupportedLanguage.tamil] = _countMatches(text, LanguageCharRanges.tamil);
    }
    if (LanguageCharRanges.telugu.hasMatch(text)) {
      scriptCounts[SupportedLanguage.telugu] = _countMatches(text, LanguageCharRanges.telugu);
    }
    if (LanguageCharRanges.kannada.hasMatch(text)) {
      scriptCounts[SupportedLanguage.kannada] = _countMatches(text, LanguageCharRanges.kannada);
    }
    if (LanguageCharRanges.malayalam.hasMatch(text)) {
      scriptCounts[SupportedLanguage.malayalam] = _countMatches(text, LanguageCharRanges.malayalam);
    }
    if (LanguageCharRanges.bengali.hasMatch(text)) {
      scriptCounts[SupportedLanguage.bengali] = _countMatches(text, LanguageCharRanges.bengali);
    }
    if (LanguageCharRanges.gujarati.hasMatch(text)) {
      scriptCounts[SupportedLanguage.gujarati] = _countMatches(text, LanguageCharRanges.gujarati);
    }
    if (LanguageCharRanges.gurmukhi.hasMatch(text)) {
      scriptCounts[SupportedLanguage.punjabi] = _countMatches(text, LanguageCharRanges.gurmukhi);
    }

    // Check for Latin text
    final latinCount = _countMatches(text, LanguageCharRanges.latin);
    if (latinCount > 0 && scriptCounts.isEmpty) {
      return LanguageDetectionResult(
        language: SupportedLanguage.english,
        confidence: 0.95,
      );
    }

    // If no script detected, default to English
    if (scriptCounts.isEmpty) {
      return LanguageDetectionResult(
        language: SupportedLanguage.english,
        confidence: 0.5,
      );
    }

    // Find the script with most characters
    final detectedLanguage = scriptCounts.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    // Calculate confidence based on proportion
    final totalScriptChars = scriptCounts.values.fold(0, (a, b) => a + b);
    final confidence = detectedLanguage.value / totalScriptChars;

    return LanguageDetectionResult(
      language: detectedLanguage.key,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  int _countMatches(String text, RegExp pattern) {
    return pattern.allMatches(text).length;
  }

  /// Check if a language is supported
  bool isLanguageSupported(String languageCode) {
    return SupportedLanguage.values.any((lang) => lang.code == languageCode);
  }

  /// Get language by code
  SupportedLanguage? getLanguageByCode(String code) {
    return SupportedLanguage.fromCode(code);
  }

  /// Get display name for language code
  String getDisplayName(String code) {
    return SupportedLanguage.fromCode(code)?.displayName ?? code;
  }

  /// Get native name for language code
  String getNativeName(String code) {
    return SupportedLanguage.fromCode(code)?.nativeName ?? code;
  }

  /// Get all supported languages
  List<SupportedLanguage> getSupportedLanguages() {
    return SupportedLanguage.all;
  }

  /// Detect if text is likely a specific language
  bool isLikelyLanguage(String text, SupportedLanguage language) {
    final result = detectLanguage(text);
    return result.language == language && result.isReliable;
  }

  /// Get the primary language from user preferences or device locale
  SupportedLanguage getDefaultLanguage() {
    // Could be extended to check device locale
    return SupportedLanguage.english;
  }

  /// Get language direction (RTL or LTR)
  bool isRTL(SupportedLanguage language) {
    // RTL languages list (none of our supported Indian languages are RTL)
    // Arabic, Hebrew, Persian, Urdu would be RTL
    return false;
  }

  /// Suggest language based on temple location
  SupportedLanguage suggestLanguageForRegion(String region) {
    final regionLower = region.toLowerCase();
    
    if (regionLower.contains('tamil nadu') || regionLower.contains('tamil')) {
      return SupportedLanguage.tamil;
    }
    if (regionLower.contains('telangana') || regionLower.contains('andhra')) {
      return SupportedLanguage.telugu;
    }
    if (regionLower.contains('karnataka')) {
      return SupportedLanguage.kannada;
    }
    if (regionLower.contains('kerala')) {
      return SupportedLanguage.malayalam;
    }
    if (regionLower.contains('west bengal') || regionLower.contains('bengal')) {
      return SupportedLanguage.bengali;
    }
    if (regionLower.contains('maharashtra')) {
      return SupportedLanguage.marathi;
    }
    if (regionLower.contains('gujarat')) {
      return SupportedLanguage.gujarati;
    }
    if (regionLower.contains('punjab')) {
      return SupportedLanguage.punjabi;
    }
    if (regionLower.contains('north') || regionLower.contains('delhi')) {
      return SupportedLanguage.hindi;
    }
    
    return SupportedLanguage.english;
  }

  /// Get language for TTS voice selection
  String getTTSLanguageCode(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.english:
        return 'en-US';
      case SupportedLanguage.hindi:
        return 'hi-IN';
      case SupportedLanguage.tamil:
        return 'ta-IN';
      case SupportedLanguage.telugu:
        return 'te-IN';
      case SupportedLanguage.kannada:
        return 'kn-IN';
      case SupportedLanguage.malayalam:
        return 'ml-IN';
      case SupportedLanguage.bengali:
        return 'bn-IN';
      case SupportedLanguage.marathi:
        return 'mr-IN';
      case SupportedLanguage.gujarati:
        return 'gu-IN';
      case SupportedLanguage.punjabi:
        return 'pa-IN';
    }
  }
}

/// Extension for easy language access
extension LanguageExtensions on String {
  SupportedLanguage? toSupportedLanguage() {
    return LanguageDetectionService().getLanguageByCode(this);
  }
}
