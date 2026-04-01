/// AI Chatbot Screen for Temple Questions
/// Provides quick access to RAG-powered Q&A about temples
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/temple_model.dart';
import '../database/db_providers.dart';
import '../services/rag_service.dart';
import '../services/language_detection_service.dart';
import '../theme/app_theme.dart';

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

class ChatbotScreen extends ConsumerStatefulWidget {
  final Temple? initialTemple;

  const ChatbotScreen({
    super.key,
    this.initialTemple,
  });

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  late RAGService _ragService;
  final LanguageDetectionService _languageService = LanguageDetectionService();
  
  final TextEditingController _questionController = TextEditingController();
  final List<ChatMessage> _chatMessages = [];
  bool _isTyping = false;
  String _selectedLanguage = 'en';
  
  Temple? _selectedTemple;
  bool _showTempleSelector = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _selectedTemple = widget.initialTemple;
    
    // Add welcome message
    _chatMessages.add(ChatMessage(
      text: 'Namaste! I\'m your Temple Guide. Ask me anything about temples - their history, rituals, mantras, traditions, and more.\n\nSelect a temple above to get started, or ask a general question.',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _initializeService() async {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    _ragService = RAGService(apiKey: apiKey);
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _showTempleSelector = false;
      _chatMessages.add(ChatMessage(
        text: question,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _questionController.clear();

    try {
      final response = await _ragService.generateResponse(
        query: question,
        templeId: _selectedTemple?.id ?? 'general',
        userLanguage: _selectedLanguage,
        templeName: _selectedTemple?.name,
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

  void _selectTemple(Temple temple) {
    setState(() {
      _selectedTemple = temple;
      _showTempleSelector = true;
      _chatMessages.clear();
      _chatMessages.add(ChatMessage(
        text: 'Now asking about ${temple.name}. What would you like to know?',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Widget _buildTempleSelector() {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final templeCardWidth = isSmallScreen ? 70.0 : 80.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.temple_hindu, color: AppTheme.saffron, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Select a Temple',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_selectedTemple != null)
                TextButton(
                  onPressed: () => _selectTemple(_selectedTemple!),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Clear'),
                ),
            ],
          ),
          SizedBox(
            height: templeCardWidth + 20,
            child: Builder(
              builder: (context) {
                final temples = ref.watch(allTemplesDbProvider).valueOrNull ?? [];
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: temples.length,
                  itemBuilder: (context, index) {
                    final temple = temples[index];
                    final isSelected = _selectedTemple?.id == temple.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => _selectTemple(temple),
                        child: Container(
                          width: templeCardWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.saffron : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            color: isSelected ? AppTheme.saffron.withValues(alpha: 0.1) : Colors.white,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.temple_hindu,
                                color: isSelected ? AppTheme.saffron : Colors.grey[600],
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  temple.name.split(' ').take(2).join(' '),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppTheme.saffron : Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    final quickQuestions = [
      'History',
      'Rituals',
      'Mantras',
      'Significance',
      'Festivals',
      'Architecture',
    ];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: quickQuestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                quickQuestions[index],
                style: const TextStyle(fontSize: 12),
              ),
              avatar: const Icon(Icons.auto_awesome, size: 14),
              onPressed: () {
                final question = 'Tell me about ${quickQuestions[index]}';
                _questionController.text = question;
                _askQuestion();
              },
              padding: EdgeInsets.zero,
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.saffron : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          softWrap: true,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.saffron),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Temple Guide'),
            if (_selectedTemple != null)
              Text(
                _selectedTemple!.name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, size: 22),
            onSelected: (lang) {
              setState(() {
                _selectedLanguage = lang;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'en', child: Text('English')),
              const PopupMenuItem(value: 'hi', child: Text('हिन्दी')),
              const PopupMenuItem(value: 'ta', child: Text('தமிழ்')),
              const PopupMenuItem(value: 'te', child: Text('తెలుగు')),
              const PopupMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')),
              const PopupMenuItem(value: 'ml', child: Text('മലയാളം')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Temple selector
          if (_showTempleSelector) _buildTempleSelector(),
          
          // Quick questions
          if (_showTempleSelector && _selectedTemple != null)
            SizedBox(
              height: isSmallScreen ? 32 : 36,
              child: _buildQuickQuestions(),
            ),
          
          const Divider(height: 1),
          
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        hintText: _selectedTemple != null 
                            ? 'Ask about ${_selectedTemple!.name.split(' ').first}...' 
                            : 'Ask a temple question...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _askQuestion(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: IconButton(
                      onPressed: _isTyping ? null : _askQuestion,
                      icon: const Icon(Icons.send),
                      color: AppTheme.saffron,
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
