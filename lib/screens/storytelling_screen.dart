import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/temple_model.dart';
import '../models/cultural_content.dart';
import '../data/cultural_content_data.dart';
import '../services/rag_service.dart';
import '../theme/app_theme.dart';
import '../models/audio_pack.dart';
import '../providers/audio_pack_provider.dart';
import '../widgets/offline_badge.dart';

class _ChatMsg {
  final String text;
  final bool isUser;
  _ChatMsg(this.text, this.isUser);
}

class StorytellingScreen extends ConsumerStatefulWidget {
  final String templeId;
  final Temple? temple;
  const StorytellingScreen({super.key, required this.templeId, this.temple});

  @override
  ConsumerState<StorytellingScreen> createState() => _StorytellingScreenState();
}

class _StorytellingScreenState extends ConsumerState<StorytellingScreen> {
  // ── TTS ──────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _playing = false;
  Timer? _timer;
  int _elapsed = 0;   // seconds
  int _total = 0;     // estimated seconds

  // ── Content ───────────────────────────────────────────────────────────────
  String _title = '';
  String _text = '';
  bool _loading = true;
  ContentType _tab = ContentType.sthalaPuranam;
  String _lang = 'en';

  // ── Chatbot ───────────────────────────────────────────────────────────────
  bool _showChat = false;
  final _chatCtrl = TextEditingController();
  final List<_ChatMsg> _msgs = [];
  bool _thinking = false;
  late RAGService _rag;

  // ── Offline pack ──────────────────────────────────────────────────────────
  bool _useOffline = false;

  // ── Language map ──────────────────────────────────────────────────────────
  static const _locales = {
    'en': 'en-US', 'hi': 'hi-IN', 'ta': 'ta-IN',
    'te': 'te-IN', 'kn': 'kn-IN', 'ml': 'ml-IN',
    'bn': 'bn-IN', 'mr': 'mr-IN', 'gu': 'gu-IN',
  };
  static const _langNames = {
    'en': 'English', 'hi': 'हिन्दी', 'ta': 'தமிழ்',
    'te': 'తెలుగు', 'kn': 'ಕನ್ನಡ', 'ml': 'മലയാളം',
    'bn': 'বাংলা', 'mr': 'मराठी', 'gu': 'ગુજરાતી',
  };

