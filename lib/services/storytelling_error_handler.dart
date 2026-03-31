/// Error Handling Service for Storytelling Feature
/// Provides comprehensive error handling and fallback mechanisms
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Error types for storytelling feature
enum StorytellingErrorType {
  networkError,
  apiError,
  contentNotFound,
  translationError,
  ttsError,
  languageNotSupported,
  offlineMode,
  validationError,
  unknownError,
}

/// Storytelling error with context
class StorytellingError {
  final StorytellingErrorType type;
  final String message;
  final String? technicalDetails;
  final DateTime timestamp;
  final bool isRecoverable;

  const StorytellingError({
    required this.type,
    required this.message,
    this.technicalDetails,
    required this.timestamp,
    this.isRecoverable = true,
  });

  /// User-friendly error message
  String get userMessage {
    switch (type) {
      case StorytellingErrorType.networkError:
        return 'Unable to connect. Please check your internet connection.';
      case StorytellingErrorType.apiError:
        return 'Service temporarily unavailable. Please try again later.';
      case StorytellingErrorType.contentNotFound:
        return 'Content not available for this temple.';
      case StorytellingErrorType.translationError:
        return 'Translation unavailable. Showing original content.';
      case StorytellingErrorType.ttsError:
        return 'Audio playback issue. Please try again.';
      case StorytellingErrorType.languageNotSupported:
        return 'Language not fully supported. Showing English version.';
      case StorytellingErrorType.offlineMode:
        return 'You are offline. Showing cached content.';
      case StorytellingErrorType.validationError:
        return 'Invalid request. Please try again.';
      case StorytellingErrorType.unknownError:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Get icon for error type
  IconData get errorIcon {
    switch (type) {
      case StorytellingErrorType.networkError:
        return Icons.wifi_off;
      case StorytellingErrorType.apiError:
        return Icons.cloud_off;
      case StorytellingErrorType.contentNotFound:
        return Icons.description;
      case StorytellingErrorType.translationError:
        return Icons.translate;
      case StorytellingErrorType.ttsError:
        return Icons.volume_off;
      case StorytellingErrorType.languageNotSupported:
        return Icons.language;
      case StorytellingErrorType.offlineMode:
        return Icons.offline_bolt;
      case StorytellingErrorType.validationError:
        return Icons.warning;
      case StorytellingErrorType.unknownError:
        return Icons.error;
    }
  }

  /// Create error from exception
  factory StorytellingError.fromException(Exception e) {
    final message = e.toString().toLowerCase();

    if (message.contains('network') || message.contains('socket') || message.contains('connection')) {
      return StorytellingError(
        type: StorytellingErrorType.networkError,
        message: 'Network error occurred',
        technicalDetails: e.toString(),
        timestamp: DateTime.now(),
      );
    }

    if (message.contains('api') || message.contains('401') || message.contains('403') || message.contains('429')) {
      return StorytellingError(
        type: StorytellingErrorType.apiError,
        message: 'API error occurred',
        technicalDetails: e.toString(),
        timestamp: DateTime.now(),
      );
    }

    if (message.contains('404') || message.contains('not found')) {
      return StorytellingError(
        type: StorytellingErrorType.contentNotFound,
        message: 'Content not found',
        technicalDetails: e.toString(),
        timestamp: DateTime.now(),
        isRecoverable: false,
      );
    }

    return StorytellingError(
      type: StorytellingErrorType.unknownError,
      message: 'Unknown error occurred',
      technicalDetails: e.toString(),
      timestamp: DateTime.now(),
    );
  }
}

/// Fallback content for errors
class ContentFallback {
  final String title;
  final String content;
  final String language;
  final bool isOffline;
  final bool isPartial;

  const ContentFallback({
    required this.title,
    required this.content,
    required this.language,
    this.isOffline = false,
    this.isPartial = false,
  });

  /// Create fallback from available content
  factory ContentFallback.fromPartial(String partialContent, String language) {
    return ContentFallback(
      title: 'Content Unavailable',
      content: partialContent,
      language: language,
      isPartial: true,
    );
  }

  /// Create offline fallback
  factory ContentFallback.offline(String templeId) {
    return ContentFallback(
      title: 'Offline Mode',
      content: 'You are viewing cached content. Connect to internet for latest information.',
      language: 'en',
      isOffline: true,
    );
  }
}

/// Error handler for storytelling feature
class StorytellingErrorHandler {
  /// Handle RAG service errors
  static ContentFallback handleRAGError(
    StorytellingError error, {
    required String templeId,
    required String languageCode,
  }) {
    if (error.type == StorytellingErrorType.offlineMode) {
      return ContentFallback.offline(templeId);
    }

    return ContentFallback.fromPartial(
      'Unable to load full content. Showing available information.',
      languageCode,
    );
  }

  /// Handle TTS errors
  static String handleTTSError(String error, String text) {
    return text;
  }

  /// Handle translation errors
  static String handleTranslationError(String originalText, String targetLanguage) {
    return originalText;
  }

  /// Build error widget for display
  static Widget buildErrorWidget({
    required StorytellingError error,
    required VoidCallback onRetry,
    VoidCallback? onFallback,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error.errorIcon,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (error.isRecoverable)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (onFallback != null) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: onFallback,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Continue'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build offline indicator widget
  static Widget buildOfflineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.offline_bolt, size: 16, color: Colors.orange),
          SizedBox(width: 8),
          Text(
            'Offline Mode',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build loading placeholder
  static Widget buildLoadingPlaceholder(String contentType) {
    return Column(
      children: [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(
          'Loading $contentType...',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Get retry strategy based on error type
  static int getRetryDelay(StorytellingError error) {
    switch (error.type) {
      case StorytellingErrorType.networkError:
        return 5000;
      case StorytellingErrorType.apiError:
        return 10000;
      case StorytellingErrorType.ttsError:
        return 2000;
      default:
        return 3000;
    }
  }

  /// Check if error requires user notification
  static bool shouldNotifyUser(StorytellingError error) {
    return error.type != StorytellingErrorType.offlineMode;
  }
}

/// Logger for storytelling errors (debug only)
void logStorytellingError(StorytellingError error) {
  assert(() {
    if (kDebugMode) {
      print('=== Storytelling Error ===');
      print('Type: ${error.type}');
      print('Message: ${error.message}');
      print('Technical: ${error.technicalDetails}');
      print('Recoverable: ${error.isRecoverable}');
      print('===========================');
    }
    return true;
  }());
}

/// Utility to wrap async operations with error handling
Future<T> withErrorHandling<T>(
  Future<T> Function() operation, {
  required T Function(StorytellingError error) onError,
}) async {
  try {
    return await operation();
  } catch (e) {
    final error = StorytellingError.fromException(e as Exception);
    return onError(error);
  }
}
