import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (track == null) return const SizedBox.shrink();

    final progress = player.duration.inSeconds > 0
        ? player.position.inSeconds / player.duration.inSeconds
        : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Album art
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: track['image'] != null && track['image'].isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: track['image'],
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7EFFD4), Color(0xFFDDFF7E)],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(Icons.music_note,
                                      size: 80, color: Colors.black54),
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Track info + favorite button
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track['name'] ?? '',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track['artist'] ?? '',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_border,
                            color: AppColors.accent),
                        onPressed: () => _addToFavorites(context, track),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppColors.accent,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (v) {
                        final pos = Duration(
                            seconds: (v * player.duration.inSeconds).toInt());
                        player.seekTo(pos);
                      },
                    ),
                  ),

                  // Time labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(player.position),
                          style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12)),
                      Text(_formatDuration(player.duration),
                          style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.shuffle,
                            color: isDark ? Colors.white54 : Colors.black54),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_previous,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 32),
                        onPressed: player.previous,
                      ),
                      GestureDetector(
                        onTap: player.togglePlayPause,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            player.isLoading
                                ? Icons.hourglass_empty
                                : player.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 32),
                        onPressed: player.next,
                      ),
                      IconButton(
                        icon: Icon(Icons.repeat,
                            color: isDark ? Colors.white54 : Colors.black54),
                        onPressed: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Preview notice
                  if (track['preview_url'] == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Text(
                        '⚠️ No preview available for this track.\nConnect Spotify for full playback.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange, fontSize: 12),
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

  Future<void> _addToFavorites(
      BuildContext context, Map<String, dynamic> track) async {
    try {
      await ApiService.addFavorite({
        'spotify_track_id': track['id'],
        'track_name': track['name'],
        'artist_name': track['artist'],
        'album_name': track['album'] ?? '',
        'album_image': track['image'] ?? '',
        'preview_url': track['preview_url'],
        'duration_ms': track['duration_ms'] ?? 0,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to favorites! ❤️'),
          backgroundColor: Color(0xFF9EFF65),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding to favorites')),
      );
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
