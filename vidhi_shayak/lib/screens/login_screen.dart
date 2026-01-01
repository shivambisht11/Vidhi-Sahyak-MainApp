import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../core/app_theme.dart';
import '../widgets/custom_button.dart';
import '../l10n/app_localizations.dart';
import 'profile_setup_screen.dart'; // Import the new setup screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  final AuthService _authService = AuthService();

  Future<void> signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() => _loading = true);

      // 1. Perform Google Sign In
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // 2. Check if the user profile exists in Firestore
        final bool userExists = await _authService.checkUserExists(user.uid);

        if (!mounted) return;

        if (userExists) {
          // 3a. User exists -> Return user to redirect to Home
          Navigator.pop(context, user);
        } else {
          // 3b. User does NOT exist -> Go to Profile Setup Screen
          final resultUser = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileSetupScreen(user: user)),
          );

          // If they completed setup, they return the user object
          if (resultUser != null && mounted) {
            Navigator.pop(context, resultUser);
          } else {
            // They backed out of setup
            setState(() => _loading = false);
          }
        }
      } else {
        // User cancelled login
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.loginFailed}$e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor, Colors.white],
            stops: [0.0, 0.7],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo or Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.loginWelcome,
                      style: AppTheme.textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.loginSubtitle,
                      style: AppTheme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Google Sign In Button
                    CustomButton(
                      text: l10n.loginGoogle,
                      icon: Icons.login,
                      onPressed: signInWithGoogle,
                      isLoading: _loading,
                    ),

                    const SizedBox(height: 24),
                    Text(
                      l10n.loginTerms,
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
