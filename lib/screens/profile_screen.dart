import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import '../models/profile_model.dart';
import '../providers/language_provider.dart';
import 'manage_access_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final int profileId;
  const ProfileScreen({super.key, required this.profileId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ProfileModel? _profile;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final _profileService = ProfileService();
  final _apiService = ApiService();

  // Password change controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Health info controllers
  final _ageController = TextEditingController();
  final _heightEditController = TextEditingController();
  final _weightEditController = TextEditingController();

  // Doctor detail controllers
  final _doctorNameController = TextEditingController();
  final _doctorSpecialtyController = TextEditingController();
  final _doctorWhatsappController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    _heightEditController.dispose();
    _weightEditController.dispose();
    _doctorNameController.dispose();
    _doctorSpecialtyController.dispose();
    _doctorWhatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception("Not authenticated");

      final userData = await StorageService().getUserData();
      final profile = await _profileService.getProfile(token, widget.profileId);

      setState(() {
        _userData = userData;
        _profile = profile;
        _isLoading = false;
      });
      _initHealthControllers();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  void _clearPasswordFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.enterCurrentPassword), backgroundColor: AppColors.statusCritical));
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordTooShort), backgroundColor: AppColors.statusCritical));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordsDoNotMatch), backgroundColor: AppColors.statusCritical));
      return;
    }

    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');

      await _apiService.updateProfile(token, {
        'current_password': _currentPasswordController.text,
        'new_password': _newPasswordController.text,
        'confirm_password': _confirmPasswordController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordChanged), backgroundColor: AppColors.statusNormal));
        _clearPasswordFields();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.statusCritical));
      }
    }
  }

  void _confirmDeleteAccount() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Text(l10n.deleteAccountConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final token = await StorageService().getToken();
                if (token == null) return;
                await ApiService().deleteAccount(token);
                await StorageService().clearEverything();
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.statusCritical),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusCritical, foregroundColor: Colors.white),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.changePasswordTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    decoration: InputDecoration(
                      labelText: l10n.currentPasswordLabel,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureCurrentPassword = !obscureCurrentPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: l10n.newPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureNewPassword = !obscureNewPassword),
                      ),
                      helperText: l10n.passwordMinChars,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: l10n.confirmNewPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () { _clearPasswordFields(); Navigator.pop(dialogContext); },
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: _changePassword,
                child: Text(l10n.changePasswordTitle),
              ),
            ],
          );
        },
      ),
    );
  }

  void _initHealthControllers() {
    _ageController.text = _profile?.age?.toString() ?? '';
    _heightEditController.text = _profile?.height?.toString() ?? '';
    _weightEditController.text = _profile?.weight?.toString() ?? '';
    _doctorNameController.text = _profile?.doctorName ?? '';
    _doctorSpecialtyController.text = _profile?.doctorSpecialty ?? '';
    _doctorWhatsappController.text = _profile?.doctorWhatsapp ?? '';
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');

      final data = <String, dynamic>{
        'doctor_name': _doctorNameController.text.trim().isEmpty ? null : _doctorNameController.text.trim(),
        'doctor_specialty': _doctorSpecialtyController.text.trim().isEmpty ? null : _doctorSpecialtyController.text.trim(),
        'doctor_whatsapp': _doctorWhatsappController.text.trim().isEmpty ? null : _doctorWhatsappController.text.trim(),
      };
      final age = int.tryParse(_ageController.text);
      if (age != null) data['age'] = age;
      final height = double.tryParse(_heightEditController.text);
      if (height != null) data['height'] = height;
      final weight = double.tryParse(_weightEditController.text);
      if (weight != null) data['weight'] = weight;

      await _profileService.updateProfile(token, _profile!.id, data);

      if (mounted) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.save), backgroundColor: AppColors.statusNormal),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.statusCritical),
        );
      }
    }
  }

  Widget _buildLanguageToggle(AppLocalizations l10n) {
    final isEnglish = ref.watch(languageProvider).languageCode == 'en';
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l10n.appLanguageSection,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _langChip(l10n.languageEnglish, isEnglish,
                      () => ref.read(languageProvider.notifier).setLanguage('en')),
                  _langChip(l10n.languageHindi, !isEnglish,
                      () => ref.read(languageProvider.notifier).setLanguage('hi')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profile)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isOwner = _profile?.accessLevel == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileDetailsTitle),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageAccessScreen(
                      profileId: widget.profileId,
                      profileName: _profile?.name ?? "Profile",
                    ),
                  ),
                );
              },
              tooltip: l10n.manageAccess,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF38BDF8)],  // sky-500 → sky-400
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.person, size: 50, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _profile?.name ?? 'N/A',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOwner ? l10n.yourProfile : l10n.sharedBySomeone,
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info Sections
            if (isOwner) ...[
              _buildSection(l10n.healthInfoSection, [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.ageField,
                          prefixIcon: const Icon(Icons.cake),
                          suffixText: 'yrs',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _heightEditController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.heightField,
                          prefixIcon: const Icon(Icons.straighten),
                          suffixText: 'cm',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightEditController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Weight',
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                          suffixText: 'kg',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(icon: Icons.male, label: l10n.genderField, value: _profile?.gender ?? '—'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoCard(icon: Icons.bloodtype, label: l10n.bloodGroupField, value: _profile?.bloodGroup ?? '—'),
              ]),
              if (_profile?.medicalConditions != null && _profile!.medicalConditions!.isNotEmpty)
                _buildSection(l10n.medicalConditionsField, [
                  _buildInfoCard(
                    icon: Icons.medical_services,
                    label: l10n.medicalConditionsField,
                    value: _profile!.medicalConditions!.join(", ") +
                        (_profile!.otherMedicalCondition != null ? " (${_profile!.otherMedicalCondition})" : ""),
                  ),
                ]),
              _buildSection(l10n.doctorDetailsSection, [
                TextFormField(
                  controller: _doctorNameController,
                  decoration: InputDecoration(
                    labelText: l10n.doctorNameField,
                    prefixIcon: const Icon(Icons.medical_services_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _doctorSpecialtyController,
                  decoration: InputDecoration(
                    labelText: l10n.doctorSpecialtyField,
                    prefixIcon: const Icon(Icons.domain_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _doctorWhatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.doctorWhatsappField,
                    hintText: l10n.doctorWhatsappHint,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.save),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Read-only view for non-owners
              _buildSection(l10n.healthInfoSection, [
                _buildInfoCard(icon: Icons.cake, label: l10n.ageField, value: l10n.ageYears('${_profile?.age ?? "?"}')),
                _buildInfoCard(icon: Icons.male, label: l10n.genderField, value: _profile?.gender ?? '—'),
                _buildInfoCard(icon: Icons.bloodtype, label: l10n.bloodGroupField, value: _profile?.bloodGroup ?? '—'),
                _buildInfoCard(icon: Icons.straighten, label: l10n.heightField, value: l10n.heightCm('${_profile?.height ?? "?"}')),
                _buildInfoCard(icon: Icons.monitor_weight, label: 'Weight', value: _profile?.weight != null ? '${_profile!.weight} kg' : '?'),
              ]),
              if (_profile?.medicalConditions != null && _profile!.medicalConditions!.isNotEmpty)
                _buildSection(l10n.medicalConditionsField, [
                  _buildInfoCard(
                    icon: Icons.medical_services,
                    label: l10n.medicalConditionsField,
                    value: _profile!.medicalConditions!.join(", ") +
                        (_profile!.otherMedicalCondition != null ? " (${_profile!.otherMedicalCondition})" : ""),
                  ),
                ]),
              if (_profile?.doctorName?.isNotEmpty == true)
                _buildSection(l10n.doctorDetailsSection, [
                  _buildInfoCard(icon: Icons.medical_services_outlined, label: l10n.doctorNameField, value: _profile!.doctorName!),
                  if (_profile?.doctorSpecialty?.isNotEmpty == true)
                    _buildInfoCard(icon: Icons.domain_outlined, label: l10n.doctorSpecialtyField, value: _profile!.doctorSpecialty!),
                  if (_profile?.doctorWhatsapp?.isNotEmpty == true)
                    _buildInfoCard(icon: Icons.phone_outlined, label: l10n.doctorWhatsappField, value: _profile!.doctorWhatsapp!),
                ]),
            ],

            if (isOwner)
              _buildSection(l10n.accountSettingsSection, [
                _buildInfoCard(icon: Icons.email, label: l10n.linkedEmail, value: _userData?['email'] ?? 'N/A'),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                    title: Text(l10n.changePassword),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showChangePasswordDialog,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLanguageToggle(l10n),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                    title: Text(l10n.privacyPolicy),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                  ),
                ),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever, color: AppColors.statusCritical),
                    title: Text(l10n.deleteAccount, style: const TextStyle(color: AppColors.statusCritical)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _confirmDeleteAccount,
                  ),
                ),
              ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String label, required String value}) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: 16,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
