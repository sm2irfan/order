import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:order_management/screens/login_screen.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  // Get the current logged in user
  User? get currentUser => Supabase.instance.client.auth.currentUser;

  // Check if user is logged in
  bool get isAuthenticated => currentUser != null;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  // Display logout confirmation dialog
  Future<bool> showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  // Handle the complete logout flow with navigation
  Future<void> handleLogout(BuildContext context) async {
    bool shouldLogout = await showLogoutConfirmation(context);

    if (shouldLogout) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await signOut();

        if (context.mounted) {
          // Pop the loading dialog
          Navigator.of(context).pop();

          // Navigate to login screen and remove all previous routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        // Handle any logout errors
        if (context.mounted) {
          // Pop the loading dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: ${e.toString()}')),
          );
        }
      }
    }
  }
}