  @override
  void initState() {
    super.initState();
    _rag = RAGService(apiKey: dotenv.env['GROQ_API_KEY'] ?? '');
    _setupTts();
    _loadContent();
    // Check offline pack
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pack = ref.read(packForTempleProvider(widget.templeId));
      if (pack?.downloadState == DownloadState.downloaded) {
        setState(() => _useOffline = true);
      }
    });
  }

  // ── TTS setup — dead simple ───────────────────────────────────────────────
  void _setupTts() {
    _tts.setStartHandler(() {
      if (!mounted) return;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) { _timer?.cancel(); return; }
        setState(() {
          _elapsed = (_elapsed + 1).clamp(0, _total);
        });
      });
      setState(() => _playing = true);
    });

    _tts.setCompletionHandler(() {
      _timer?.cancel();
      if (!mounted) return;
      setState(() { _playing = false; _elapsed = 0; });
    });

    _tts.setCancelHandler(() {
      _timer?.cancel();
      if (!mounted) return;
      setState(() => _playing = false);
    });

    _tts.setErrorHandler((e) {
      _timer?.cancel();
      debugPrint('TTS error: $e');
      if (!mounted) return;
      setState(() => _playing = false);
    });
  }

  // ── Speak ─────────────────────────────────────────────────────────────────
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    // Stop first, then configure, then speak
    await _tts.stop();
    await _tts.setLanguage(_locales[_lang] ?? 'en-US');
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.85);
    await _tts.setPitch(1.0);
    _elapsed = 0;
    _total = (text.split(RegExp(r'\s+')).length / 2.5).ceil().clamp(5, 3600);
    await _tts.speak(text);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _tts.stop();
    if (mounted) setState(() { _playing = false; _elapsed = 0; });
  }

  // ── Content loading ───────────────────────────────────────────────────────
  void _loadContent() async {
    await _stop();
    setState(() => _loading = true);
    final data = CulturalContentData()
        .getContentForTemple(widget.templeId);
    final item = data[_tab];
    setState(() {
      _title = item?.title ?? '';
      _text = item?.content ?? '';
      _loading = false;
    });
  }

  // ── Play/pause toggle ─────────────────────────────────────────────────────
  Future<void> _togglePlay() async {
    if (_text.isEmpty) return;

    if (_playing) {
      await _stop();
      return;
    }

    // If offline pack has a text file for this category, use that
    if (_useOffline) {
      final pack = ref.read(packForTempleProvider(widget.templeId));
      if (pack?.downloadState == DownloadState.downloaded) {
        final catMap = {
          ContentType.sthalaPuranam: ContentCategory.history,
          ContentType.history: ContentCategory.history,
          ContentType.ritual: ContentCategory.ritual,
          ContentType.significance: ContentCategory.significance,
        };
        final cat = catMap[_tab] ?? ContentCategory.history;
        AudioTrack? track;
        try { track = pack!.tracks.firstWhere((t) => t.category == cat); }
        catch (_) { track = pack?.tracks.firstOrNull; }

        if (track?.localPath != null) {
          final f = File(track!.localPath!);
          if (f.existsSync() && f.lengthSync() > 10) {
            final offlineText = await f.readAsString();
            if (offlineText.isNotEmpty) {
              await _speak(offlineText);
              return;
            }
          }
        }
      }
    }

    // Live TTS from screen content
    await _speak(_text);
  }

  // ── Chatbot ───────────────────────────────────────────────────────────────
  Future<void> _ask() async {
    final q = _chatCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _msgs.add(_ChatMsg(q, true));
      _thinking = true;
    });
    _chatCtrl.clear();
    try {
      final ans = await _rag.generateResponse(
        query: q,
        templeId: widget.templeId,
        userLanguage: _lang,
        templeName: widget.temple?.name,
      );
      if (mounted) setState(() { _msgs.add(_ChatMsg(ans, false)); _thinking = false; });
    } catch (_) {
      if (mounted) setState(() {
        _msgs.add(_ChatMsg('Sorry, could not get an answer. Try again.', false));
        _thinking = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    _chatCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showChat
            ? 'Ask about ${widget.temple?.name ?? 'Temple'}'
            : '${widget.temple?.name ?? 'Temple'} Stories'),
        actions: [
          // Language picker
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (l) { setState(() => _lang = l); _loadContent(); },
            itemBuilder: (_) => _langNames.entries.map((e) => PopupMenuItem(
              value: e.key,
              child: Row(children: [
                Text(e.value),
                const Spacer(),
                if (e.key == _lang) const Icon(Icons.check, size: 16, color: Colors.green),
              ]),
            )).toList(),
          ),
          // Offline badge
          Consumer(builder: (_, ref, __) {
            final pack = ref.watch(packForTempleProvider(widget.templeId));
            if (pack?.downloadState != DownloadState.downloaded) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OfflineBadge(packId: pack!.packId),
            );
          }),
          // Chat toggle
          IconButton(
            icon: Icon(_showChat ? Icons.menu_book : Icons.chat_bubble_outline),
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
        ],
      ),
      body: _showChat ? _buildChat() : _buildStory(),
    );
  }

  // ── Story view ────────────────────────────────────────────────────────────
  Widget _buildStory() {
    return Column(children: [
      _buildTabs(),
      Expanded(child: _buildContent()),
      _buildPlayer(),
    ]);
  }

  Widget _buildTabs() {
    const tabs = [
      (ContentType.sthalaPuranam, 'History'),
      (ContentType.ritual, 'Rituals'),
      (ContentType.mantra, 'Mantras'),
      (ContentType.significance, 'Significance'),
      (ContentType.architecture, 'Architecture'),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: tabs.map((t) {
          final selected = _tab == t.$1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: FilterChip(
              label: Text(t.$2),
              selected: selected,
              selectedColor: AppTheme.saffron.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.saffron,
              onSelected: (_) { setState(() => _tab = t.$1); _loadContent(); },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_text.isEmpty) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text('No content available', style: TextStyle(color: Colors.grey[600])),
      ]),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_title.isNotEmpty) ...[
          Text(_title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
        ],
        Text(_text, style: const TextStyle(fontSize: 16, height: 1.6)),
        const SizedBox(height: 16),
        Text(
          'Sourced from temple traditions and verified records.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }

  Widget _buildPlayer() {
    final progress = _total > 0 ? (_elapsed / _total).clamp(0.0, 1.0) : 0.0;
    String fmt(int s) {
      final m = s ~/ 60;
      final sec = s % 60;
      return '${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
          child: Slider(value: progress, onChanged: null, activeColor: AppTheme.saffron),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmt(_elapsed), style: const TextStyle(fontSize: 12)),
            Text(fmt(_total), style: const TextStyle(fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Stop
          IconButton(
            icon: const Icon(Icons.stop_rounded),
            onPressed: _playing ? _stop : null,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 12),
          // Play / Pause
          GestureDetector(
            onTap: _text.isEmpty ? null : _togglePlay,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _text.isEmpty ? Colors.grey : AppTheme.saffron,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.saffron.withValues(alpha: 0.35), blurRadius: 12)],
              ),
              child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 38, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // Offline toggle (only when pack downloaded)
          Consumer(builder: (_, ref, __) {
            final pack = ref.watch(packForTempleProvider(widget.templeId));
            if (pack?.downloadState != DownloadState.downloaded) return const SizedBox(width: 48);
            return IconButton(
              icon: Icon(_useOffline ? Icons.headphones : Icons.record_voice_over),
              tooltip: _useOffline ? 'Using offline pack' : 'Using live TTS',
              color: _useOffline ? AppTheme.saffron : Colors.grey[600],
              onPressed: () => setState(() => _useOffline = !_useOffline),
            );
          }),
        ]),
      ]),
    );
  }

  // ── Chat view ─────────────────────────────────────────────────────────────
  Widget _buildChat() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        color: AppTheme.saffron.withValues(alpha: 0.08),
        child: Row(children: [
          CircleAvatar(backgroundColor: AppTheme.saffron, radius: 16,
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Ask anything about this temple — history, rituals, mantras, festivals.',
              style: TextStyle(fontSize: 13))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _msgs.length + (_thinking ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _msgs.length) return _bubble('Thinking…', false, thinking: true);
            return _bubble(_msgs[i].text, _msgs[i].isUser);
          },
        ),
      ),
      _buildChatInput(),
    ]);
  }

  Widget _bubble(String text, bool isUser, {bool thinking = false}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.saffron : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: thinking
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[500])),
                const SizedBox(width: 8),
                Text('Thinking…', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ])
            : Text(text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 14)),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              minLines: 1, maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ask about ${widget.temple?.name?.split(' ').first ?? 'temple'}…',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => _ask(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _thinking ? null : _ask,
            icon: const Icon(Icons.send_rounded),
            color: AppTheme.saffron,
          ),
        ]),
      ),
    );
  }
}
