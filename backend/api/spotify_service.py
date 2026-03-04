"""
Spotify API Service for EmoTune
Handles authentication, track search, and playlist generation
"""
import requests
import base64
import json
from datetime import datetime, timedelta
from django.conf import settings
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)

SPOTIFY_AUTH_URL = 'https://accounts.spotify.com/authorize'
SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token'
SPOTIFY_API_BASE = 'https://api.spotify.com/v1'

# Emotion to Spotify search mapping
EMOTION_SEARCH_PARAMS = {
    'happy': {
        'keywords': ['happy', 'upbeat', 'joyful', 'feel good', 'sunshine'],
        'audio_features': {'min_valence': 0.6, 'min_energy': 0.5, 'target_tempo': 120},
        'genres': ['pop', 'dance', 'happy', 'summer'],
    },
    'sad': {
        'keywords': ['sad', 'heartbreak', 'melancholy', 'emotional', 'crying'],
        'audio_features': {'max_valence': 0.4, 'max_energy': 0.5},
        'genres': ['sad', 'acoustic', 'indie', 'singer-songwriter'],
    },
    'angry': {
        'keywords': ['angry', 'rage', 'intense', 'powerful', 'aggressive'],
        'audio_features': {'min_energy': 0.7, 'max_valence': 0.5, 'target_loudness': -5},
        'genres': ['metal', 'rock', 'punk', 'hip-hop'],
    },
    'motivational': {
        'keywords': ['motivational', 'workout', 'pump up', 'champion', 'victory'],
        'audio_features': {'min_energy': 0.7, 'min_valence': 0.5},
        'genres': ['work-out', 'power-pop', 'hip-hop', 'edm'],
    },
    'fear': {
        'keywords': ['fear', 'anxiety', 'tension', 'dark', 'haunting'],
        'audio_features': {'max_valence': 0.4, 'target_mode': 0},
        'genres': ['dark', 'ambient', 'classical'],
    },
    'depressing': {
        'keywords': ['depression', 'hopeless', 'dark', 'empty', 'alone'],
        'audio_features': {'max_valence': 0.3, 'max_energy': 0.4},
        'genres': ['sad', 'emo', 'acoustic', 'blues'],
    },
    'surprising': {
        'keywords': ['surprising', 'unexpected', 'eclectic', 'diverse', 'experimental'],
        'audio_features': {'target_valence': 0.6},
        'genres': ['indie', 'alternative', 'experimental', 'pop'],
    },
    'stressed': {
        'keywords': ['relaxing', 'stress relief', 'calm', 'meditation', 'peaceful'],
        'audio_features': {'max_energy': 0.5, 'max_tempo': 100, 'target_valence': 0.5},
        'genres': ['chill', 'ambient', 'study', 'sleep'],
    },
    'calm': {
        'keywords': ['calm', 'peaceful', 'ambient', 'relaxing', 'meditation'],
        'audio_features': {'max_energy': 0.4, 'max_tempo': 90, 'min_valence': 0.4},
        'genres': ['ambient', 'chill', 'classical', 'study', 'sleep'],
    },
    'lonely': {
        'keywords': ['lonely', 'alone', 'solitude', 'missing you', 'empty'],
        'audio_features': {'max_valence': 0.5, 'max_energy': 0.5},
        'genres': ['indie', 'acoustic', 'sad', 'singer-songwriter'],
    },
    'romantic': {
        'keywords': ['love', 'romance', 'romantic', 'sweet', 'affection'],
        'audio_features': {'min_valence': 0.5, 'target_energy': 0.5},
        'genres': ['romance', 'r-n-b', 'soul', 'pop'],
    },
    'nostalgic': {
        'keywords': ['nostalgic', 'retro', 'throwback', 'memories', 'classic'],
        'audio_features': {'target_valence': 0.5},
        'genres': ['oldies', '80s', '90s', 'retro', 'classic'],
    },
    'mixed': {
        'keywords': ['diverse', 'variety', 'mix', 'playlist', 'popular'],
        'audio_features': {},
        'genres': ['pop', 'indie', 'hip-hop', 'rock'],
    },
}


