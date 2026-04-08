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
    final token = await _storage.getToken();
    final reachable = await ConnectivityService().isServerReachable();

    // 1. Try to use existing token
    if (token != null) {
      if (reachable) {
        try {
          // Verify token is still valid
          final userData = await ApiService().getCurrentUser(token);
          await _storage.saveUserData(userData);
          await _storage.saveLastLoginTimestamp();
          
          SyncService().syncPendingReadings();
          _goToProfiles();
          return;
        } catch (_) {
          // Token expired or invalid, fall through to credential login
        }
      } else {
        // Offline session check
        final lastLogin = await _storage.getLastLoginTimestamp();
        if (lastLogin != null) {
          final daysSince = DateTime.now().difference(lastLogin).inDays;
          if (daysSince <= 7) {
            _goToProfiles();
            return;
          }
        }
      }
    }

    // 2. Try saved credentials fallback (if token was invalid or missing)
    final creds = await _storage.getSavedCredentials();
    if (creds != null && reachable) {
      try {
        final resp = await ApiService().login(creds.email, creds.password);
        final newToken = resp['access_token'] as String?;
        if (newToken != null) {
          await _storage.saveToken(newToken);
          await _storage.saveLastLoginTimestamp();
          try {
            final userData = await ApiService().getCurrentUser(newToken);
            await _storage.saveUserData(userData);
          } catch (_) {}
          
          SyncService().syncPendingReadings();
          _goToProfiles();
          return;
        }
      } catch (_) {
        // Credential login failed
      }
    }

    // 3. No active session or valid fallback credentials, show login screen
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
