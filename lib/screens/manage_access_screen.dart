import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/storage_service.dart';

class ManageAccessScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const ManageAccessScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<ManageAccessScreen> createState() => _ManageAccessScreenState();
}

class _ManageAccessScreenState extends State<ManageAccessScreen> {
  final ProfileService _profileService = ProfileService();
  final StorageService _storageService = StorageService();
  final _emailController = TextEditingController();
  String? _selectedRelationship;
  String _selectedAccessLevel = 'viewer';

  List<Map<String, dynamic>> _accesses = [];
  bool _isLoading = true;
  String? _error;

  static const _relationships = [
    'father', 'mother', 'spouse', 'son', 'daughter',
    'brother', 'sister', 'uncle', 'aunt', 'friend', 'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");

      final accesses = await _profileService.getProfileAccess(token, widget.profileId);
      setState(() {
        _accesses = accesses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");

      await _profileService.sendInvite(token, widget.profileId, email, relationship: _selectedRelationship, accessLevel: _selectedAccessLevel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteSentSuccess), backgroundColor: AppColors.statusNormal),
        );
        _emailController.clear();
        setState(() {
          _selectedRelationship = null;
          _selectedAccessLevel = 'viewer';
        });
      }
      _loadAccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.statusCritical),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _revokeAccess(int userId, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.revokeAccessTitle),
        content: Text(l10n.revokeAccessConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.revoke, style: const TextStyle(color: AppColors.statusCritical)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");

      await _profileService.revokeAccess(token, widget.profileId, userId);
      _loadAccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.statusCritical),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUserAccess(int userId, String newLevel) async {
    setState(() => _isLoading = true);
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");
      await _profileService.updateAccessLevel(token, widget.profileId, userId, newLevel);
      _loadAccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.statusCritical),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageAccessTitle),
      ),
      body: Column(
        children: [
          // Invite Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassCard(
              borderRadius: 12,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.inviteSomeoneTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: l10n.enterEmailHint,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedRelationship,
                      decoration: InputDecoration(
                        labelText: l10n.relationshipLabel,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _relationships.map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_relationshipDisplayName(r, l10n)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedRelationship = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedAccessLevel,
                      decoration: const InputDecoration(
                        labelText: 'Access Level',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'viewer', child: Text('Viewer — can only view readings')),
                        DropdownMenuItem(value: 'editor', child: Text('Editor — can add & delete readings')),
                      ],
                      onChanged: (v) => setState(() => _selectedAccessLevel = v ?? 'viewer'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _inviteUser,
                        child: Text(l10n.invite),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(),

          // Users List
          Expanded(
            child: _isLoading && _accesses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.statusCritical)))
                    : _accesses.length <= 1
                        ? Center(
                            child: Text(
                              l10n.notSharedYet,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _accesses.length,
                            itemBuilder: (context, index) {
                              final access = _accesses[index];
                              if (access['access_level'] == 'owner') return const SizedBox.shrink();

                              final rel = access['relationship'] as String?;
                              final currentLevel = access['access_level'] as String? ?? 'viewer';
                              final userId = access['user_id'] as int;
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(access['full_name']),
                                subtitle: Text(
                                  rel != null
                                      ? '${_relationshipDisplayName(rel, l10n)} · ${access['email']}'
                                      : access['email'],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButton<String>(
                                      value: currentLevel,
                                      underline: const SizedBox.shrink(),
                                      isDense: true,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: currentLevel == 'editor' ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                                        DropdownMenuItem(value: 'editor', child: Text('Editor')),
                                      ],
                                      onChanged: _isLoading ? null : (v) {
                                        if (v != null && v != currentLevel) {
                                          _updateUserAccess(userId, v);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      color: AppColors.statusCritical,
                                      tooltip: l10n.revoke,
                                      onPressed: _isLoading ? null : () => _revokeAccess(userId, access['full_name']),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _relationshipDisplayName(String key, AppLocalizations l10n) {
    switch (key) {
      case 'father': return l10n.relationshipFather;
      case 'mother': return l10n.relationshipMother;
      case 'spouse': return l10n.relationshipSpouse;
      case 'son': return l10n.relationshipSon;
      case 'daughter': return l10n.relationshipDaughter;
      case 'brother': return l10n.relationshipBrother;
      case 'sister': return l10n.relationshipSister;
      case 'uncle': return l10n.relationshipUncle;
      case 'aunt': return l10n.relationshipAunt;
      case 'friend': return l10n.relationshipFriend;
      case 'other': return l10n.relationshipOther;
      default: return key;
    }
  }
}
