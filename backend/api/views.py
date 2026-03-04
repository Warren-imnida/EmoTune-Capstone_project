"""
EmoTune Main API Views
Handles emotion analysis, recommendations, Spotify auth
"""
import random
import json
from django.conf import settings
from django.http import JsonResponse
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import get_user_model
from django.db.models import Count, Avg
from datetime import timedelta

from .spotify_service import spotify_service
from ml.emotion_classifier import get_classifier, get_ai_response, get_feel_better_message
from users.models import PromptHistory, UserPreference, FavoriteTrack, ListeningSession
from users.serializers import PromptHistorySerializer

User = get_user_model()


@api_view(['POST'])
def analyze_emotion(request):
    """
    Main endpoint: Analyze user's emotion from text prompt
    and return AI response + playlist recommendations
    """
    text = request.data.get('text', '').strip()
    if not text:
        return Response({'error': 'Text is required'}, status=status.HTTP_400_BAD_REQUEST)

    # Run BERT emotion classification
    classifier = get_classifier()
    result = classifier.predict(text)
    emotion = result['emotion']
    confidence = result['confidence']
    all_scores = result['all_scores']

    # Get AI response message
    ai_response = get_ai_response(emotion)

    # Get adaptive recommendations (check user preferences first)
    tracks = []
    user = request.user if request.user.is_authenticated else None
    
    if user:
        # Check if user has strong preferences for this emotion
        top_prefs = UserPreference.objects.filter(
            user=user,
            emotion=emotion,
            play_count__gte=3  # Played 3+ times = strong preference
        ).order_by('-play_count')[:5]

        if top_prefs.exists():
            # Include preferred tracks
            for pref in top_prefs:
                tracks.append({
                    'id': pref.spotify_track_id,
                    'name': pref.track_name,
                    'artist': pref.artist_name,
                    'album': '',
                    'image': '',
                    'preview_url': None,
                    'duration_ms': 0,
                    'is_preferred': True,
                })

    # Get Spotify recommendations
    preferred_artists = user.preferred_artists if user else []
    spotify_tracks = spotify_service.get_recommendations(
        emotion, user=user, preferred_artists=preferred_artists
    )
    
    # Merge: preferred tracks first, then Spotify tracks
    seen_ids = {t['id'] for t in tracks}
    for t in spotify_tracks:
        if t['id'] not in seen_ids:
            tracks.append(t)
            seen_ids.add(t['id'])

    # Save prompt history
    if user:
        history = PromptHistory.objects.create(
            user=user,
            prompt_text=text,
            detected_emotion=emotion,
            emotion_confidence=confidence,
            emotion_scores=all_scores,
            ai_response=ai_response,
            playlist_data=tracks[:20],
        )
        history_id = history.id
    else:
        history_id = None

    return Response({
        'emotion': emotion,
        'confidence': round(confidence * 100, 1),
        'all_scores': {k: round(v * 100, 1) for k, v in all_scores.items()},
        'ai_response': ai_response,
        'tracks': tracks[:20],
        'history_id': history_id,
    })


@api_view(['POST'])
def check_feel_better(request):
    """Called when user has been listening for a long time"""
    history_id = request.data.get('history_id')
    listen_duration = request.data.get('duration', 0)
    
    message = get_feel_better_message()
    
    # Get an uplift song
    uplift_tracks = spotify_service.get_recommendations('happy', limit=5)
    
    if history_id and request.user.is_authenticated:
        try:
            history = PromptHistory.objects.get(id=history_id, user=request.user)
            history.session_duration = listen_duration
            history.save()
        except PromptHistory.DoesNotExist:
            pass
    
    return Response({
        'message': message,
        'uplift_tracks': uplift_tracks[:3],
    })


@api_view(['POST'])
def feel_better_response(request):
    """User responds to 'Feel better?' prompt"""
    history_id = request.data.get('history_id')
    response_val = request.data.get('felt_better', True)
    
    if history_id and request.user.is_authenticated:
        PromptHistory.objects.filter(id=history_id, user=request.user).update(
            felt_better_response=response_val
        )
    return Response({'status': 'ok'})