class SpotifyService:
    def __init__(self):
        self.client_id = settings.SPOTIFY_CLIENT_ID
        self.client_secret = settings.SPOTIFY_CLIENT_SECRET
        self.redirect_uri = settings.SPOTIFY_REDIRECT_URI

    def get_auth_url(self, state=None):
        """Generate Spotify OAuth URL"""
        params = {
            'client_id': self.client_id,
            'response_type': 'code',
            'redirect_uri': self.redirect_uri,
            'scope': settings.SPOTIFY_SCOPE,
        }
        if state:
            params['state'] = state
        query = '&'.join([f"{k}={v}" for k, v in params.items()])
        return f"{SPOTIFY_AUTH_URL}?{query}"

    def exchange_code(self, code):
        """Exchange auth code for tokens"""
        auth = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()
        response = requests.post(SPOTIFY_TOKEN_URL, headers={
            'Authorization': f'Basic {auth}',
            'Content-Type': 'application/x-www-form-urlencoded',
        }, data={
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': self.redirect_uri,
        })
        return response.json()

    def refresh_token(self, refresh_token):
        """Refresh an access token"""
        auth = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()
        response = requests.post(SPOTIFY_TOKEN_URL, headers={
            'Authorization': f'Basic {auth}',
            'Content-Type': 'application/x-www-form-urlencoded',
        }, data={
            'grant_type': 'refresh_token',
            'refresh_token': refresh_token,
        })
        return response.json()

    def get_client_token(self):
        """Get app-level token (no user auth required)"""
        auth = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()
        response = requests.post(SPOTIFY_TOKEN_URL, headers={
            'Authorization': f'Basic {auth}',
            'Content-Type': 'application/x-www-form-urlencoded',
        }, data={'grant_type': 'client_credentials'})
        return response.json().get('access_token')

    def ensure_valid_token(self, user):
        """Ensure user's Spotify token is valid, refresh if needed"""
        if not user.is_spotify_connected:
            return None
        
        if user.spotify_token_expires and user.spotify_token_expires <= timezone.now():
            token_data = self.refresh_token(user.spotify_refresh_token)
            user.spotify_access_token = token_data.get('access_token')
            if 'refresh_token' in token_data:
                user.spotify_refresh_token = token_data['refresh_token']
            user.spotify_token_expires = timezone.now() + timedelta(seconds=token_data.get('expires_in', 3600))
            user.save()
        
        return user.spotify_access_token

    def search_tracks(self, query, token, limit=10):
        """Search for tracks"""
        response = requests.get(f"{SPOTIFY_API_BASE}/search", headers={
            'Authorization': f'Bearer {token}'
        }, params={'q': query, 'type': 'track', 'limit': limit})
        
        if response.status_code == 200:
            tracks = response.json().get('tracks', {}).get('items', [])
            return self._format_tracks(tracks)
        return []

    def get_recommendations(self, emotion, user=None, preferred_artists=None, limit=20):
        """Get track recommendations based on emotion"""
        token = self.get_client_token()
        if not token:
            return []
        
        emotion_params = EMOTION_SEARCH_PARAMS.get(emotion, EMOTION_SEARCH_PARAMS['mixed'])
        
        # Build search query
        keyword = emotion_params['keywords'][0]
        genre = emotion_params['genres'][0] if emotion_params['genres'] else 'pop'
        
        all_tracks = []
        
        # If user has preferred artists, include their tracks
        if preferred_artists and user:
            for artist in preferred_artists[:3]:
                tracks = self.search_tracks(f"artist:{artist} {keyword}", token, limit=5)
                all_tracks.extend(tracks)
        
        # Search by emotion keywords
        for kw in emotion_params['keywords'][:3]:
            tracks = self.search_tracks(f"genre:{genre} {kw}", token, limit=8)
            all_tracks.extend(tracks)
        
        # Deduplicate by track ID
        seen = set()
        unique_tracks = []
        for t in all_tracks:
            if t['id'] not in seen:
                seen.add(t['id'])
                unique_tracks.append(t)
        
        return unique_tracks[:limit]

    def get_user_profile(self, token):
        """Get Spotify user profile"""
        response = requests.get(f"{SPOTIFY_API_BASE}/me", headers={
            'Authorization': f'Bearer {token}'
        })
        if response.status_code == 200:
            return response.json()
        return None

    def search_artists(self, query, token, limit=5):
        """Search for artists"""
        response = requests.get(f"{SPOTIFY_API_BASE}/search", headers={
            'Authorization': f'Bearer {token}'
        }, params={'q': query, 'type': 'artist', 'limit': limit})
        
        if response.status_code == 200:
            artists = response.json().get('artists', {}).get('items', [])
            return [{
                'id': a['id'],
                'name': a['name'],
                'image': a['images'][0]['url'] if a.get('images') else None,
                'genres': a.get('genres', []),
                'popularity': a.get('popularity', 0),
            } for a in artists]
        return []

    def _format_tracks(self, tracks):
        """Format Spotify tracks into standardized format"""
        formatted = []
        for track in tracks:
            if not track:
                continue
            album = track.get('album', {})
            artists = track.get('artists', [])
            formatted.append({
                'id': track['id'],
                'name': track['name'],
                'artist': ', '.join([a['name'] for a in artists]),
                'album': album.get('name', ''),
                'image': album.get('images', [{}])[0].get('url', '') if album.get('images') else '',
                'preview_url': track.get('preview_url'),
                'duration_ms': track.get('duration_ms', 0),
                'spotify_url': track.get('external_urls', {}).get('spotify', ''),
                'uri': track.get('uri', ''),
            })
        return formatted


spotify_service = SpotifyService()
