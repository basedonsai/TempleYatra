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

    // Use ALL content from the knowledge base — no hardcoded temple list
    for (final content in allCulturalContent) {
      chunks.add(ContentChunk(
        id: '${content.templeId}_${content.type.toString().split('.').last}_${content.language}',
        content: content.content,
        templeId: content.templeId,
        contentType: content.type.toString().split('.').last,
        language: content.language,
        relevanceScore: 1.0,
      ));
    }

    return chunks;
  }

  /// Generate response using RAG
  Future<String> generateResponse({
    required String query,
    required String templeId,
    String? userLanguage,
    String? templeName,
  }) async {
    try {
      final language = userLanguage ??
          _languageDetection.detectLanguage(query).language.code;

      final relevantChunks = await retrieveRelevantContent(
        query: query,
        templeId: templeId,
        language: language,
      );

      final response = await _callGroqAPI(
        query: query,
        context: relevantChunks,
        language: language,
        templeId: templeId,
        templeName: templeName,
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
    String templeId = '',
    String? templeName,
  }) async {
    if (_apiKey.isEmpty) {
      return _buildOfflineResponse(query, context, language);
    }

    final contextText = context.isNotEmpty
        ? context.join('\n\n')
        : 'No specific records found for this temple in the local knowledge base.';

    final templeLabel = templeName ?? templeId.replaceAll('_', ' ');

    final systemPrompt = _buildSystemPrompt(language, templeLabel);

    final userPrompt = '''
Temple: $templeLabel
Query: $query

Verified temple information from our knowledge base:
$contextText

Answer the query using ONLY the information above. 
Do NOT use placeholder text like [Deity's Name], [Year], [Era/Dynasty] or any bracketed templates.
If the knowledge base does not contain enough detail, say so honestly and share what you do know.
''';

    final requestBody = jsonEncode({
      'model': _config.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.4,
      'max_tokens': 1024,
    });

    final response = await http.post(
      Uri.parse(_groqApiUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: requestBody,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Request timed out. Please try again.'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Build system prompt based on language
  String _buildSystemPrompt(String language, String templeName) {
    final base = {
      'en': '''You are a knowledgeable temple guide for $templeName.
Answer questions using ONLY the verified information provided in the context.
Never use placeholder text like [Deity's Name], [Year], [Era/Dynasty], or any bracketed templates.
If you don't have enough information, say "I don't have detailed records on that for $templeName, but here's what I know:" and share what's available.
Keep answers concise, warm, and culturally respectful.''',
      'hi': '''आप $templeName के लिए एक जानकार मंदिर गाइड हैं।
केवल प्रदान की गई सत्यापित जानकारी का उपयोग करके प्रश्नों का उत्तर दें।
कभी भी [देवता का नाम], [वर्ष] जैसे placeholder text का उपयोग न करें।
उत्तर संक्षिप्त और सांस्कृतिक रूप से सम्मानजनक रखें।''',
      'te': '''మీరు $templeName కోసం నిపుణుడైన ఆలయ గైడ్.
అందించిన ధృవీకరించిన సమాచారాన్ని మాత్రమే ఉపయోగించి ప్రశ్నలకు సమాధానం ఇవ్వండి.
[దేవత పేరు], [సంవత్సరం] వంటి placeholder text ఎప్పుడూ ఉపయోగించవద్దు.''',
      'ta': '''நீங்கள் $templeName-க்கான அறிவுள்ள கோவில் வழிகாட்டி.
வழங்கப்பட்ட சரிபார்க்கப்பட்ட தகவல்களை மட்டுமே பயன்படுத்தி கேள்விகளுக்கு பதிலளிக்கவும்.
[தெய்வத்தின் பெயர்], [ஆண்டு] போன்ற placeholder text பயன்படுத்தாதீர்கள்.''',
    };

    return base[language] ?? base['en']!;
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

  /// Offline fallback: answer from local knowledge base only
  String _buildOfflineResponse(
    String query,
    List<String> context,
    String language,
  ) {
    if (context.isEmpty) {
      return 'I don\'t have specific information about that. '
          'Please connect to the internet for AI-powered answers.';
    }
    // Return the most relevant chunk as a plain answer
    return '${context.first}\n\n'
        '(Offline mode — connect to the internet for richer AI responses.)';
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
