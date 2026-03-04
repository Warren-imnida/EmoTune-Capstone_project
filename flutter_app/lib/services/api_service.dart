import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';
  
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth
  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'confirm_password': password,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final headers = await authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/users/profile/'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final headers = await authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/users/profile/'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldPass, String newPass) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/users/change-password/'),
      headers: headers,
      body: jsonEncode({
        'old_password': oldPass,
        'new_password': newPass,
        'confirm_new_password': newPass,
      }),
    );
    return jsonDecode(response.body);
  }

  // Emotion analysis
  static Future<Map<String, dynamic>> analyzeEmotion(String text) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/analyze/'),
      headers: headers,
      body: jsonEncode({'text': text}),
    );
    return jsonDecode(response.body);
  }

  // Feel better
  static Future<Map<String, dynamic>> checkFeelBetter(
      int historyId, int duration) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/feel-better/'),
      headers: headers,
      body: jsonEncode({'history_id': historyId, 'duration': duration}),
    );
    return jsonDecode(response.body);
  }

  // Favorites
  static Future<List<dynamic>> getFavorites() async {
    final headers = await authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/users/favorites/'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<void> addFavorite(Map<String, dynamic> track) async {
    final headers = await authHeaders();
    await http.post(
      Uri.parse('$baseUrl/users/favorites/'),
      headers: headers,
      body: jsonEncode(track),
    );
  }

  static Future<void> removeFavorite(String trackId) async {
    final headers = await authHeaders();
    await http.delete(
      Uri.parse('$baseUrl/users/favorites/$trackId/'),
      headers: headers,
    );
  }

  // History
  static Future<List<dynamic>> getHistory() async {
    final headers = await authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/users/history/'), headers: headers);
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getEmotionStats() async {
    final headers = await authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/users/emotion-stats/'), headers: headers);
    return jsonDecode(response.body);
  }

  // Artists
  static Future<List<dynamic>> searchArtists(String query) async {
    final headers = await authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/spotify/search-artists/?q=$query'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<void> updateArtists(List<String> artists) async {
    final headers = await authHeaders();
    await http.put(
      Uri.parse('$baseUrl/users/update-artists/'),
      headers: headers,
      body: jsonEncode({'preferred_artists': artists}),
    );
  }

  // Listen time tracking
  static Future<void> updateListenTime(String trackId, String emotion,
      int duration, String trackName, String artistName) async {
    final headers = await authHeaders();
    await http.post(
      Uri.parse('$baseUrl/users/listen-time/'),
      headers: headers,
      body: jsonEncode({
        'track_id': trackId,
        'emotion': emotion,
        'duration': duration,
        'track_name': trackName,
        'artist_name': artistName,
      }),
    );
  }

  // Spotify auth
  static Future<String> getSpotifyAuthUrl(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/spotify/auth-url/?user_id=$userId'),
    );
    final data = jsonDecode(response.body);
    return data['auth_url'];
  }
}
