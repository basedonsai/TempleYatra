/// Storytelling Screen for Temple Stories
/// Displays culturally authentic storytelling content with audio support
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/temple_model.dart';
import '../models/cultural_content.dart';
import '../data/cultural_content_data.dart';
import '../services/rag_service.dart';
import '../services/regional_tts_service.dart';
import '../services/language_detection_service.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_theme.dart';

/// Chat message model for chatbot interface
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class StorytellingScreen extends StatefulWidget {
  final String templeId;
  final Temple? temple;

  const StorytellingScreen({
    super.key,
    required this.templeId,
    this.temple,
  });

  @override
  State<StorytellingScreen> createState() => _StorytellingScreenState();
}

class _StorytellingScreenState extends State<StorytellingScreen> {
  // Services
  late RAGService _ragService;
  late RegionalTTSService _ttsService;
  late OfflineCacheService _cacheService;
  final LanguageDetectionService _languageService = LanguageDetectionService();

  // State
  String _selectedLanguage = 'en';
  ContentType _selectedContentType = ContentType.sthalaPuranam;
  bool _isLoading = false;
  bool _isPlaying = false;
  String _storyContent = '';
  String _storyTitle = '';
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String _errorMessage = '';
   
  // Chatbot state
  bool _showChatbot = false;
  final TextEditingController _questionController = TextEditingController();
  final List<ChatMessage> _chatMessages = [];
  bool _isTyping = false;

