import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/player_provider.dart';
import '../widgets/track_card.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final List<String> _emotions = [
    'happy', 'sad', 'angry', 'motivational', 'fear',
    'depressing', 'surprising', 'stressed', 'calm',
    'lonely', 'romantic', 'nostalgic', 'mixed',
  ];
  
  final List<String> _emotionEmojis = [
    '😊', '😢', '😠', '💪', '😨',
    '😔', '😲', '😤', '😌',
    '🥺', '💕', '🌅', '🎭',
  ];

  String? _selectedEmotion;
  List<dynamic> _tracks = [];
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations 🎵')),
      body: Column(
        children: [
          // Emotion selector
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _emotions.length,
              itemBuilder: (ctx, i) {
                final em = _emotions[i];
                final emoji = _emotionEmojis[i];
                final isSelected = _selectedEmotion == em;
                final color = AppColors.emotionColors[em] ?? AppColors.accent;

                return GestureDetector(
                  onTap: () => _selectEmotion(em),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color
                          : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected ? color : color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          '${em[0].toUpperCase()}${em.substring(1)}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white54 : Colors.black54),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Tracks
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tracks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_note,
                                size: 60,
                                color: isDark
                                    ? Colors.white12
                                    : Colors.black12),
                            const SizedBox(height: 12),
                            Text(
                              'Select a mood above',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _tracks.length,
                        itemBuilder: (ctx, i) => TrackCard(
                          track: Map<String, dynamic>.from(_tracks[i]),
                          onTap: () => _playFrom(i),
                          emotion: _selectedEmotion ?? 'mixed',
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectEmotion(String emotion) async {
    setState(() {
      _selectedEmotion = emotion;
      _loading = true;
      _tracks = [];
    });

    try {
      final result = await ApiService.analyzeEmotion(
          'I am feeling $emotion today');
      setState(() {
        _tracks = result['tracks'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _playFrom(int index) {
    final trackList =
        _tracks.map((t) => Map<String, dynamic>.from(t)).toList();
    context.read<PlayerProvider>().loadPlaylist(
          trackList,
          _selectedEmotion ?? 'mixed',
        );
    context.read<PlayerProvider>().playTrackAtIndex(index);
  }
}
