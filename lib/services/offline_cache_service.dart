/// Offline Content Cache Service
/// Provides caching for storytelling content for offline access
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cultural_content.dart';
import '../data/cultural_content_data.dart';

/// Cache entry metadata
class CacheEntry {
  final String key;
  final DateTime timestamp;
  final int sizeBytes;
  final String language;
  final String contentType;

  CacheEntry({
    required this.key,
    required this.timestamp,
    required this.sizeBytes,
    required this.language,
    required this.contentType,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(days: 7);
  }
}

/// Offline Cache Service
class OfflineCacheService {
  // Singleton
  static final OfflineCacheService _instance = OfflineCacheService._();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._();

  // Cache directory
  final String _cacheDir = 'storytelling_cache';
  
  // In-memory metadata cache
  final Map<String, CacheEntry> _metadataCache = {};
  
  // Maximum cache size (50 MB)
  final int _maxCacheSize = 50 * 1024 * 1024;

  /// Cache content for offline use
  Future<void> cacheContent({
    required String templeId,
    required String contentType,
    required String language,
    required String content,
  }) async {
    final key = _getKey(templeId, contentType, language);
    
    try {
      // Save content to file
      final file = await _getCacheFile(key);
      await file.writeAsString(content);
      
      // Update metadata
      final entry = CacheEntry(
        key: key,
        timestamp: DateTime.now(),
        sizeBytes: content.length,
        language: language,
        contentType: contentType,
      );
      _metadataCache[key] = entry;
      
      // Check cache size and clean if needed
      await _cleanupIfNeeded();
    } catch (e) {
      debugPrint('Cache write error: $e');
    }
  }

  /// Get cached content
  Future<String?> getCachedContent({
    required String templeId,
    required String contentType,
    required String language,
  }) async {
    final key = _getKey(templeId, contentType, language);
    
    try {
      final file = await _getCacheFile(key);
      if (await file.exists()) {
        final content = await file.readAsString();
        
        // Check if expired
        final entry = _metadataCache[key];
        if (entry != null && entry.isExpired) {
          await file.delete();
          _metadataCache.remove(key);
          return null;
        }
        
        return content;
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
    
    return null;
  }

  /// Check if content is cached
  Future<bool> isContentCached({
    required String templeId,
    required String contentType,
    required String language,
  }) async {
    final key = _getKey(templeId, contentType, language);
    final file = await _getCacheFile(key);
    
    if (await file.exists()) {
      final entry = _metadataCache[key];
      if (entry != null && !entry.isExpired) {
        return true;
      }
    }
    
    return false;
  }

  /// Preload content for multiple temples
  Future<void> preloadTempleContent({
    required List<String> templeIds,
    List<String> languages = const ['en', 'hi', 'ta', 'te'],
    List<String> contentTypes = const ['sthalaPuranam', 'ritual', 'mantra'],
    Function(double)? onProgress,
  }) async {
    int completed = 0;
    final total = templeIds.length * languages.length * contentTypes.length;
    
    for (final templeId in templeIds) {
      for (final language in languages) {
        for (final contentType in contentTypes) {
          // Get content from knowledge base
          final content = _getContentForCache(templeId, contentType, language);
          
          if (content != null) {
            await cacheContent(
              templeId: templeId,
              contentType: contentType,
              language: language,
              content: content,
            );
          }
          
          completed++;
          onProgress?.call(completed / total);
        }
      }
    }
  }

  /// Get content from knowledge base for caching
  String? _getContentForCache(
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

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    final expiredKeys = <String>[];
    
    for (final entry in _metadataCache.values) {
      if (entry.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      try {
        final file = await _getCacheFile(key);
        if (await file.exists()) {
          await file.delete();
        }
        _metadataCache.remove(key);
      } catch (e) {
        debugPrint('Error clearing expired cache: $e');
      }
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    for (final key in _metadataCache.keys) {
      try {
        final file = await _getCacheFile(key);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error clearing cache: $e');
      }
    }
    _metadataCache.clear();
  }

  /// Get cache size
  Future<int> getCacheSize() async {
    int totalSize = 0;
    
    for (final entry in _metadataCache.values) {
      totalSize += entry.sizeBytes;
    }
    
    return totalSize;
  }

  /// Get cache entry count
  int getCacheEntryCount() {
    return _metadataCache.length;
  }

  /// Get cache entries by temple
  List<CacheEntry> getCacheEntriesForTemple(String templeId) {
    final prefix = '${templeId}_';
    return _metadataCache.values
        .where((entry) => entry.key.startsWith(prefix))
        .toList();
  }

  /// Cleanup if cache size exceeded
  Future<void> _cleanupIfNeeded() async {
    var currentSize = await getCacheSize();
    
    if (currentSize > _maxCacheSize) {
      // Remove oldest entries first
      final entries = _metadataCache.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      for (final entry in entries) {
        if (currentSize <= _maxCacheSize * 0.8) break;
        
        try {
          final file = await _getCacheFile(entry.key);
          if (await file.exists()) {
            currentSize -= entry.sizeBytes;
            await file.delete();
          }
          _metadataCache.remove(entry.key);
        } catch (e) {
          debugPrint('Error during cleanup: $e');
        }
      }
    }
  }

  /// Generate cache key
  String _getKey(String templeId, String contentType, String language) {
    return '${templeId}_${contentType}_$language';
  }

  /// Get cache file
  Future<File> _getCacheFile(String key) async {
    // Use app's cache directory
    final cachePath = Directory.systemTemp.path;
    final dir = Directory('$cachePath/$_cacheDir');
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return File('${dir.path}/$key.txt');
  }
}
