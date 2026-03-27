import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import '../models/profile_model.dart';
import 'manage_access_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int profileId;
  const ProfileScreen({super.key, required this.profileId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter current password'), backgroundColor: Colors.red));
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min 6 characters'), backgroundColor: Colors.red));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed!'), backgroundColor: Colors.green));
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
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
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
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureNewPassword = !obscureNewPassword),
                      ),
                      helperText: 'Min. 6 characters',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
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
              TextButton(onPressed: () { _clearPasswordFields(); Navigator.pop(dialogContext); }, child: const Text('Cancel')),
              ElevatedButton(onPressed: _changePassword, child: const Text('Change Password')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Profile')), body: const Center(child: CircularProgressIndicator()));
    }

    final isOwner = _profile?.accessLevel == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
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
              tooltip: 'Manage Access',
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
                    isOwner ? 'Your Profile' : 'Shared by Someone',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info Sections
            _buildSection('Health Information', [
              _buildInfoCard(icon: Icons.cake, label: 'Age', value: '${_profile?.age ?? "?"} years'),
              _buildInfoCard(icon: Icons.male, label: 'Gender', value: _profile?.gender ?? 'Unknown'),
              _buildInfoCard(icon: Icons.bloodtype, label: 'Blood Group', value: _profile?.bloodGroup ?? 'Unknown'),
              _buildInfoCard(icon: Icons.straighten, label: 'Height', value: '${_profile?.height ?? "?"} cm'),
            ]),

            if (_profile?.medicalConditions != null && _profile!.medicalConditions!.isNotEmpty)
              _buildSection('Medical Conditions', [
                _buildInfoCard(
                  icon: Icons.medical_services, 
                  label: 'Conditions', 
                  value: _profile!.medicalConditions!.join(", ") + 
                         (_profile!.otherMedicalCondition != null ? " (${_profile!.otherMedicalCondition})" : "")
                ),
              ]),

            if (isOwner)
              _buildSection('Account Settings', [
                _buildInfoCard(icon: Icons.email, label: 'Linked Email', value: _userData?['email'] ?? 'N/A'),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Change Account Password'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showChangePasswordDialog,
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
