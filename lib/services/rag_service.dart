/// RAG Service using Groq API
/// Retrieval-Augmented Generation for culturally authentic storytelling
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cultural_content.dart';
import '../data/cultural_content_data.dart';
import 'language_detection_service.dart';
import 'storytelling_error_handler.dart';

/// RAG Configuration
class RAGConfig {
  final int topK;
  final double similarityThreshold;
  final int maxContextLength;
  final String model;

  const RAGConfig({
    this.topK = 5,
    this.similarityThreshold = 0.3,
    this.maxContextLength = 4000,
    this.model = 'llama-3.3-70b-versatile',
  });
}

/// Content chunk for retrieval
class ContentChunk {
  final String id;
  final String content;
  final String templeId;
  final String contentType;
  final String language;
  final double relevanceScore;

  ContentChunk({
    required this.id,
    required this.content,
    required this.templeId,
    required this.contentType,
    required this.language,
    this.relevanceScore = 0.0,
  });
}

/// RAG Service for retrieval-augmented generation
class RAGService {
  final String _apiKey;
  final RAGConfig _config;
  final LanguageDetectionService _languageDetection;
  final StorytellingErrorHandler _errorHandler;
  final List<ContentChunk> _knowledgeBase;

  // Groq API endpoint
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  RAGService({
    required String apiKey,
    RAGConfig? config,
    LanguageDetectionService? languageDetection,
    StorytellingErrorHandler? errorHandler,
  })  : _apiKey = apiKey,
        _config = config ?? const RAGConfig(),
        _languageDetection = languageDetection ?? LanguageDetectionService(),
        _errorHandler = errorHandler ?? StorytellingErrorHandler(),
        _knowledgeBase = _buildKnowledgeBase();

  /// Build knowledge base from cultural content data
  static List<ContentChunk> _buildKnowledgeBase() {
    final chunks = <ContentChunk>[];

    // Process content for each temple
    final temples = ['chilkur-balaji', 'jagannath-puri', 'srisailam'];

    for (final templeId in temples) {
      for (final type in ContentType.values) {
        final contentList = getContentByType(templeId, type);
        for (final content in contentList) {
          final chunk = ContentChunk(
            id: '${templeId}_${type}_${content.language}',
            content: content.content,
            templeId: templeId,
            contentType: type.toString().split('.').last,
            language: content.language,
            relevanceScore: 1.0,
          );
          chunks.add(chunk);
        }
      }
    }

    return chunks;
  }

  /// Generate response using RAG
  Future<String> generateResponse({
    required String query,
    required String templeId,
    String? userLanguage,
  }) async {
    try {
      // Detect language if not provided
      final language = userLanguage ?? 
          _languageDetection.detectLanguage(query).language.code;

      // Retrieve relevant content
      final relevantChunks = await retrieveRelevantContent(
        query: query,
        templeId: templeId,
        language: language,
      );

      // Generate response using Groq API
      final response = await _callGroqAPI(
        query: query,
        context: relevantChunks,
        language: language,
      );

      return response;
    } catch (e) {
      final error = StorytellingError.fromException(e as Exception);
      return StorytellingErrorHandler.handleRAGError(
        error,
        templeId: templeId,
        languageCode: userLanguage ?? 'en',
      ).content;
    }
  }

  /// Retrieve relevant content chunks
  Future<List<String>> retrieveRelevantContent({
    required String query,
    required String templeId,
    required String language,
  }) async {
    final queryLower = query.toLowerCase();
    final keywords = _extractKeywords(queryLower);

    // Filter and score chunks
    final scoredChunks = _knowledgeBase
        .where((chunk) => 
            chunk.templeId == templeId || 
            chunk.templeId.isEmpty)
        .map((chunk) {
      double score = 0.0;

      // Language match
      if (chunk.language == language) {
        score += 0.3;
      }

      // Keyword relevance
      for (final keyword in keywords) {
        if (chunk.content.toLowerCase().contains(keyword)) {
          score += 0.2;
        }
      }

      // Content type relevance based on query
      if (queryLower.contains('history') || 
          queryLower.contains('story') ||
          queryLower.contains('origin')) {
        if (chunk.contentType == 'sthalaPuranam') {
          score += 0.3;
        }
      }

      if (queryLower.contains('ritual') || 
          queryLower.contains('worship') ||
          queryLower.contains('puja')) {
        if (chunk.contentType == 'ritual') {
          score += 0.3;
        }
      }

      if (queryLower.contains('mantra') || 
          queryLower.contains('prayer') ||
          queryLower.contains('chant')) {
        if (chunk.contentType == 'mantra') {
          score += 0.3;
        }
      }

      return chunk.copyWith(relevanceScore: score);
    })
    .where((chunk) => chunk.relevanceScore >= _config.similarityThreshold)
    .toList()
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    // Return top K chunks
    return scoredChunks
        .take(_config.topK)
        .map((chunk) => chunk.content)
        .toList();
  }

