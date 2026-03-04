import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<dynamic> _artists = [];
  List<dynamic> _searchResults = [];
  final _artistSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  void _loadArtists() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      setState(() {
        _artists = List.from(user['preferred_artists'] ?? []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Login'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/welcome');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.accent.withOpacity(0.2),
                    child: Text(
                      (user['username'] as String? ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user['username'] ?? '',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    user['email'] ?? '',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (user['is_spotify_connected'] == true
                              ? Colors.green
                              : Colors.grey)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: user['is_spotify_connected'] == true
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note,
                            size: 14,
                            color: user['is_spotify_connected'] == true
                                ? Colors.green
                                : Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          user['is_spotify_connected'] == true
                              ? 'Spotify Connected'
                              : 'Spotify Not Connected',
                          style: TextStyle(
                            color: user['is_spotify_connected'] == true
                                ? Colors.green
                                : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Theme toggle
            _sectionTitle('Appearance', isDark),
            const SizedBox(height: 12),
            _card(
              isDark,
              child: Row(
                children: [
                  Icon(
                    themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    themeProvider.isDark ? 'Dark Mode' : 'Light Mode',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  const Spacer(),
                  Switch(
                    value: themeProvider.isDark,
                    onChanged: (_) => themeProvider.toggleTheme(),
                    activeThumbColor: AppColors.accent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Preferred Artists
            _sectionTitle('Preferred Artists', isDark),
            const SizedBox(height: 8),
            Text('Artists we\'ll prioritize in recommendations',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12)),
            const SizedBox(height: 12),

            // Artist search
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _artistSearchCtrl,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search an artist...',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: _searchArtists,
                  ),
                ),
              ],
            ),

            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade200),
                ),
                child: Column(
                  children: _searchResults.take(5).map<Widget>((artist) {
                    final name = artist['name'] as String;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: artist['image'] != null
                            ? NetworkImage(artist['image'])
                            : null,
                        backgroundColor: AppColors.accent.withOpacity(0.2),
                        child: artist['image'] == null
                            ? Text(name[0],
                                style: const TextStyle(color: AppColors.accent))
                            : null,
                      ),
                      title: Text(name,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87)),
                      trailing: _artists.contains(name)
                          ? const Icon(Icons.check, color: AppColors.accent)
                          : IconButton(
                              icon: const Icon(Icons.add, color: AppColors.accent),
                              onPressed: () => _addArtist(name),
                            ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Current artists
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _artists.map<Widget>((a) {
                return Chip(
                  label: Text(a.toString()),
                  backgroundColor: AppColors.accent.withOpacity(0.15),
                  labelStyle: const TextStyle(color: AppColors.accent),
                  deleteIcon: const Icon(Icons.close,
                      size: 16, color: AppColors.accent),
                  onDeleted: () => _removeArtist(a.toString()),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Account settings
            _sectionTitle('Account', isDark),
            const SizedBox(height: 12),

            _card(
              isDark,
              child: Column(
                children: [
                  _settingsTile(
                    Icons.person_outline,
                    'Edit Profile',
                    () => _showEditProfile(context, user),
                    isDark,
                  ),
                  _divider(isDark),
                  _settingsTile(
                    Icons.lock_outline,
                    'Change Password',
                    () => _showChangePassword(context),
                    isDark,
                  ),
                  _divider(isDark),
                  _settingsTile(
                    Icons.music_note,
                    'Connect Spotify',
                    () => _connectSpotify(user['id'].toString()),
                    isDark,
                    trailing: user['is_spotify_connected'] == true
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 18)
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) => Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _card(bool isDark, {required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200),
        ),
        child: child,
      );

  Widget _divider(bool isDark) => Divider(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
        height: 1,
      );

  Widget _settingsTile(
      IconData icon, String title, VoidCallback onTap, bool isDark,
      {Widget? trailing}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.accent),
      title: Text(title,
          style:
              TextStyle(color: isDark ? Colors.white : Colors.black87)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _searchArtists(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await ApiService.searchArtists(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() => _searchResults = []);
    }
  }

  void _addArtist(String artist) {
    if (!_artists.contains(artist)) {
      setState(() => _artists.add(artist));
      ApiService.updateArtists(_artists.cast<String>());
    }
    _artistSearchCtrl.clear();
    setState(() => _searchResults = []);
  }

  void _removeArtist(String artist) {
    setState(() => _artists.remove(artist));
    ApiService.updateArtists(_artists.cast<String>());
  }

  void _showEditProfile(BuildContext ctx, Map<String, dynamic> user) {
    final usernameCtrl = TextEditingController(text: user['username']);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Edit Profile',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: usernameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context
                  .read<AuthProvider>()
                  .updateProfile({'username': usernameCtrl.text});
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext ctx) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Change Password',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Old Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.changePassword(oldCtrl.text, newCtrl.text);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

 Future<void> _connectSpotify(String userId) async {
    final url = await ApiService.getSpotifyAuthUrl(userId);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Spotify login')),
      );
    }
  }
}
