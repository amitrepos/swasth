import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/storage_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import '../models/profile_model.dart';
import '../providers/language_provider.dart';
import 'manage_access_screen.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.enterCurrentPassword), backgroundColor: Colors.red));
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordTooShort), backgroundColor: Colors.red));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordsDoNotMatch), backgroundColor: Colors.red));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordChanged), backgroundColor: Colors.green));
        _clearPasswordFields();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
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

  Widget _buildLanguageToggle(AppLocalizations l10n) {
    final isEnglish = ref.watch(languageProvider).languageCode == 'en';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                gradient: LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.primary),
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
            _buildSection(l10n.healthInfoSection, [
              _buildInfoCard(icon: Icons.cake, label: l10n.ageField, value: l10n.ageYears('${_profile?.age ?? "?"}')),
              _buildInfoCard(icon: Icons.male, label: l10n.genderField, value: _profile?.gender ?? 'Unknown'),
              _buildInfoCard(icon: Icons.bloodtype, label: l10n.bloodGroupField, value: _profile?.bloodGroup ?? 'Unknown'),
              _buildInfoCard(icon: Icons.straighten, label: l10n.heightField, value: l10n.heightCm('${_profile?.height ?? "?"}')),
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

            if (isOwner)
              _buildSection(l10n.accountSettingsSection, [
                _buildInfoCard(icon: Icons.email, label: l10n.linkedEmail, value: _userData?['email'] ?? 'N/A'),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                    title: Text(l10n.changePassword),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showChangePasswordDialog,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLanguageToggle(l10n),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
