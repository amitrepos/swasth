import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/auth_form_scroll_body.dart';
import 'consent_screen.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _profileNameController = TextEditingController(text: "My Health");
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _otherConditionController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'A+';
  final List<String> _selectedConditions = [];

  // Medical condition values are API keys — do NOT translate
  final List<String> _medicalConditionsOptions = [
    'Diabetes T1',
    'Diabetes T2',
    'Hypertension',
    'Heart Disease',
    'None',
    'Other',
  ];

  bool _passwordHasMinLength = false;
  bool _passwordHasUppercase = false;
  bool _passwordHasLowercase = false;
  bool _passwordHasNumber = false;
  bool _passwordHasSpecialChar = false;
  bool _passwordsMatch = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _profileNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationsController.dispose();
    _otherConditionController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _passwordHasMinLength = password.length >= 8;
      _passwordHasUppercase = password.contains(RegExp(r'[A-Z]'));
      _passwordHasLowercase = password.contains(RegExp(r'[a-z]'));
      _passwordHasNumber = password.contains(RegExp(r'[0-9]'));
      _passwordHasSpecialChar = password.contains(
        RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
      );
      _passwordsMatch =
          confirmPassword.isNotEmpty && password == confirmPassword;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    if (_selectedConditions.contains('Other') &&
        _otherConditionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.specifyOtherCondition)));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'confirm_password': _confirmPasswordController.text,
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'profile_name': _profileNameController.text.trim(),
        'age': int.tryParse(_ageController.text),
        'gender': _selectedGender,
        'height': double.tryParse(_heightController.text),
        'weight': double.tryParse(_weightController.text),
        'blood_group': _selectedBloodGroup,
        'current_medications': _medicationsController.text.trim().isEmpty
            ? null
            : _medicationsController.text.trim(),
        'medical_conditions': _selectedConditions,
        'other_medical_condition': _selectedConditions.contains('Other')
            ? _otherConditionController.text.trim()
            : null,
      };

      // Navigate to consent screen — registration API is called after consent
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConsentScreen(
              onAccept:
                  ({
                    required String appVersion,
                    required String language,
                    required bool aiConsent,
                  }) async {
                    userData['consent_app_version'] = appVersion;
                    userData['consent_language'] = language;
                    userData['ai_consent'] = aiConsent;
                    await _apiService.register(userData);
                  },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.statusCritical,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: AuthFormScrollBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(l10n.accountDetailsSection),

              // Full Name
              TextFormField(
                key: const Key('reg_full_name'),
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: l10n.fullNameLabel,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                key: const Key('reg_email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.emailLabel,
                  prefixIcon: const Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.emailValidationEmpty;
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                    return l10n.emailValidationInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                key: const Key('reg_phone'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (value) {
                  final l10n = AppLocalizations.of(context)!;
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  final stripped = value.replaceAll(RegExp(r'[\s\-]'), '');
                  if (!RegExp(r'^\+?[0-9]+$').hasMatch(stripped)) {
                    return 'Phone number can only contain digits';
                  }
                  if (stripped.length < 10 || stripped.length > 15) {
                    return 'Phone number must be 10-15 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                key: const Key('reg_password'),
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  prefixIcon: const Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.passwordValidationEmpty;
                  }
                  if (!_passwordHasMinLength ||
                      !_passwordHasUppercase ||
                      !_passwordHasLowercase ||
                      !_passwordHasNumber ||
                      !_passwordHasSpecialChar) {
                    return 'Password does not meet requirements';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Password requirements
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.passwordRequirementsTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRequirementRow(
                      l10n.passwordReqLength,
                      _passwordHasMinLength,
                    ),
                    _buildRequirementRow(
                      l10n.passwordReqUppercase,
                      _passwordHasUppercase,
                    ),
                    _buildRequirementRow(
                      l10n.passwordReqLowercase,
                      _passwordHasLowercase,
                    ),
                    _buildRequirementRow(
                      l10n.passwordReqNumber,
                      _passwordHasNumber,
                    ),
                    _buildRequirementRow(
                      l10n.passwordReqSpecial,
                      _passwordHasSpecialChar,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextFormField(
                key: const Key('reg_confirm_password'),
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.confirmPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText:
                      !_passwordsMatch &&
                          _confirmPasswordController.text.isNotEmpty
                      ? l10n.passwordsDoNotMatch
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (!_passwordsMatch) {
                    return l10n.passwordsDoNotMatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              _buildSectionTitle(l10n.healthProfileSection),

              // Profile Name
              TextFormField(
                controller: _profileNameController,
                decoration: InputDecoration(
                  labelText: l10n.profileNameLabel,
                  hintText: l10n.profileNameHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Age
              TextFormField(
                key: const Key('reg_age'),
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.ageLabel,
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: l10n.genderLabel,
                  prefixIcon: const Icon(Icons.people),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedGender = value!);
                },
              ),
              const SizedBox(height: 16),

              // Height
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.heightLabel,
                  prefixIcon: const Icon(Icons.height),
                ),
              ),
              const SizedBox(height: 16),

              // Weight
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
              ),
              const SizedBox(height: 16),

              // Blood Group
              DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                decoration: InputDecoration(
                  labelText: l10n.bloodGroupLabel,
                  prefixIcon: const Icon(Icons.bloodtype),
                ),
                items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                    .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedBloodGroup = value!);
                },
              ),
              const SizedBox(height: 16),

              // Current Medications
              TextFormField(
                controller: _medicationsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.medicationsLabel,
                  hintText: 'Comma separated list',
                  prefixIcon: const Icon(Icons.medication),
                ),
              ),
              const SizedBox(height: 16),

              // Medical Conditions
              Text(
                l10n.medicalConditionsSection,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._medicalConditionsOptions.map((condition) {
                return CheckboxListTile(
                  title: Text(condition),
                  value: _selectedConditions.contains(condition),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedConditions.add(condition);
                      } else {
                        _selectedConditions.remove(condition);
                      }
                    });
                  },
                );
              }),

              if (_selectedConditions.contains('Other')) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _otherConditionController,
                  decoration: InputDecoration(
                    labelText: l10n.specifyOtherCondition,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Register Button
              ElevatedButton(
                key: const Key('reg_submit_button'),
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.register),
              ),
              const SizedBox(height: 16),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.alreadyHaveAccount),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Text(l10n.loginButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: isMet ? AppColors.statusNormal : AppColors.statusCritical,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isMet ? AppColors.statusNormal : AppColors.statusCritical,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
