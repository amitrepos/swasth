import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/error_mapper.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_form_scroll_body.dart';
import 'select_profile_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final token = await StorageService().getToken();
      if (token != null) {
        await _apiService.sendEmailVerification(token);
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.emailVerificationOtpSent),
              backgroundColor: AppColors.statusNormal,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.emailVerificationFailed),
            backgroundColor: AppColors.statusCritical,
          ),
        );
      }
    }
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendCountdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) timer.cancel();
    });
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');

      await _apiService.verifyEmailOTP(token, _otpController.text.trim());

      // Update cached user data
      final userData = await StorageService().getUserData();
      if (userData != null) {
        userData['email_verified'] = true;
        await StorageService().saveUserData(userData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.emailVerifiedSuccess),
            backgroundColor: AppColors.statusNormal,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SelectProfileScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        await ErrorMapper.showSnack(
          context,
          e,
          backgroundColor: AppColors.statusCritical,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() => _isLoading = true);

    try {
      final token = await StorageService().getToken();
      if (token != null) {
        await _apiService.sendEmailVerification(token);

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.emailVerificationOtpSent),
              backgroundColor: AppColors.statusNormal,
            ),
          );
          _startResendTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        await ErrorMapper.showSnack(
          context,
          e,
          backgroundColor: AppColors.statusCritical,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.emailVerificationTitle)),
      body: AuthFormScrollBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              Icon(
                Icons.email_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.emailVerificationTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.emailVerificationSubtitle(widget.email),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // OTP Field
              TextFormField(
                key: const Key('email_verify_otp_field'),
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: l10n.otpLabel,
                  border: const OutlineInputBorder(),
                  hintText: '000000',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.otpValidationEmpty;
                  }
                  if (value.length != 6) {
                    return l10n.otpValidationLength;
                  }
                  if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                    return l10n.otpValidationDigitsOnly;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Verify Button
              ElevatedButton(
                key: const Key('email_verify_button'),
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        l10n.verifyEmailButton,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // Resend OTP
              Row(
                key: const Key('email_verify_resend'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.didNotReceiveOtp),
                  if (_resendCountdown > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      l10n.resendIn(_resendCountdown),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: _isLoading ? null : _resendOTP,
                      child: Text(l10n.resendOtp),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Skip for now
              TextButton(
                key: const Key('email_verify_skip'),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SelectProfileScreen(),
                    ),
                  );
                },
                child: Text(l10n.skipForNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