  // Content cache
  List<ContentType> _availableTypes = [];
  List<String> _availableLanguages = ['en'];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadAvailableContent();
    _loadDefaultContent();
  }

  void _initializeServices() async {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    _ragService = RAGService(apiKey: apiKey);
    _ttsService = RegionalTTSService();
    _cacheService = OfflineCacheService();

    // Set up TTS callbacks
    _ttsService.setCallbacks(
      onPositionChanged: (position, total) {
        setState(() {
          _currentPosition = position;
          _totalDuration = total;
        });
      },
      onStateChanged: (state) {
        setState(() {
          _isPlaying = state == TTSState.playing;
        });
      },
    );
  }

  void _loadAvailableContent() async {
    final contentData = CulturalContentData();
    final content = contentData.getContentForTemple(widget.templeId);
    
    setState(() {
      _availableTypes = content.keys.toList();
      _availableLanguages = ['en', 'hi', 'ta', 'te', 'kn', 'ml', 'bn', 'mr', 'gu'];
    });
  }

  void _loadDefaultContent() {
    _loadContent();
  }

  void _loadContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contentData = CulturalContentData();
      final templeContent = contentData.getContentForTemple(widget.templeId);
      
      String content = '';
      String title = '';
      
      if (templeContent.containsKey(_selectedContentType)) {
        final contentItem = templeContent[_selectedContentType]!;
        title = contentItem.title;
        content = contentItem.getContent(_selectedLanguage);
        
        // Translate if needed
        if (content.isEmpty && contentItem.content.isNotEmpty) {
          content = contentItem.content; // Fallback to default
        }
      }
      
      setState(() {
        _storyTitle = title;
        _storyContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

  void _changeLanguage(String language) {
    setState(() {
      _selectedLanguage = language;
    });
    _loadContent();
  }

  void _changeContentType(ContentType type) {
    setState(() {
      _selectedContentType = type;
    });
    _loadContent();
  }

  void _togglePlayPause() async {
    if (!_isPlaying && _storyContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content is still loading. Please wait.')),
      );
      return;
    }
    if (_isPlaying) {
      await _ttsService.pause();
    } else {
      await _ttsService.speak(
        text: _storyContent,
        languageCode: _selectedLanguage,
      );
    }
  }

  /// Handle user question
  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    // Add user message
    setState(() {
      _chatMessages.add(ChatMessage(
        text: question,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _questionController.clear();

    try {
      // Get response from RAG
      final response = await _ragService.generateResponse(
        query: question,
        templeId: widget.templeId,
        userLanguage: _selectedLanguage,
      );

      setState(() {
        _chatMessages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        _chatMessages.add(ChatMessage(
          text: 'Sorry, I couldn\'t find an answer. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    }
  }

  /// Toggle chatbot visibility
  void _toggleChatbot() {
    setState(() {
      _showChatbot = !_showChatbot;
    });
  }

  void _stopAudio() async {
    await _ttsService.stop();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showChatbot ? 'Ask About ${widget.temple?.name ?? 'Temple'}' : '${widget.temple?.name ?? 'Temple'} Stories'),
        actions: [
          _buildLanguageSelector(),
          _buildOfflineIndicator(),
          _buildChatbotToggle(),
        ],
      ),
      body: _showChatbot ? _buildChatbotInterface() : _buildStorytellingInterface(),
    );
  }

  /// Build language selector dropdown
  Widget _buildLanguageSelector() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      onSelected: _changeLanguage,
      itemBuilder: (context) => _availableLanguages.map((lang) {
        return PopupMenuItem<String>(
          value: lang,
          child: Row(
            children: [
              Text(_languageService.getDisplayName(lang)),
              if (lang == _selectedLanguage)
                const Icon(Icons.check, size: 16),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build offline indicator
  Widget _buildOfflineIndicator() {
    return FutureBuilder<bool>(
      future: _cacheService.isContentCached(
        templeId: widget.templeId,
        contentType: _selectedContentType.name,
        language: _selectedLanguage,
      ),
      builder: (context, snapshot) {
        final isCached = snapshot.data ?? false;
        return Icon(
          isCached ? Icons.offline_bolt : Icons.cloud_download,
          color: isCached ? Colors.green : Colors.grey,
          size: 20,
        );
      },
    );
  }

  /// Build chatbot toggle button
  Widget _buildChatbotToggle() {
    return IconButton(
      icon: Icon(_showChatbot ? Icons.menu_book : Icons.chat_bubble_outline),
      tooltip: _showChatbot ? 'View Stories' : 'Ask Questions',
      onPressed: _toggleChatbot,
    );
  }

  /// Build chatbot interface
  Widget _buildChatbotInterface() {
    return Column(
      children: [
        // Welcome message
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.saffron.withValues(alpha: 0.1),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.saffron,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ask me anything about this temple - its history, rituals, mantras, traditions, and more!',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        
        // Chat messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _chatMessages.length) {
                return _buildTypingIndicator();
              }
              return _buildChatMessage(_chatMessages[index]);
            },
          ),
        ),
        
        // Input field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: 'Ask a question about this temple...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 3,
                  onSubmitted: (_) => _askQuestion(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.saffron,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _isTyping ? null : _askQuestion,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build content type selector
  Widget _buildContentTypeSelector() {
    final contentTypes = [
      (ContentType.sthalaPuranam, 'Sthala Puranam'),
      (ContentType.ritual, 'Rituals'),
      (ContentType.mantra, 'Mantras'),
      (ContentType.significance, 'Significance'),
      (ContentType.history, 'History'),
      (ContentType.architecture, 'Architecture'),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: contentTypes.map((type) {
          final (contentType, label) = type;
          final isSelected = _selectedContentType == contentType;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: AppTheme.saffron.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.saffron,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.saffron : Colors.black87,
              ),
              onSelected: (_) => _changeContentType(contentType),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build chat message bubble
  Widget _buildChatMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.saffron : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: message.isUser ? Colors.white70 : Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build typing indicator
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Thinking...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /// Format timestamp
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Build storytelling interface
  Widget _buildStorytellingInterface() {
    return Column(
      children: [
        _buildContentTypeSelector(),
        Expanded(child: _buildStorytellingContent()),
        _buildAudioControls(),
      ],
    );
  }

  /// Build storytelling content display
  Widget _buildStorytellingContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_storyContent.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _storyTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Text(
            _storyContent,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          // Source attribution
          const Text(
            'Information sourced from temple traditions and verified sources.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          Column(
            children: [
              Slider(
                value: _totalDuration.inSeconds > 0
                    ? _currentPosition.inSeconds / _totalDuration.inSeconds
                    : 0,
                onChanged: (_) {}, // TTS doesn't support seeking
                activeColor: AppTheme.saffron,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_currentPosition)),
                    Text(_formatDuration(_totalDuration)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: _isPlaying ? () {} : null, // Replay not supported for streaming
              ),
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.saffron,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.saffron.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _isPlaying ? _stopAudio : null,
              ),
              IconButton(
                icon: const Icon(Icons.speed),
                tooltip: 'Audio Quality',
                onPressed: () {}, // Quality settings could be added
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
