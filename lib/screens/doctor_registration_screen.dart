import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:swasth_app/l10n/app_localizations.dart';
import '../constants/doctor_specialties.dart';
import '../theme/app_theme.dart';
import '../services/doctor_service.dart';
import '../services/error_mapper.dart';
import '../widgets/auth_form_scroll_body.dart';
import '../widgets/password_requirements_box.dart';
import 'unified_login_screen.dart';

/// Doctor self-registration screen.
///
/// POSTs to `/api/doctor/register`. The resulting account will be marked
/// unverified until a Swasth admin approves the NMC number.
class DoctorRegistrationScreen extends StatefulWidget {
  const DoctorRegistrationScreen({super.key});

  @override
  State<DoctorRegistrationScreen> createState() =>
      _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorService = DoctorService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nmcController = TextEditingController();
  final _clinicController = TextEditingController();

  // These are API key strings — see backend schemas.DOCTOR_SPECIALTY_OPTIONS.
  String _selectedSpecialty = 'General Physician';
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nmcController.dispose();
    _clinicController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);
    try {
      await _doctorService.register({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'confirm_password': _confirmPasswordController.text,
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'nmc_number': _nmcController.text.trim(),
        'specialty': _selectedSpecialty,
        'clinic_name': _clinicController.text.trim().isEmpty
            ? null
            : _clinicController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.doctorRegisterSuccess),
          backgroundColor: AppColors.statusNormal,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      await ErrorMapper.showSnack(
        context,
        e,
        backgroundColor: AppColors.statusCritical,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.doctorRegisterTitle)),
      body: AuthFormScrollBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.doctorRegisterHeadline,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.doctorRegisterSubheadline,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('doc_reg_full_name'),
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: l10n.doctorFullNameLabel,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter your full name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('doc_reg_email'),
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
              TextFormField(
                key: const Key('doc_reg_phone'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.phoneValidationEmpty;
                  }
                  final stripped = value.replaceAll(RegExp(r'[\s\-]'), '');
                  if (!RegExp(r'^\+?[0-9]+$').hasMatch(stripped)) {
                    return l10n.phoneValidationDigits;
                  }
                  if (stripped.length < 10 || stripped.length > 15) {
                    return l10n.phoneValidationLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('doc_reg_nmc'),
                controller: _nmcController,
                decoration: InputDecoration(
                  labelText: l10n.doctorNmcLabel,
                  hintText: l10n.doctorNmcHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.doctorNmcEmpty;
                  }
                  if (value.trim().length < 4) {
                    return l10n.doctorNmcEmpty;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('doc_reg_specialty'),
                value: _selectedSpecialty,
                decoration: InputDecoration(
                  labelText: l10n.doctorSpecialtyLabel,
                  prefixIcon: const Icon(Icons.medical_services_outlined),
                ),
                items: doctorSpecialtyApiKeys
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(doctorSpecialtyDisplayName(l10n, k)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(
                  () => _selectedSpecialty = v ?? _selectedSpecialty,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('doc_reg_clinic'),
                controller: _clinicController,
                decoration: InputDecoration(
                  labelText: l10n.doctorClinicLabel,
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('doc_reg_password'),
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  prefixIcon: const Icon(Icons.lock),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.passwordValidationEmpty;
                  }
                  if (!PasswordRequirementsBox.meetsAllRequirements(value)) {
                    return 'Password does not meet requirements';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              PasswordRequirementsBox(password: _passwordController.text),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('doc_reg_confirm_password'),
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.confirmPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return l10n.passwordsDoNotMatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('doc_reg_submit'),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.doctorRegisterSubmit),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.alreadyHaveAccount),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
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
}
