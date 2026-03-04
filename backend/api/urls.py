from django.urls import path
from . import views

urlpatterns = [
    # Core
    path('analyze/', views.analyze_emotion, name='analyze_emotion'),
    path('feel-better/', views.check_feel_better, name='feel_better'),
    path('feel-better-response/', views.feel_better_response, name='feel_better_response'),
    
    # Spotify
    path('spotify/auth-url/', views.spotify_auth_url, name='spotify_auth_url'),
    path('spotify/callback/', views.spotify_callback, name='spotify_callback'),
    path('spotify/search-artists/', views.search_artists, name='search_artists'),
    path('spotify/search-tracks/', views.search_tracks, name='search_tracks'),
    
    # Admin
    path('admin/dashboard/', views.admin_dashboard, name='admin_dashboard'),
    path('admin/users/', views.admin_users, name='admin_users'),
    path('admin/users/<int:user_id>/', views.admin_delete_user, name='admin_delete_user'),
]
