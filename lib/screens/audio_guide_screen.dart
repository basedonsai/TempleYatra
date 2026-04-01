import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../services/regional_tts_service.dart';
import '../services/offline_cache_service.dart';
import '../data/cultural_content_data.dart';
import '../models/cultural_content.dart';

class AudioGuideScreen extends StatefulWidget {
  final String templeId;
  final String templeName;

  const AudioGuideScreen({
    super.key,
    required this.templeId,
    required this.templeName,
  });

  @override
  State<AudioGuideScreen> createState() => _AudioGuideScreenState();
}

class _AudioGuideScreenState extends State<AudioGuideScreen> {
  bool _isPlaying = false;
  bool _isLoading = false;
  String _selectedLanguage = 'en';
  String _selectedContentType = 'sthalaPuranam';
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _timer;
  String? _currentText;
  String? _errorMessage;
  double _playbackSpeed = 1.0;
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  bool _isDownloading = false;
  bool _isDownloaded = false;

  // Services
  final RegionalTTSService _ttsService = RegionalTTSService();
  final OfflineCacheService _cacheService = OfflineCacheService();

  // Available languages for audio guide
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिंदी (Hindi)'},
    {'code': 'ta', 'name': 'தமிழ் (Tamil)'},
    {'code': 'te', 'name': 'తెలుగు (Telugu)'},
    {'code': 'kn', 'name': 'ಕನ್ನಡ (Kannada)'},
    {'code': 'ml', 'name': 'മലയാളം (Malayalam)'},
  ];

  // Content types
  final List<Map<String, String>> _contentTypes = [
    {'type': 'sthalaPuranam', 'label': 'Temple History'},
    {'type': 'ritual', 'label': 'Rituals & Traditions'},
    {'type': 'mantra', 'label': 'Mantras & Prayers'},
    {'type': 'significance', 'label': 'Spiritual Significance'},
  ];

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final content = await _getContentForCurrentSelection();
      
      if (content != null && content.isNotEmpty) {
        // Estimate duration: ~130 words/min average TTS speed
        final wordCount = content.split(RegExp(r'\s+')).length;
        final estimatedSeconds = (wordCount / 130 * 60).ceil();
        final estimatedDuration = Duration(seconds: estimatedSeconds.clamp(10, 3600));
        setState(() {
          _currentText = content;
          _totalDuration = estimatedDuration;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No content available for this selection';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

  Future<String?> _getContentForCurrentSelection() async {
    try {
      final type = ContentType.values.firstWhere(
        (e) => e.toString().split('.').last == _selectedContentType,
        orElse: () => ContentType.sthalaPuranam,
      );
      
      // First check cache
      final isCached = await _cacheService.isContentCached(
        templeId: widget.templeId,
        contentType: _selectedContentType,
        language: _selectedLanguage,
      );
      
      if (isCached) {
        final cached = await _cacheService.getCachedContent(
          templeId: widget.templeId,
          contentType: _selectedContentType,
          language: _selectedLanguage,
        );
        return cached;
      }
      
      // Get from knowledge base
      final contentList = getContentByType(widget.templeId, type);
      
      if (contentList.isEmpty) {
        return _getSampleContent();
      }
      
      final inLanguage = contentList.firstWhere(
        (c) => c.language == _selectedLanguage,
        orElse: () => contentList.first,
      );
      
      return inLanguage.content;
    } catch (e) {
      if (kDebugMode) print('Error getting content: $e');
      return _getSampleContent();
    }
  }

  String _getSampleContent() {
    final Map<String, Map<String, String>> sampleContent = {
      'sthalaPuranam': {
        'en': 'Welcome to ${widget.templeName}. This ancient temple has been a center of spiritual devotion for centuries. The architecture reflects the rich cultural heritage of our ancestors.',
        'hi': '${widget.templeName} में आपका स्वागत है। यह प्राचीन मंदिर सदियों से आध्यात्मिक भक्ति का केंद्र रहा है।',
        'ta': '${widget.templeName}க்கு நல்வரவு. இந்த பழமையான கோவில் நூற்றாண்டுகளாக ஆன்மிக பக்தியின் மையமாக இருந்து வருகிறது.',
        'te': '${widget.templeName}కి స్వాగతం. ఈ పురాతన ఆలయం శతాబ్దాలుగా ఆధ్యాత్మిక భక్తి కేంద్రంగా ఉంది.',
      },
    };
    
    return sampleContent[_selectedContentType]?[_selectedLanguage] ??
           sampleContent['sthalaPuranam']?['en'] ??
           'Audio guide content for ${widget.templeName}.';
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      _pauseAudio();
    } else {
      await _playAudio();
    }
  }

  Future<void> _playAudio() async {
    if (_currentText == null || _currentText!.isEmpty) {
      await _loadContent();
      if (_currentText == null || _currentText!.isEmpty) return;
    }

    setState(() {
      _isPlaying = true;
      _errorMessage = null;
    });

    try {
      await _ttsService.speak(
        text: _currentText!,
        languageCode: _selectedLanguage,
      );

      _startProgressTimer();
    } catch (e) {
      setState(() {
        _isPlaying = false;
        _errorMessage = 'Audio playback failed: $e';
      });
    }
  }

  void _pauseAudio() {
    _ttsService.stop();
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _startProgressTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentPosition < _totalDuration) {
        setState(() {
          _currentPosition = Duration(seconds: _currentPosition.inSeconds + 1);
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _onLanguageChanged(String language) {
    _pauseAudio();
    setState(() {
      _selectedLanguage = language;
      _currentPosition = Duration.zero;
      _isDownloaded = false;
    });
    _loadContent();
  }

  void _onContentTypeChanged(String contentType) {
    _pauseAudio();
    setState(() {
      _selectedContentType = contentType;
      _currentPosition = Duration.zero;
      _isDownloaded = false;
    });
    _loadContent();
  }

  Future<void> _downloadForOffline() async {
    if (_isDownloading || _isDownloaded) return;
    if (_currentText == null || _currentText!.isEmpty) return;

    setState(() => _isDownloading = true);

    try {
      await _cacheService.cacheContent(
        templeId: widget.templeId,
        contentType: _selectedContentType,
        language: _selectedLanguage,
        content: _currentText!,
      );
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved for offline use'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration.inSeconds > 0
        ? _currentPosition.inSeconds / _totalDuration.inSeconds
        : 0.0;

    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Guide', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF8B0000),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Language selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: _onLanguageChanged,
            itemBuilder: (context) => _languages.map((lang) {
              return PopupMenuItem(
                value: lang['code'],
                child: Text(lang['name']!),
              );
            }).toList(),
          ),
          // Content type selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_book, color: Colors.white),
            tooltip: 'Content Type',
            onSelected: _onContentTypeChanged,
            itemBuilder: (context) => _contentTypes.map((type) {
              return PopupMenuItem(
                value: type['type'],
                child: Text(type['label']!),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Temple Image/Icon
                  Container(
                    width: isSmallScreen ? 150 : 180,
                    height: isSmallScreen ? 150 : 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9933).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF9933),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.temple_hindu,
                      size: isSmallScreen ? 60 : 80,
                      color: const Color(0xFFFF9933),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.templeName,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 22 : 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Audio Guide',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Selection indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge(
                        Icons.language,
                        _languages.firstWhere(
                          (l) => l['code'] == _selectedLanguage,
                          orElse: () => _languages[0],
                        )['name']!,
                      ),
                      const SizedBox(width: 12),
                      _buildBadge(
                        Icons.menu_book,
                        _contentTypes.firstWhere(
                          (t) => t['type'] == _selectedContentType,
                          orElse: () => _contentTypes[0],
                        )['label']!,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Content preview or loading/error state
                  if (_isLoading)
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFF9933)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading content...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[400], size: 48),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadContent,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9933),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_currentText != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        _currentText!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Audio Controls
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Progress Bar
                Column(
                  children: [
                    Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        setState(() {
                          _currentPosition = Duration(
                            seconds: (value * _totalDuration.inSeconds).toInt(),
                          );
                        });
                      },
                      activeColor: const Color(0xFFFF9933),
                      inactiveColor: Colors.grey[300],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_currentPosition),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _formatDuration(_totalDuration),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Download button — shows spinner while saving, checkmark when done
                    IconButton(
                      onPressed: (_isDownloading || _isDownloaded || _currentText == null)
                          ? null
                          : _downloadForOffline,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isDownloaded ? Icons.cloud_done : Icons.cloud_download,
                              color: _isDownloaded ? Colors.green : Colors.grey[600],
                              size: 24,
                            ),
                      tooltip: _isDownloaded ? 'Saved offline' : 'Save for offline',
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Play/Pause button
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9933),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9933).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _togglePlayPause,
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Speed button
                    IconButton(
                      onPressed: () {
                        final currentIndex = _speeds.indexOf(_playbackSpeed);
                        final nextIndex = (currentIndex + 1) % _speeds.length;
                        setState(() => _playbackSpeed = _speeds[nextIndex]);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Speed: ${_playbackSpeed}x'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: Icon(Icons.speed, color: Colors.grey[600], size: 24),
                      tooltip: 'Playback speed: ${_playbackSpeed}x',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8B0000).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8B0000)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8B0000),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
