import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:swasth_app/l10n/app_localizations.dart';
import '../constants/doctor_specialties.dart';
import '../theme/app_theme.dart';
import '../services/admin_service.dart';
import '../services/storage_service.dart';
import '../widgets/auth_form_scroll_body.dart';

/// Admin-only screen to create a patient or doctor account (G6).
///
/// POSTs to `/api/admin/users`. Requires an admin token. Doctor accounts
/// are created unverified and must go through the normal verification
/// flow (G1) before seeing patient data.
class AdminCreateUserScreen extends StatefulWidget {
  const AdminCreateUserScreen({super.key});

  @override
  State<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends State<AdminCreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  final _storageService = StorageService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nmcController = TextEditingController();
  final _clinicController = TextEditingController();

  String _role = 'patient';
  String _selectedSpecialty = 'General Physician';
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nmcController.dispose();
    _clinicController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    if (_role == 'doctor' && _nmcController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminCreateUserNmcRequired)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final email = _emailController.text.trim();
      await _adminService.createUser(
        token,
        email: email,
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _role,
        nmcNumber: _role == 'doctor' ? _nmcController.text.trim() : null,
        specialty: _role == 'doctor' ? _selectedSpecialty : null,
        clinicName: _role == 'doctor' ? _clinicController.text.trim() : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminCreateUserSuccess(email)),
          backgroundColor: AppColors.statusNormal,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.statusCritical,
        ),
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
      appBar: AppBar(title: Text(l10n.adminCreateUserTitle)),
      body: AuthFormScrollBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.adminCreateUserHeadline,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.adminCreateUserRoleLabel,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 56,
                child: SegmentedButton<String>(
                  key: const Key('acu_role_segmented'),
                  segments: [
                    ButtonSegment<String>(
                      value: 'patient',
                      label: Text(l10n.adminCreateUserRolePatient),
                      icon: const Icon(Icons.person),
                    ),
                    ButtonSegment<String>(
                      value: 'doctor',
                      label: Text(l10n.adminCreateUserRoleDoctor),
                      icon: const Icon(Icons.schedule_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
              ),
              if (_role == 'doctor') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusElevated.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.statusElevated.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.statusElevated,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.adminCreateUserDoctorComingSoon,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('acu_full_name'),
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: l10n.fullNameLabel,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('acu_email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.emailLabel,
                  prefixIcon: const Icon(Icons.email_outlined),
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
                key: const Key('acu_phone'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixIcon: const Icon(Icons.phone_outlined),
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
              if (_role == 'doctor') ...[
                TextFormField(
                  key: const Key('acu_nmc'),
                  controller: _nmcController,
                  decoration: InputDecoration(
                    labelText: l10n.doctorNmcLabel,
                    hintText: l10n.doctorNmcHint,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (_role != 'doctor') return null;
                    if (value == null || value.trim().isEmpty) {
                      return l10n.doctorNmcEmpty;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('acu_specialty'),
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
                  key: const Key('acu_clinic'),
                  controller: _clinicController,
                  decoration: InputDecoration(
                    labelText: l10n.doctorClinicLabel,
                    prefixIcon: const Icon(Icons.local_hospital_outlined),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('acu_password'),
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                  helperText: l10n.adminCreateUserTempPasswordHelp,
                  helperMaxLines: 2,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.passwordValidationEmpty;
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('acu_submit'),
                onPressed: (_isLoading || _role == 'doctor') ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.adminCreateUserSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