# Spotify Auth
@api_view(['GET'])
@permission_classes([AllowAny])
def spotify_auth_url(request):
    """Get Spotify OAuth URL"""
    user_id = request.query_params.get('user_id', '')
    url = spotify_service.get_auth_url(state=str(user_id))
    return Response({'auth_url': url})


@api_view(['GET'])
@permission_classes([AllowAny])
def spotify_callback(request):
    """Handle Spotify OAuth callback"""
    code = request.query_params.get('code')
    state = request.query_params.get('state')  # user_id
    
    if not code:
        return Response({'error': 'No code provided'}, status=400)
    
    token_data = spotify_service.exchange_code(code)
    
    if 'access_token' not in token_data:
        return Response({'error': 'Token exchange failed'}, status=400)
    
    access_token = token_data['access_token']
    refresh_token = token_data.get('refresh_token')
    expires_in = token_data.get('expires_in', 3600)
    
    # Get Spotify user info
    spotify_profile = spotify_service.get_user_profile(access_token)
    
    # Update user if state (user_id) provided
    if state:
        try:
            user = User.objects.get(id=int(state))
            user.spotify_access_token = access_token
            user.spotify_refresh_token = refresh_token
            user.spotify_token_expires = timezone.now() + timedelta(seconds=expires_in)
            user.is_spotify_connected = True
            if spotify_profile:
                user.spotify_id = spotify_profile.get('id')
            user.save()
        except (User.DoesNotExist, ValueError):
            pass
    
    return Response({
        'access_token': access_token,
        'spotify_profile': spotify_profile,
        'message': 'Spotify connected successfully!'
    })


@api_view(['GET'])
def search_artists(request):
    """Search artists for preference selection"""
    query = request.query_params.get('q', '')
    if not query:
        return Response([])
    
    token = spotify_service.get_client_token()
    artists = spotify_service.search_artists(query, token)
    return Response(artists)


@api_view(['GET'])
def search_tracks(request):
    """Search tracks"""
    query = request.query_params.get('q', '')
    if not query:
        return Response([])
    
    token = spotify_service.get_client_token()
    tracks = spotify_service.search_tracks(query, token, limit=20)
    return Response(tracks)


# Admin Views
@api_view(['GET'])
@permission_classes([IsAdminUser])
def admin_dashboard(request):
    """Admin dashboard stats"""
    total_users = User.objects.filter(is_staff=False).count()
    
    # Monthly stats for last 6 months
    from django.db.models.functions import TruncMonth
    monthly_playlists = (
        PromptHistory.objects
        .annotate(month=TruncMonth('created_at'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )
    
    # Mood distribution
    mood_distribution = (
        PromptHistory.objects
        .values('detected_emotion')
        .annotate(count=Count('id'))
        .order_by('-count')
    )
    
    return Response({
        'total_users': total_users,
        'monthly_playlists': list(monthly_playlists),
        'mood_distribution': list(mood_distribution),
    })


@api_view(['GET'])
@permission_classes([IsAdminUser])
def admin_users(request):
    """Admin: list all users"""
    query = request.query_params.get('q', '')
    users = User.objects.filter(is_staff=False)
    if query:
        users = users.filter(username__icontains=query) | users.filter(email__icontains=query)
    
    data = [{
        'id': u.id,
        'username': u.username,
        'email': u.email,
        'is_spotify_connected': u.is_spotify_connected,
        'created_at': u.created_at,
        'prompt_count': u.prompt_history.count(),
    } for u in users]
    
    return Response(data)


@api_view(['DELETE'])
@permission_classes([IsAdminUser])
def admin_delete_user(request, user_id):
    """Admin: delete a user"""
    try:
        user = User.objects.get(id=user_id, is_staff=False)
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=404)


from django.shortcuts import render

def admin_panel(request):
    """Serve the Admin Dashboard HTML interface"""
    return render(request, "admin_dashboard.html")

