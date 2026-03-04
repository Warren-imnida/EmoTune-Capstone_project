import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/api_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  
  Map<String, dynamic>? _currentTrack;
  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _currentEmotion;
  int? _historyId;
  int _totalListenTime = 0;
  bool _feelBetterShown = false;

  Map<String, dynamic>? get currentTrack => _currentTrack;
  List<Map<String, dynamic>> get playlist => _playlist;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  int get currentIndex => _currentIndex;
  String? get currentEmotion => _currentEmotion;

  PlayerProvider() {
    _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.durationStream.listen((d) {
      if (d != null) {
        _duration = d;
        notifyListeners();
      }
    });
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
      notifyListeners();
    });
  }

  void loadPlaylist(List<Map<String, dynamic>> tracks, String emotion, {int? historyId}) {
    _playlist = tracks;
    _currentEmotion = emotion;
    _historyId = historyId;
    _feelBetterShown = false;
    _totalListenTime = 0;
    if (tracks.isNotEmpty) {
      playTrackAtIndex(0);
    }
  }

  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    
    final track = _playlist[index];
    _currentIndex = index;
    _currentTrack = track;
    _isLoading = true;
    notifyListeners();

    try {
      final previewUrl = track['preview_url'];
      if (previewUrl != null && previewUrl.isNotEmpty) {
        await _player.setUrl(previewUrl);
        await _player.play();
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() async {
    if (_currentIndex < _playlist.length - 1) {
      _trackListened();
      await playTrackAtIndex(_currentIndex + 1);
    } else {
      // Playlist finished - check feel better
      _onPlaylistFinished();
    }
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      await playTrackAtIndex(_currentIndex - 1);
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void _onTrackCompleted() {
    _trackListened();
    if (_currentIndex < _playlist.length - 1) {
      playTrackAtIndex(_currentIndex + 1);
    } else {
      _onPlaylistFinished();
    }
  }

  void _trackListened() {
    final track = _currentTrack;
    if (track != null && _currentEmotion != null) {
      final listenSecs = _position.inSeconds;
      _totalListenTime += listenSecs;
      
      // Update adaptive preferences if listened >30 seconds
      if (listenSecs > 30) {
        ApiService.updateListenTime(
          track['id'] ?? '',
          _currentEmotion!,
          listenSecs,
          track['name'] ?? '',
          track['artist'] ?? '',
        );
      }

      // Check feel better after 20 minutes
      if (_totalListenTime > 1200 && !_feelBetterShown) {
        _feelBetterShown = true;
        _triggerFeelBetter();
      }
    }
  }

  void _onPlaylistFinished() {
    if (!_feelBetterShown) {
      _feelBetterShown = true;
      _triggerFeelBetter();
    }
  }

  Function(Map<String, dynamic>)? onFeelBetter;

  Future<void> _triggerFeelBetter() async {
    if (_historyId != null) {
      try {
        final result = await ApiService.checkFeelBetter(_historyId!, _totalListenTime);
        onFeelBetter?.call(result);
      } catch (e) {
        debugPrint('Feel better check error: $e');
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
