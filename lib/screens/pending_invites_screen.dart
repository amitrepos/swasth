import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../models/invite_model.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

class PendingInvitesScreen extends StatefulWidget {
  const PendingInvitesScreen({super.key});

  @override
  State<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends State<PendingInvitesScreen> {
  final ProfileService _profileService = ProfileService();
  final StorageService _storageService = StorageService();

  List<InviteModel> _invites = [];
  bool _isLoading = true;
  String? _error;
  bool _anyChange = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");

      final invites = await _profileService.getPendingInvites(token);
      setState(() {
        _invites = invites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _respond(InviteModel invite, bool accept) async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception("Not authenticated");

      await _profileService.respondToInvite(token, invite.id, accept);
      _anyChange = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? l10n.acceptedInvite(invite.profileName)
                : l10n.rejectedInvite(invite.profileName)),
            backgroundColor: accept ? Colors.green : Colors.grey,
          ),
        );
      }
      _loadInvites();
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
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _anyChange);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.pendingInvitesTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _anyChange),
          ),
        ),
        body: _isLoading && _invites.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadInvites, child: Text(l10n.retry)),
                      ],
                    ),
                  )
                : _invites.isEmpty
                    ? Center(
                        child: Text(l10n.noPendingInvites, style: const TextStyle(color: Colors.grey)),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvites,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _invites.length,
                          itemBuilder: (context, index) {
                            final invite = _invites[index];
                            final daysLeft = invite.expiresAt.difference(DateTime.now()).inDays;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.orange.withOpacity(0.1),
                                          child: const Icon(Icons.mail, color: Colors.orange),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                invite.invitedByName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Text(
                                                l10n.wantsToShare(invite.profileName),
                                                style: TextStyle(color: Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.expiresInDays(
                                        daysLeft,
                                        DateFormat('MMM d, yyyy').format(invite.expiresAt),
                                      ),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _isLoading ? null : () => _respond(invite, false),
                                            child: Text(l10n.reject),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : () => _respond(invite, true),
                                            child: Text(l10n.accept),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
