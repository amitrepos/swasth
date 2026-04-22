import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/error_mapper.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_form_scroll_body.dart';
import 'select_profile_screen.dart';
import 'doctor/doctor_triage_screen.dart';
import 'registration_screen.dart';

class PhoneOTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneOTPVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<PhoneOTPVerificationScreen> createState() =>
      _PhoneOTPVerificationScreenState();
}

class _PhoneOTPVerificationScreenState extends State<PhoneOTPVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  int _resendCountdown = 60;
  bool _isNewUser = false;

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _nameController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final response = await _apiService.verifyPhoneOTP(
        phoneNumber: widget.phoneNumber,
        otp: _otpController.text.trim(),
        fullName: _isNewUser ? _nameController.text.trim() : null,
      );

      if (mounted) {
        final token = response['access_token'];
        _isNewUser = response['is_new_user'] as bool? ?? false;

        if (token != null) {
          await StorageService().saveToken(token);

          try {
            final userData = await _apiService.getCurrentUser(token);
            await StorageService().saveUserData(userData);
          } catch (_) {}
        }

        if (_isNewUser) {
          // New user - redirect to complete registration
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountCreatedSuccess),
              backgroundColor: AppColors.statusNormal,
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => RegistrationScreen(
                prefillPhone: widget.phoneNumber,
                isPhoneVerified: true,
              ),
            ),
            (route) => false,
          );
        } else {
          // Existing user - login successful
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.loginSuccessful),
              backgroundColor: AppColors.statusNormal,
            ),
          );

          final userData = await StorageService().getUserData();
          final role = userData?['role'] as String?;

          final destination = role == 'doctor'
              ? const DoctorTriageScreen()
              : const SelectProfileScreen();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => destination),
            (route) => false,
          );
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

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.sendPhoneOTP(widget.phoneNumber);

      if (mounted) {
        setState(() => _resendCountdown = 60);
        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.otpSentToPhoneSuccess),
            backgroundColor: AppColors.statusNormal,
          ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.verifyPhoneOTP)),
      body: AuthFormScrollBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              Icon(
                Icons.phone_android,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.verifyPhoneOTP,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.otpSentToPhone(widget.phoneNumber),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Name field (only for new users)
              if (_isNewUser) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.fullNameLabel,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.nameValidationEmpty;
                    }
                    if (value.trim().length < 2) {
                      return l10n.nameValidationTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // OTP input
              TextFormField(
                key: const Key('phone_otp_field'),
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: l10n.otpLabel,
                  prefixIcon: const Icon(Icons.lock),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.otpValidationEmpty;
                  }
                  if (value.length != 6) {
                    return l10n.otpValidationLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Verify Button
              ElevatedButton(
                key: const Key('phone_otp_verify_button'),
                onPressed: _isLoading ? null : _verifyOTP,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.verifyOTP),
              ),
              const SizedBox(height: 16),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.didntReceiveOTP),
                  if (_resendCountdown > 0)
                    Text(
                      ' ${l10n.resendIn(_resendCountdown)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    TextButton(
                      key: const Key('phone_otp_resend'),
                      onPressed: _isLoading ? null : _resendOTP,
                      child: Text(l10n.resendOTP),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