  /// Extract keywords from query
  List<String> _extractKeywords(String query) {
    // Common stop words to filter out
    final stopWords = {
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
      'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
      'would', 'could', 'should', 'may', 'might', 'must', 'shall',
      'can', 'need', 'dare', 'ought', 'used', 'to', 'of', 'in',
      'for', 'on', 'with', 'at', 'by', 'from', 'as', 'into',
      'through', 'during', 'before', 'after', 'above', 'below',
      'between', 'under', 'again', 'further', 'then', 'once',
      'what', 'which', 'who', 'whom', 'this', 'that', 'these',
      'those', 'it', 'its', 'and', 'but', 'or', 'nor', 'so',
      'yet', 'both', 'either', 'neither', 'not', 'only', 'same',
      'temple', 'tell', 'me', 'about', 'give', 'explain', 'describe'
    };

    // Extract words and filter
    return query
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => 
            word.length > 2 && 
            !stopWords.contains(word.toLowerCase()))
        .toList();
  }

  /// Call Groq API for response generation
  Future<String> _callGroqAPI({
    required String query,
    required List<String> context,
    required String language,
  }) async {
    // Prepare context
    final contextText = context.join('\n\n');

    // Build system prompt based on language
    final systemPrompt = _buildSystemPrompt(language);

    // Build user prompt
    final userPrompt = '''
Query: $query

Context Information:
$contextText

Please provide a culturally accurate and informative response about the temple based on the context above.
''';

    // Build request body
    final requestBody = jsonEncode({
      'model': _config.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.7,
      'max_tokens': 1024,
    });

    // Make API call
    final response = await http.post(
      Uri.parse(_groqApiUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    // Handle response
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Build system prompt based on language
  String _buildSystemPrompt(String language) {
    final prompts = {
      'en': '''You are a knowledgeable temple guide providing culturally accurate information about Hindu temples. 
Share authentic sthala puranam (temple history), rituals, mantras, and spiritual significance.
Always maintain respect and authenticity in your responses.''',
      'hi': '''आप हिंदू मंदिरों के बारे में सांस्कृतिक रूप से सटीक जानकारी प्रदान करने वाले ज्ञान मंदिर गाइड हैं। 
प्रामाणिक स्थल पुराण (मंदिर का इतिहास), अनुष्ठान, मंत्र और आध्यात्मिक महत्व साझा करें।
अपने उत्तरों में सम्मान और प्रामाणिकता बनाए रखें।''',
      'ta': '''நீங்கள் இந்து கோவில்கள் பற்றிய கலாச்சார ரீதியாக துல்லியமான தகவல்களை வழங்கும் அறிவு கோவில் வழிகாட்டியாக இருக்கிறீர்கள். 
உண்மையான ஸ்தல புராணம் (கோவில் வரலாறு), சடங்குகள், மந்திரங்கள் மற்றும் ஆன்மீக முக்கியத்துவத்தைப் பகிரவும்.''',
      'te': '''మీరు హిందూ ఆలయాల గురించి సాంస్కృతికంగా ఖచ్చితమైన సమాచారాన్ని అందించే జ్ఞానం కలిగిన ఆలయ గైడ్‌గా ఉన్నారు. 
అసలైన స్థల పురాణం (ఆలయ చరిత్ర), ఆచారాలు, మంత్రాలు, ఆధ్యాత్మిక ప్రాముఖ్యతను పంచుకోండి.''',
    };

    return prompts[language] ?? prompts['en']!;
  }

  /// Add custom content to knowledge base
  void addToKnowledgeBase({
    required String templeId,
    required String content,
    required String contentType,
    required String language,
  }) {
    final chunk = ContentChunk(
      id: '${templeId}_${contentType}_$language',
      content: content,
      templeId: templeId,
      contentType: contentType,
      language: language,
      relevanceScore: 1.0,
    );
    _knowledgeBase.add(chunk);
  }

  /// Clear knowledge base
  void clearKnowledgeBase() {
    _knowledgeBase.clear();
  }

  /// Get knowledge base stats
  Map<String, dynamic> getKnowledgeBaseStats() {
    final templeCounts = <String, int>{};
    final languageCounts = <String, int>{};
    final typeCounts = <String, int>{};

    for (final chunk in _knowledgeBase) {
      templeCounts[chunk.templeId] = (templeCounts[chunk.templeId] ?? 0) + 1;
      languageCounts[chunk.language] = (languageCounts[chunk.language] ?? 0) + 1;
      typeCounts[chunk.contentType] = (typeCounts[chunk.contentType] ?? 0) + 1;
    }

    return {
      'totalChunks': _knowledgeBase.length,
      'templeBreakdown': templeCounts,
      'languageBreakdown': languageCounts,
      'typeBreakdown': typeCounts,
    };
  }
}

extension on ContentChunk {
  ContentChunk copyWith({double? relevanceScore}) {
    return ContentChunk(
      id: id,
      content: content,
      templeId: templeId,
      contentType: contentType,
      language: language,
      relevanceScore: relevanceScore ?? this.relevanceScore,
    );
  }
}
