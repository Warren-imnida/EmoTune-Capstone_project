import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/emotune_logo.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.accent),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 16),
              const EmoTuneLogo(size: 100),
              const SizedBox(height: 32),
              if (auth.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
                ),
              _label('Username:'),
              const SizedBox(height: 6),
              _field(_emailCtrl, 'Enter username', false),
              const SizedBox(height: 16),
              _label('Password:'),
              const SizedBox(height: 6),
              _field(_passCtrl, 'Enter password', true),
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
  );

  Widget _field(TextEditingController ctrl, String hint, bool isPassword) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword && _obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}

// =============== REGISTER SCREEN ===============

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.accent),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 8),
              const EmoTuneLogo(size: 90),
              const SizedBox(height: 24),
              if (auth.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
                ),
              _buildField('Username', _usernameCtrl, false),
              const SizedBox(height: 12),
              _buildField('Email', _emailCtrl, false),
              const SizedBox(height: 12),
              _buildField('Password', _passCtrl, true),
              const SizedBox(height: 12),
              _buildField('Confirm password', _confirmCtrl, true),
              const SizedBox(height: 28),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool isPass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: isPass,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
      ],
    );
  }

  Future<void> _register() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _usernameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
