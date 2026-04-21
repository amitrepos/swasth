import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/error_mapper.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_form_scroll_body.dart';
import 'doctor_registration_screen.dart';
import 'registration_screen.dart';
import 'select_profile_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';
import 'doctor/doctor_triage_screen.dart';
import 'phone_otp_verification_screen.dart';

class AmazonStyleLoginScreen extends StatefulWidget {
  const AmazonStyleLoginScreen({super.key});

  @override
  State<AmazonStyleLoginScreen> createState() => _AmazonStyleLoginScreenState();
}

class _AmazonStyleLoginScreenState extends State<AmazonStyleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Login mode: 'email' or 'phone'
  String _loginMode = 'email';

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final creds = await StorageService().getSavedCredentials();
    if (creds != null && mounted) {
      setState(() {
        _emailController.text = creds.email;
        _passwordController.text = creds.password;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _proceedWithLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      if (_loginMode == 'email') {
        // Check if it's an email or phone number
        final input = _emailController.text.trim();
        final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input);

        if (isEmail) {
          // Email flow: Check if account exists
          final result = await _apiService.checkAccountExists(email: input);
          final exists = result['exists'] as bool;

          if (exists) {
            // Account exists, proceed to password login
            await _loginWithEmail(input);
          } else {
            // Account doesn't exist, show error
            if (mounted) {
              await ErrorMapper.showSnack(
                context,
                ValidationException('No account found with this email. Please sign up first.'),
                backgroundColor: AppColors.statusCritical,
              );
            }
          }
        } else {
          // Phone number flow: Check if account exists
          final result = await _apiService.checkAccountExists(phoneNumber: input);
          final exists = result['exists'] as bool;

          if (exists) {
            // Account exists, send OTP for login
            await _sendPhoneOTP(input);
          } else {
            // Account doesn't exist, redirect to registration
            if (mounted) {
              final proceed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.phoneLoginNoAccountTitle),
                  content: Text(l10n.phoneLoginNoAccountMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.createAccount),
                    ),
                  ],
                ),
              );

              if (proceed == true && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RegistrationScreen(
                      prefillPhone: input,
                    ),
                  ),
                );
              }
            }
          }
        }
      } else {
        // Phone mode: Check if account exists
        final phoneNumber = _phoneController.text.trim();
        final result = await _apiService.checkAccountExists(phoneNumber: phoneNumber);
        final exists = result['exists'] as bool;

        if (exists) {
          // Account exists, send OTP for login
          await _sendPhoneOTP(phoneNumber);
        } else {
          // Account doesn't exist, redirect to registration
          if (mounted) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.phoneLoginNoAccountTitle),
                content: Text(l10n.phoneLoginNoAccountMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.createAccount),
                  ),
                ],
              ),
            );

            if (proceed == true && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RegistrationScreen(
                    prefillPhone: phoneNumber,
                  ),
                ),
              );
            }
          }
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

  Future<void> _loginWithEmail(String email) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final response = await _apiService.login(
        email,
        _passwordController.text,
      );

      if (mounted) {
        final token = response['access_token'];
        if (token != null) {
          await StorageService().saveToken(token);

          if (_rememberMe) {
            await StorageService().saveCredentials(
              email,
              _passwordController.text,
            );
          } else {
            await StorageService().clearCredentials();
          }

          try {
            final userData = await _apiService.getCurrentUser(token);
            await StorageService().saveUserData(userData);
          } catch (_) {}
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.loginSuccessful),
              backgroundColor: AppColors.statusNormal,
            ),
          );
        }

        if (mounted) {
          final userData = await StorageService().getUserData();
          final role = userData?['role'] as String?;

          if (userData?['email_verified'] != true && role != 'doctor') {
            final shouldVerify = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.verifyEmailDialogTitle),
                content: Text(l10n.verifyEmailDialogMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.verifyLater),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.verifyNow),
                  ),
                ],
              ),
            );

            if (mounted && shouldVerify == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EmailVerificationScreen(email: email),
                ),
              );
              return;
            }
          }

          if (mounted) {
            final destination = role == 'doctor'
                ? const DoctorTriageScreen()
                : const SelectProfileScreen();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => destination),
            );
          }
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
    }
  }

  Future<void> _sendPhoneOTP(String phoneNumber) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await _apiService.sendPhoneOTP(phoneNumber);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.otpSentSuccess),
            backgroundColor: AppColors.statusNormal,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhoneOTPVerificationScreen(
              phoneNumber: phoneNumber,
            ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: AuthFormScrollBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              Icon(
                Icons.health_and_safety,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Login mode toggle
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(l10n.loginModeEmail),
                      selected: _loginMode == 'email',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _loginMode = 'email');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(l10n.loginModePhone),
                      selected: _loginMode == 'phone',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _loginMode = 'phone');
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Email/Phone input based on mode
              if (_loginMode == 'email') ...[
                TextFormField(
                  key: const Key('login_email_or_phone'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.emailOrPhoneLabel,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.emailValidationEmpty;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password (only shown for email mode)
                TextFormField(
                  key: const Key('login_password'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordValidationEmpty;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),

                // Remember me checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    Text(
                      l10n.rememberMe,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),

                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(l10n.forgotPassword),
                  ),
                ),
              ] else ...[
                // Phone number input
                TextFormField(
                  key: const Key('login_phone'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.phoneNumberLabel,
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.phoneValidationEmpty;
                    }
                    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(value.trim())) {
                      return l10n.phoneValidationInvalid;
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),

              // Continue/Login Button
              ElevatedButton(
                key: const Key('login_continue_button'),
                onPressed: _isLoading ? null : _proceedWithLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.continueButton),
              ),
              const SizedBox(height: 16),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.noAccount),
                  TextButton(
                    key: const Key('login_register_link'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistrationScreen(),
                        ),
                      );
                    },
                    child: Text(l10n.register),
                  ),
                ],
              ),

              // Doctor registration link
              TextButton(
                key: const Key('login_doctor_register_link'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoctorRegistrationScreen(),
                    ),
                  );
                },
                child: Text(l10n.loginDoctorRegisterLink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
