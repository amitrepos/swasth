import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'select_profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    final creds = await _storage.getSavedCredentials();

    // No saved credentials → show login screen
    if (creds == null) {
      _goToLogin();
      return;
    }

    // Try online login first (fast timeout)
    final reachable = await ConnectivityService().isServerReachable();

    if (reachable) {
      try {
        final resp = await ApiService().login(creds.email, creds.password);
        final token = resp['access_token'] as String?;
        if (token != null) {
          await _storage.saveToken(token);
          await _storage.saveLastLoginTimestamp();
          try {
            final userData = await ApiService().getCurrentUser(token);
            await _storage.saveUserData(userData);
          } catch (_) {}
          // Sync any pending offline readings in background
          SyncService().syncPendingReadings();
          _goToProfiles();
          return;
        }
      } catch (_) {
        // Online login failed (wrong password changed on another device, etc.)
        // Fall through to offline check
      }
    }

    // Offline path — check if session is fresh enough (within 7 days)
    final lastLogin = await _storage.getLastLoginTimestamp();
    if (lastLogin != null) {
      final daysSince = DateTime.now().difference(lastLogin).inDays;
      if (daysSince <= 7) {
        _goToProfiles();
        return;
      }
    }

    // Session too old or no previous login — must log in online
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToProfiles() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Swasth',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
