import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  String _loadingMessage = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _logoLoaded = false;
  final Image _logoImage = Image.asset('assets/logo.png', width: 120, height: 120);

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for logo
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Preload the logo image after dependencies are ready
    if (!_logoLoaded) {
      precacheImage(_logoImage.image, context).then((_) {
        if (mounted) {
          setState(() => _logoLoaded = true);
        }
      });
    }
    
    // Start auto-login after first dependency change
    final l10n = AppLocalizations.of(context)!;
    if (_loadingMessage.isEmpty) {
      _loadingMessage = l10n.splashInitializing;
      _attemptAutoLogin();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _attemptAutoLogin() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loadingMessage = l10n.splashCheckingConnection);
    
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
    final l10n = AppLocalizations.of(context)!;
    final token = await _storage.getToken();
    final reachable = await ConnectivityService().isServerReachable();

    // SCENARIO 1: OFFLINE
    if (!reachable) {
      setState(() => _loadingMessage = l10n.splashWorkingOffline);
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
        setState(() => _loadingMessage = l10n.splashLoadingProfile);
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
    setState(() => _loadingMessage = l10n.splashCheckingCredentials);
    final creds = await _storage.getSavedCredentials();
    if (creds != null) {
      try {
        setState(() => _loadingMessage = l10n.splashSigningIn);
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return AnimatedOpacity(
                  opacity: _logoLoaded ? _opacityAnimation.value : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _logoImage,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _logoLoaded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  Text(
                    l10n.splashAppName,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.splashTagline,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              _loadingMessage.isEmpty ? l10n.splashInitializing : _loadingMessage,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
