// Context: Primary UI for user profile selection and access management.
// Related: lib/services/profile_service.dart, lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../models/profile_model.dart';
import '../models/invite_model.dart';
import '../theme/app_theme.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import 'shell_screen.dart';
import 'create_profile_screen.dart';
import 'pending_invites_screen.dart';
import '../widgets/offline_banner.dart';

class SelectProfileScreen extends StatefulWidget {
  const SelectProfileScreen({super.key});

  @override
  State<SelectProfileScreen> createState() => _SelectProfileScreenState();
}

class _SelectProfileScreenState extends State<SelectProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final StorageService _storageService = StorageService();

  List<ProfileModel> _profiles = [];
  List<InviteModel> _pendingInvites = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        setState(() => _error = "Not authenticated");
        return;
      }

      final profiles = await _profileService.getProfiles(token);
      final invites = await _profileService.getPendingInvites(token);

      // Cache profiles for offline use
      await _storageService.saveProfiles(
        profiles.map((p) => p.toJson()).toList(),
      );

      setState(() {
        _profiles = profiles;
        _pendingInvites = invites;
        _isLoading = false;
        _isOffline = false;
      });
    } catch (e) {
      // Try loading cached profiles for offline use
      final cached = await _storageService.getCachedProfiles();
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _profiles = cached.map((j) => ProfileModel.fromJson(j)).toList();
          _isLoading = false;
          _isOffline = true;
        });
        return;
      }
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _selectProfile(ProfileModel profile) async {
    await _storageService.saveActiveProfileId(profile.id);
    await _storageService.saveActiveProfileName(profile.name);
    await _storageService.saveActiveProfileAccessLevel(profile.accessLevel);

    if (mounted) {
      // If we were pushed from Shell (profile switcher), pop back.
      // If we replaced Shell (first time / no profile), push new Shell.
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ShellScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectProfileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isOffline) const OfflineBanner(),
                        if (_pendingInvites.isNotEmpty)
                          _buildInvitesBanner(l10n),

                        _buildSectionHeader(l10n.myProfilesSection),
                        ..._profiles
                            .where((p) => p.accessLevel == 'owner')
                            .map((p) => _buildProfileCard(p)),

                        const SizedBox(height: 16),
                        _buildSectionHeader(l10n.sharedWithMeSection),
                        ..._profiles
                            .where((p) => p.accessLevel != 'owner')
                            .map((p) => _buildProfileCard(p)),

                        if (_profiles.where((p) => p.accessLevel != 'owner').isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Text(
                              l10n.noSharedProfiles,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                          ),

                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
                              );
                              if (result == true) _loadData();
                            },
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addProfile),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInvitesBanner(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PendingInvitesScreen()),
        );
        if (result == true) _loadData();
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.pendingInvitesBanner(_pendingInvites.length),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProfileCard(ProfileModel profile) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: () => _selectProfile(profile),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            profile.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          profile.name,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          profile.relationship != null
              ? '${profile.age ?? "?"} yrs · ${profile.gender ?? "Unknown"} · ${profile.relationship![0].toUpperCase()}${profile.relationship!.substring(1)}'
              : '${profile.age ?? "?"} yrs · ${profile.gender ?? "Unknown"}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: profile.accessLevel == 'owner'
                ? AppColors.primary
                : AppColors.success,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            profile.accessLevel.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
