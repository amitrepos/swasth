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

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Single input controller for both email and phone
  final _inputController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
  // State management for different steps
  String _loginStep = 'input'; // 'input', 'password', 'loading'
  bool _accountExists = false;
  String _loginMethod = ''; // 'email_password', 'phone_otp'
  bool _isNewUser = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final creds = await StorageService().getSavedCredentials();
    if (creds != null && mounted) {
      setState(() {
        _inputController.text = creds.email;
        _passwordController.text = creds.password;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Detect if input is email or phone
  bool _isEmail(String input) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input.trim());
  }

  bool _isPhone(String input) {
    return RegExp(r'^\+?\d{10,15}$').hasMatch(input.trim());
  }

  Future<void> _checkAccountAndProceed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    final input = _inputController.text.trim();

    try {
      // Check if input is valid email or phone
      if (!_isEmail(input) && !_isPhone(input)) {
        if (mounted) {
          await ErrorMapper.showSnack(
            context,
            ValidationException('Please enter a valid email or phone number'),
            backgroundColor: AppColors.statusCritical,
          );
        }
        return;
      }

      // Check if account exists
      final result = await _apiService.checkAccountExists(
        email: _isEmail(input) ? input : null,
        phoneNumber: _isPhone(input) ? input : null,
      );

      final exists = result['exists'] as bool;
      final loginMethod = result['login_method'] as String?;

      if (exists) {
        // Account exists - proceed with appropriate login method
        setState(() {
          _accountExists = true;
          _loginMethod = loginMethod ?? '';
          _isNewUser = false;
        });

        if (_loginMethod == 'email_password') {
          // Show password field for email login
          setState(() => _loginStep = 'password');
        } else if (_loginMethod == 'phone_otp') {
          // Send OTP for phone login
          await _sendPhoneOTP(input);
        }
      } else {
        // Account doesn't exist - show create account option
        setState(() {
          _accountExists = false;
          _isNewUser = true;
        });

        if (mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.phoneLoginNoAccountTitle),
              content: Text(
                _isEmail(input)
                    ? 'No account found with this email. Would you like to create a new account?'
                    : l10n.phoneLoginNoAccountMessage,
              ),
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
            // Navigate to registration with pre-filled phone if it's a phone number
            // For email, user will need to enter it manually in registration
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RegistrationScreen(
                  prefillPhone: _isPhone(input) ? input : null,
                ),
              ),
            );
            
            // If it's an email, we should prefill it in the registration form
            // We'll need to handle this differently - for now, just navigate
            if (_isEmail(input) && mounted) {
              // Show a message that they need to complete registration
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please complete your registration with email: $input'),
                  backgroundColor: AppColors.statusNormal,
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

  Future<void> _loginWithEmailPassword(String email) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
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

          // Prompt non-doctor users to verify email if not yet verified
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _backToInput() {
    setState(() {
      _loginStep = 'input';
      _accountExists = false;
      _loginMethod = '';
      _isNewUser = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginTitle),
        leading: _loginStep == 'password'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToInput,
              )
            : null,
      ),
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

              // Input field for email or phone
              TextFormField(
                key: const Key('unified_login_input'),
                controller: _inputController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.emailOrPhoneLabel,
                  prefixIcon: const Icon(Icons.person),
                  hintText: 'Enter email or phone (e.g., +911234567890)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email or phone number';
                  }
                  if (!_isEmail(value) && !_isPhone(value)) {
                    return 'Please enter a valid email or phone number';
                  }
                  return null;
                },
                enabled: _loginStep == 'input',
              ),
              const SizedBox(height: 4),
              Text(
                'For phone numbers, please include country code with + symbol (e.g., +91 for India)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),

              // Password field (shown only when account exists and uses email/password)
              if (_loginStep == 'password') ...[
                TextFormField(
                  key: const Key('unified_login_password'),
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
                  autofocus: true,
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
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),

              // Continue/Login Button
              ElevatedButton(
                key: const Key('unified_login_continue_button'),
                onPressed: _isLoading
                    ? null
                    : _loginStep == 'password'
                        ? () => _loginWithEmailPassword(_inputController.text.trim())
                        : _checkAccountAndProceed,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _loginStep == 'password'
                            ? l10n.loginButton
                            : l10n.continueButton,
                      ),
              ),
              const SizedBox(height: 16),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.noAccount),
                  TextButton(
                    key: const Key('unified_login_register_link'),
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
                key: const Key('unified_login_doctor_register_link'),
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
