import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../providers/player_provider.dart';
import 'package:provider/provider.dart';

class FeelBetterDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const FeelBetterDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final upliftTracks = List<Map<String, dynamic>>.from(data['uplift_tracks'] ?? []);

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌟', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              data['message'] ?? 'Feel better?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (upliftTracks.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Here\'s a song for you:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              ...upliftTracks.take(1).map((track) => _UpliftTrackTile(track: track)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Not yet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Yes! 😊'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpliftTrackTile extends StatelessWidget {
  final Map<String, dynamic> track;
  const _UpliftTrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<PlayerProvider>().loadPlaylist([track], 'happy');
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50,
                height: 50,
                child: track['image'] != null && track['image'].isNotEmpty
                    ? Image.network(track['image'], fit: BoxFit.cover)
                    : Container(
                        color: AppColors.accent.withOpacity(0.3),
                        child: const Icon(Icons.music_note),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track['artist'] ?? '',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
