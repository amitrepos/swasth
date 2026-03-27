import 'package:flutter/material.dart';
import '../services/profile_service.dart';
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
  
  List<Map<String, dynamic>> _accesses = [];
  bool _isLoading = true;
  String? _error;

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
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");

      await _profileService.sendInvite(token, widget.profileId, email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent successfully'), backgroundColor: Colors.green),
        );
        _emailController.clear();
      }
      _loadAccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _revokeAccess(int userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access?'),
        content: Text('Are you sure you want to stop sharing this profile with $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke', style: TextStyle(color: Colors.red))),
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
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Access'),
      ),
      body: Column(
        children: [
          // Invite Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite someone to view this profile',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Enter email address',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _inviteUser,
                          child: const Text('Invite'),
                        ),
                      ],
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
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _accesses.length <= 1 // Only owner is present
                        ? const Center(
                            child: Text(
                              'Not shared with anyone yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _accesses.length,
                            itemBuilder: (context, index) {
                              final access = _accesses[index];
                              if (access['access_level'] == 'owner') return const SizedBox.shrink();

                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(access['full_name']),
                                subtitle: Text(access['email']),
                                trailing: TextButton(
                                  onPressed: _isLoading ? null : () => _revokeAccess(access['user_id'], access['full_name']),
                                  child: const Text('Revoke', style: TextStyle(color: Colors.red)),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
