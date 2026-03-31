/// Content Preloader Service
/// Preloads storytelling content for offline access
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'offline_cache_service.dart';
import '../data/cultural_content_data.dart';
import '../models/cultural_content.dart';

/// Preload progress callback
typedef ProgressCallback = void Function(double progress);

/// Content Preloader Service
class ContentPreloader {
  final OfflineCacheService _cacheService;
  
  // Singleton
  static final ContentPreloader _instance = ContentPreloader._();
  factory ContentPreloader() => _instance;
  ContentPreloader._() : _cacheService = OfflineCacheService();

  /// Preload content for a list of temples
  Future<void> preloadForTemples({
    required List<String> templeIds,
    List<String> languages = const ['en', 'hi', 'ta', 'te'],
    List<String> contentTypes = const ['sthalaPuranam', 'ritual', 'mantra'],
    ProgressCallback? onProgress,
  }) async {
    int completed = 0;
    final total = templeIds.length * languages.length * contentTypes.length;
    
    for (final templeId in templeIds) {
      for (final language in languages) {
        for (final contentType in contentTypes) {
          try {
            await _preloadContent(
              templeId: templeId,
              language: language,
              contentType: contentType,
            );
          } catch (e) {
            // Continue with other content even if one fails
            if (kDebugMode) {
              print('Failed to preload $templeId ($language, $contentType): $e');
            }
          }
          
          completed++;
          onProgress?.call(completed / total);
        }
      }
    }
  }

  /// Preload content for a single temple
  Future<void> preloadForTemple({
    required String templeId,
    List<String>? languages,
    List<String>? contentTypes,
    ProgressCallback? onProgress,
  }) async {
    final langs = languages ?? ['en', 'hi', 'ta', 'te'];
    final types = contentTypes ?? ['sthalaPuranam', 'ritual', 'mantra'];
    
    int completed = 0;
    final total = langs.length * types.length;
    
    for (final language in langs) {
      for (final contentType in types) {
        try {
          await _preloadContent(
            templeId: templeId,
            language: language,
            contentType: contentType,
          );
        } catch (e) {
          if (kDebugMode) {
            print('Failed to preload $templeId ($language, $contentType): $e');
          }
        }
        
        completed++;
        onProgress?.call(completed / total);
      }
    }
  }

  /// Internal method to preload single content
  Future<void> _preloadContent({
    required String templeId,
    required String language,
    required String contentType,
  }) async {
    // Check if already cached
    final isCached = await _cacheService.isContentCached(
      templeId: templeId,
      contentType: contentType,
      language: language,
    );
    
    if (isCached) {
      return; // Already cached
    }
    
    // Get content from knowledge base
    final content = _getContentForTemple(templeId, contentType, language);
    
    if (content != null) {
      await _cacheService.cacheContent(
        templeId: templeId,
        contentType: contentType,
        language: language,
        content: content,
      );
    }
  }

  /// Get content from knowledge base
  String? _getContentForTemple(
    String templeId,
    String contentType,
    String language,
  ) {
    try {
      final type = ContentType.values.firstWhere(
        (e) => e.toString().split('.').last == contentType,
      );
      
      final contentList = getContentByType(templeId, type);
      if (contentList.isEmpty) return null;
      
      // Prefer content in requested language
      final inLanguage = contentList.firstWhere(
        (c) => c.language == language,
        orElse: () => contentList.first,
      );
      
      return inLanguage.content;
    } catch (e) {
      return null;
    }
  }

  /// Check preload status for a temple
  Future<Map<String, dynamic>> getPreloadStatus(String templeId) async {
    final entries = _cacheService.getCacheEntriesForTemple(templeId);
    final cachedLanguages = <String>{};
    final cachedTypes = <String>{};
    
    for (final entry in entries) {
      cachedLanguages.add(entry.language);
      cachedTypes.add(entry.contentType);
    }
    
    return {
      'templeId': templeId,
      'cachedLanguages': cachedLanguages.toList(),
      'cachedTypes': cachedTypes.toList(),
      'totalEntries': entries.length,
      'isFullyCached': cachedLanguages.length >= 4 && cachedTypes.length >= 3,
    };
  }

  /// Clear preload for a temple
  Future<void> clearTempleCache(String templeId) async {
    final entries = _cacheService.getCacheEntriesForTemple(templeId);
    
    for (final entry in entries) {
      try {
        await _cacheService.getCachedContent(
          templeId: templeId,
          contentType: entry.contentType,
          language: entry.language,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error clearing cache for $templeId: $e');
        }
      }
    }
  }

  /// Get overall cache status
  Future<Map<String, dynamic>> getOverallCacheStatus() async {
    final cacheSize = await _cacheService.getCacheSize();
    final entryCount = _cacheService.getCacheEntryCount();
    
    return {
      'totalSizeBytes': cacheSize,
      'totalSizeMB': (cacheSize / (1024 * 1024)).toStringAsFixed(2),
      'totalEntries': entryCount,
    };
  }

  /// Auto preload favorites
  Future<void> preloadFavorites(List<String> favoriteTempleIds) async {
    await preloadForTemples(
      templeIds: favoriteTempleIds,
      languages: ['en', 'hi'],
      contentTypes: ['sthalaPuranam', 'ritual'],
      onProgress: (progress) {
        if (kDebugMode) {
          print('Preloading favorites: ${(progress * 100).toStringAsFixed(0)}%');
        }
      },
    );
  }
}
