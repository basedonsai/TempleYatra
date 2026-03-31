/// Translation Service using Groq API
/// Provides multilingual translation for storytelling content
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'language_detection_service.dart';

/// Translation result
class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final bool isCached;

  TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.confidence,
    this.isCached = false,
  });
}

/// Translation cache entry
class TranslationCacheEntry {
  final String translatedText;
  final DateTime timestamp;

  TranslationCacheEntry({required this.translatedText, required this.timestamp});
}

/// Translation Service
class TranslationService {
  final String apiKey;
  final String baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // In-memory cache (could be replaced with SQLite for persistence)
  final Map<String, TranslationCacheEntry> _cache = {};
  final Duration _cacheValidity = const Duration(days: 7);

  TranslationService({required this.apiKey});

  /// Translate text from source language to target language
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    bool useCache = true,
  }) async {
    // Check cache first
    final cacheKey = _getCacheKey(text, sourceLanguage, targetLanguage);
    if (useCache) {
      final cached = _getFromCache(cacheKey);
      if (cached != null) {
        return TranslationResult(
          translatedText: cached.translatedText,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          confidence: 1.0,
          isCached: true,
        );
      }
    }

    // Skip translation if source and target are the same
    if (sourceLanguage == targetLanguage) {
      return TranslationResult(
        translatedText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        confidence: 1.0,
      );
    }

    try {
      final result = await _callGroqTranslation(text, sourceLanguage, targetLanguage);
      
      // Cache the result
      _addToCache(cacheKey, result.translatedText);
      
      return result;
    } catch (e) {
      debugPrint('Translation error: $e');
      // Return original text as fallback
      return TranslationResult(
        translatedText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        confidence: 0.0,
      );
    }
  }

  /// Translate content with cultural context preservation
  Future<TranslationResult> translateWithContext({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? culturalContext,
    bool useCache = true,
  }) async {
    final cacheKey = _getCacheKey('$text:$culturalContext', sourceLanguage, targetLanguage);
    
    if (useCache) {
      final cached = _getFromCache(cacheKey);
      if (cached != null) {
        return TranslationResult(
          translatedText: cached.translatedText,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          confidence: 1.0,
          isCached: true,
        );
      }
    }

    if (sourceLanguage == targetLanguage) {
      return TranslationResult(
        translatedText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        confidence: 1.0,
      );
    }

    try {
      final result = await _callGroqTranslationWithContext(
        text,
        sourceLanguage,
        targetLanguage,
        culturalContext,
      );
      
      _addToCache(cacheKey, result.translatedText);
      return result;
    } catch (e) {
      debugPrint('Context translation error: $e');
      return TranslationResult(
        translatedText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        confidence: 0.0,
      );
    }
  }

  /// Translate text to all supported languages
  Future<Map<String, String>> translateToAllLanguages({
    required String text,
    required String sourceLanguage,
    List<String>? targetLanguages,
  }) async {
    final results = <String, String>{};
    final targets = targetLanguages ?? _getDefaultTargetLanguages(sourceLanguage);

    await Future.forEach(targets, (String target) async {
      final result = await translate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: target,
      );
      results[target] = result.translatedText;
    });

    return results;
  }

  /// Call Groq API for translation
  Future<TranslationResult> _callGroqTranslation(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final sourceName = LanguageDetectionService().getDisplayName(sourceLanguage);
    final targetName = LanguageDetectionService().getDisplayName(targetLanguage);

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': '''You are a professional translator specializing in religious and cultural content. 
Translate the following text from $sourceName to $targetName.
 Preserve the meaning, tone, and cultural context accurately.
 For religious terms, maintain original Sanskrit/Hindi/Telugu/Tamil words where appropriate.
 Keep the translation natural and understandable.
 Return ONLY the translated text, nothing else.'''
          },
          {
            'role': 'user',
            'content': text
          }
        ],
        'temperature': 0.3,
        'max_tokens': 4000,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final translatedText = data['choices'][0]['message']['content'].toString().trim();

      return TranslationResult(
        translatedText: translatedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        confidence: 0.9,
      );
    } else {
      throw Exception('Translation API error: ${response.statusCode}');
    }
  }

  /// Call Groq API for context-aware translation
  Future<TranslationResult> _callGroqTranslationWithContext(
    String text,
    String sourceLanguage,
    String targetLanguage,
    String? culturalContext,
  ) async {
    final sourceName = LanguageDetectionService().getDisplayName(sourceLanguage);
    final targetName = LanguageDetectionService().getDisplayName(targetLanguage);
    
    final contextInfo = culturalContext != null 
        ? 'Cultural context: $culturalContext' 
        : '';

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': '''You are a translator specializing in Hindu religious and temple content.
Translate from $sourceName to $targetName preserving cultural and religious accuracy.
$contextInfo
Important: Keep Sanskrit slokas, mantras, and religious terms in original form.
Maintain devotional tone. Return ONLY the translated text.'''
          },
          {
            'role': 'user',
            'content': text
          }
        ],
        'temperature': 0.3,
        'max_tokens': 4000,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final translatedText = data['choices'][0]['message']['content'].toString().trim();

      return TranslationResult(
        translatedText: translatedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        confidence: 0.95,
      );
    } else {
      throw Exception('Context translation API error: ${response.statusCode}');
    }
  }

  /// Get cache key for translation
  String _getCacheKey(String text, String source, String target) {
    return '${source}_${target}_${text.hashCode}';
  }

  /// Get translation from cache
  TranslationCacheEntry? _getFromCache(String key) {
    final entry = _cache[key];
    if (entry != null) {
      final age = DateTime.now().difference(entry.timestamp);
      if (age < _cacheValidity) {
        return entry;
      }
      _cache.remove(key);
    }
    return null;
  }

  /// Add translation to cache
  void _addToCache(String key, String translatedText) {
    _cache[key] = TranslationCacheEntry(
      translatedText: translatedText,
      timestamp: DateTime.now(),
    );
  }

  /// Get default target languages based on source
  List<String> _getDefaultTargetLanguages(String source) {
    final allLanguages = SupportedLanguage.values
        .map((e) => e.code)
        .where((code) => code != source)
        .toList();
    
    // Prioritize major languages
    final priority = ['en', 'hi', 'ta', 'te'];
    final filtered = allLanguages
        .where((code) => !priority.contains(code))
        .toList();
    
    return [...priority.take(3), ...filtered.take(5)];
  }

  /// Clear translation cache
  void clearCache() {
    _cache.clear();
  }

  /// Get cache size
  int getCacheSize() {
    return _cache.length;
  }
}
