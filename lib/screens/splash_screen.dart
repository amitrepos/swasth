import 'dart:async';

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'unified_login_screen.dart';
import 'select_profile_screen.dart';
import 'doctor/doctor_triage_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = StorageService();
  String _loadingMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    setState(() => _loadingMessage = 'Checking connection...');
    
    // Add timeout to prevent indefinite loading
    try {
      await Future.any([
        _performAutoLogin(),
        Future.delayed(const Duration(seconds: 15), () => throw Exception('Login timeout')),
      ]);
    } catch (e) {
      debugPrint('Auto-login error: $e');
      if (mounted) {
        // On timeout or error, go to login screen
        _goToLogin();
      }
    }
  }

  Future<void> _performAutoLogin() async {
    final token = await _storage.getToken();
    final reachable = await ConnectivityService().isServerReachable();

    // SCENARIO 1: OFFLINE
    if (!reachable) {
      setState(() => _loadingMessage = 'Working offline...');
      final lastLogin = await _storage.getLastLoginTimestamp();
      if (lastLogin != null) {
        final daysSince = DateTime.now().difference(lastLogin).inDays;
        if (daysSince <= 7) {
          _goToProfiles();
          return;
        }
      }
      _goToLogin(); // Offline but session expired
      return;
    }

    // SCENARIO 2: ONLINE - TOKEN REUSE
    if (token != null) {
      try {
        setState(() => _loadingMessage = 'Loading your profile...');
        final userData = await ApiService().getCurrentUser(token);
        await _storage.saveUserData(userData);
        // Note: We intentionally do NOT call saveLastLoginTimestamp here
        // to maintain the 7-day credential requirement.

        SyncService().syncPendingReadings();
        _goToProfiles();
        return;
      } catch (_) {
        await _storage.deleteToken(); // Clear invalid token
      }
    }

    // SCENARIO 3: ONLINE - CREDENTIAL FALLBACK
    setState(() => _loadingMessage = 'Checking saved credentials...');
    final creds = await _storage.getSavedCredentials();
    if (creds != null) {
      try {
        setState(() => _loadingMessage = 'Signing in...');
        final resp = await ApiService().login(creds.email, creds.password);
        final newToken = resp['access_token'] as String?;
        if (newToken != null) {
          await _storage.saveToken(newToken);
          await _storage
              .saveLastLoginTimestamp(); // Extend grace period only on re-auth
          try {
            final userData = await ApiService().getCurrentUser(newToken);
            await _storage.saveUserData(userData);
          } catch (_) {}

          SyncService().syncPendingReadings();
          _goToProfiles();
          return;
        }
      } catch (_) {
        // Credential login failed (e.g. password changed)
      }
    }

    // SCENARIO 4: NO SESSION (or all above failed)
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
    );
  }

  Future<void> _goToProfiles() async {
    if (!mounted) return;
    // Check if user is a doctor — route to triage board instead
    final userData = await _storage.getUserData();
    final role = userData?['role'] as String?;
    if (role == 'doctor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorTriageScreen()),
      );
      return;
    }
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
            Icon(Icons.health_and_safety, size: 80, color: AppColors.primary),
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
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
