/// Cultural content model for storytelling feature
/// Stores sthala puranam, rituals, mantras, and other cultural information
library;

class CulturalContent {
  final String id;
  final String templeId;
  final ContentType type;
  final String title;
  final String content;
  final String language;
  final String? audioUrl;
  final String source;
  final DateTime? validatedDate;
  final String? validatorName;
  final List<String>? tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  CulturalContent({
    required this.id,
    required this.templeId,
    required this.type,
    required this.title,
    required this.content,
    required this.language,
    this.audioUrl,
    required this.source,
    this.validatedDate,
    this.validatorName,
    this.tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Get content for a specific language
  /// If the requested language doesn't exist, returns the default content
  String getContent(String requestedLanguage) {
    // For now, return the default content
    // In a real app, this would check for translations
    return content;
  }

  /// Get content type display name
  String get typeDisplayName {
    switch (type) {
      case ContentType.sthalaPuranam:
        return 'Sthala Puranam';
      case ContentType.ritual:
        return 'Ritual';
      case ContentType.mantra:
        return 'Mantra';
      case ContentType.significance:
        return 'Significance';
      case ContentType.history:
        return 'History';
      case ContentType.architecture:
        return 'Architecture';
      case ContentType.festival:
        return 'Festival';
      case ContentType.deity:
        return 'Deity Information';
    }
  }

  /// Get content type display title for UI
  String get typeDisplayTitle {
    switch (type) {
      case ContentType.sthalaPuranam:
        return 'Temple Legend';
      case ContentType.ritual:
        return 'Daily Rituals';
      case ContentType.mantra:
        return 'Sacred Mantras';
      case ContentType.significance:
        return 'Religious Significance';
      case ContentType.history:
        return 'Temple History';
      case ContentType.architecture:
        return 'Architecture';
      case ContentType.festival:
        return 'Festival Information';
      case ContentType.deity:
        return 'About the Deity';
    }
  }

  /// Get icon for content type
  String get typeIcon {
    switch (type) {
      case ContentType.sthalaPuranam:
        return '📖';
      case ContentType.ritual:
        return '🕉️';
      case ContentType.mantra:
        return '🔱';
      case ContentType.significance:
        return '✨';
      case ContentType.history:
        return '🏛️';
      case ContentType.architecture:
        return '🏛️';
      case ContentType.festival:
        return '🎉';
      case ContentType.deity:
        return '🪔';
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templeId': templeId,
      'type': type.toString().split('.').last,
      'title': title,
      'content': content,
      'language': language,
      'audioUrl': audioUrl,
      'source': source,
      'validatedDate': validatedDate?.toIso8601String(),
      'validatorName': validatorName,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create CulturalContent from JSON
  factory CulturalContent.fromJson(Map<String, dynamic> json) {
    return CulturalContent(
      id: json['id'] ?? '',
      templeId: json['templeId'] ?? '',
      type: ContentType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ContentType.sthalaPuranam,
      ),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      language: json['language'] ?? 'en',
      audioUrl: json['audioUrl'],
      source: json['source'] ?? '',
      validatedDate: json['validatedDate'] != null
          ? DateTime.parse(json['validatedDate'])
          : null,
      validatorName: json['validatorName'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  /// Create a copy with updated content
  CulturalContent copyWith({
    String? title,
    String? content,
    String? audioUrl,
    String? source,
    List<String>? tags,
    DateTime? validatedDate,
    String? validatorName,
  }) {
    return CulturalContent(
      id: id,
      templeId: templeId,
      type: type,
      title: title ?? this.title,
      content: content ?? this.content,
      language: language,
      audioUrl: audioUrl ?? this.audioUrl,
      source: source ?? this.source,
      validatedDate: validatedDate ?? this.validatedDate,
      validatorName: validatorName ?? this.validatorName,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Types of cultural content
enum ContentType {
  sthalaPuranam,  // Temple legend
  ritual,         // Daily rituals
  mantra,         // Sacred mantras
  significance,   // Religious significance
  history,        // Historical information
  architecture,   // Architectural details
  festival,       // Festival information
  deity,          // Deity information
}

/// Supported languages for content
class SupportedLanguage {
  final String code;
  final String displayName;
  final String nativeName;
  final String? script;
  final bool isRTL;
  final List<String>? regions;

  const SupportedLanguage({
    required this.code,
    required this.displayName,
    required this.nativeName,
    this.script,
    this.isRTL = false,
    this.regions,
  });

  static const List<SupportedLanguage> all = [
    SupportedLanguage(
      code: 'en',
      displayName: 'English',
      nativeName: 'English',
      regions: ['India', 'Global'],
    ),
    SupportedLanguage(
      code: 'hi',
      displayName: 'Hindi',
      nativeName: 'हिन्दी',
      script: 'Devanagari',
      regions: ['North India', 'National'],
    ),
    SupportedLanguage(
      code: 'ta',
      displayName: 'Tamil',
      nativeName: 'தமிழ்',
      script: 'Tamil',
      regions: ['Tamil Nadu', 'Sri Lanka'],
    ),
    SupportedLanguage(
      code: 'te',
      displayName: 'Telugu',
      nativeName: 'తెలుగు',
      script: 'Telugu',
      regions: ['Telangana', 'Andhra Pradesh'],
    ),
    SupportedLanguage(
      code: 'kn',
      displayName: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      script: 'Kannada',
      regions: ['Karnataka'],
    ),
    SupportedLanguage(
      code: 'ml',
      displayName: 'Malayalam',
      nativeName: 'മലയാളം',
      script: 'Malayalam',
      regions: ['Kerala', 'Lakshadweep'],
    ),
    SupportedLanguage(
      code: 'bn',
      displayName: 'Bengali',
      nativeName: 'বাংলা',
      script: 'Bengali',
      regions: ['West Bengal', 'Bangladesh'],
    ),
    SupportedLanguage(
      code: 'mr',
      displayName: 'Marathi',
      nativeName: 'मराठी',
      script: 'Devanagari',
      regions: ['Maharashtra'],
    ),
    SupportedLanguage(
      code: 'gu',
      displayName: 'Gujarati',
      nativeName: 'ગુજરાતી',
      script: 'Gujarati',
      regions: ['Gujarat'],
    ),
  ];

  /// Get language by code
  static SupportedLanguage? getByCode(String code) {
    try {
      return all.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Check if language is supported
  static bool isSupported(String code) {
    return all.any((lang) => lang.code == code);
  }

  /// Get display name for code
  static String getDisplayName(String code) {
    return getByCode(code)?.displayName ?? code;
  }
}
