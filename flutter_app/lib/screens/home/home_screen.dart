import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/emotune_logo.dart';
import '../widgets/track_card.dart';
import '../widgets/mini_player.dart';
import '../widgets/feel_better_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _promptCtrl = TextEditingController();
  bool _isAnalyzing = false;
  Map<String, dynamic>? _lastResult;
  String? _aiMessage;
  List<Map<String, dynamic>> _tracks = [];

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerProvider>();
    player.onFeelBetter = (result) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => FeelBetterDialog(data: result),
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmoTuneLogo(size: 60, showText: true),
                ],
              ),
            ),

            // Chat/Result area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_aiMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A1A)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _aiMessage!,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            if (_lastResult != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.emotionColors[_lastResult!['emotion']]
                                          ?.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.emotionColors[_lastResult!['emotion']] ??
                                            AppColors.accent,
                                      ),
                                    ),
                                    child: Text(
                                      '${_lastResult!['emotion'].toString().toUpperCase()} '
                                      '${_lastResult!['confidence']}%',
                                      style: TextStyle(
                                        color: AppColors.emotionColors[_lastResult!['emotion']] ??
                                            AppColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_tracks.isNotEmpty) ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _tracks.length,
                        itemBuilder: (ctx, i) => TrackCard(
                          track: _tracks[i],
                          onTap: () => _playTrack(i),
                          emotion: _lastResult?['emotion'] ?? 'mixed',
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],

                    if (_tracks.isEmpty && _aiMessage == null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Icon(Icons.music_note,
                                  size: 60,
                                  color: isDark ? Colors.white12 : Colors.black12),
                              const SizedBox(height: 12),
                              Text(
                                'Tell me how you feel...',
                                style: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Mini player
            const MiniPlayer(),

            // Prompt input
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptCtrl,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'I feel......',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontStyle: FontStyle.italic,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _analyze(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isAnalyzing ? null : _analyze,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        shape: BoxShape.circle,
                      ),
                      child: _isAnalyzing
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.send, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _tracks = [];
      _aiMessage = null;
    });

    try {
      final result = await ApiService.analyzeEmotion(text);
      setState(() {
        _lastResult = result;
        _aiMessage = result['ai_response'];
        _tracks = List<Map<String, dynamic>>.from(result['tracks'] ?? []);
      });
      
      // Auto-load playlist in player
      if (_tracks.isNotEmpty) {
        context.read<PlayerProvider>().loadPlaylist(
          _tracks,
          result['emotion'],
          historyId: result['history_id'],
        );
      }
      _promptCtrl.clear();
    } catch (e) {
      setState(() {
        _aiMessage = 'Connection error. Please check if the backend is running.';
      });
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _playTrack(int index) {
    context.read<PlayerProvider>().playTrackAtIndex(index);
  }
}
