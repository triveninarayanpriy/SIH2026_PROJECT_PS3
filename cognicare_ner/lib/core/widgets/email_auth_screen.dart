import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'big_button.dart';

/// Large-text email/password sign-in + register screen for caregiver & doctor.
///
/// On success it does nothing itself — the enclosing role gate listens to
/// [AuthService.authStateChanges] and rebuilds to the next screen.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _email.text.trim();
    final String password = _password.text;
    if (email.isEmpty || password.length < 6) {
      setState(() => _error =
          'Enter an email and a password of at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await _auth.registerCaregiver(email, password);
      } else {
        await _auth.signInWithEmail(email, password);
      }
      // The role gate's auth stream will rebuild to the next screen.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendly(e));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'That email is already registered — try signing in.';
      case 'weak-password':
        return 'Please choose a stronger password (6+ characters).';
      case 'network-request-failed':
        return 'No internet connection. Please try again when online.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase yet.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.subtitle != null) ...[
              Text(widget.subtitle!, style: AppText.body()),
              const SizedBox(height: 24),
            ],
            _field(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _password,
              label: 'Password',
              obscure: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: AppText.body(color: AppColors.gentleWarning)),
            ],
            const SizedBox(height: 28),
            if (_busy)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else
              BigButton(
                label: _isRegister ? 'Create account' : 'Sign in',
                icon: _isRegister ? Icons.person_add_rounded : Icons.login_rounded,
                onTap: _submit,
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _isRegister = !_isRegister;
                        _error = null;
                      }),
              child: Text(
                _isRegister
                    ? 'Have an account? Sign in'
                    : 'New here? Create an account',
                style: AppText.body(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: AppText.body(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
      ),
    );
  }
}
