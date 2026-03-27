import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'select_profile_screen.dart';
import 'manage_access_screen.dart';
import 'scan_screen.dart';
import 'photo_scan_screen.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  String _activeProfileName = "Health";
  int? _activeProfileId;

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    final name = await _storageService.getActiveProfileName();
    final id = await _storageService.getActiveProfileId();
    if (mounted) {
      setState(() {
        if (name != null) _activeProfileName = name;
        _activeProfileId = id;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _storageService.clearAll();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              if (_activeProfileId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(profileId: _activeProfileId!),
                  ),
                );
              }
            },
            tooltip: l10n.profile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: l10n.logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Active Profile Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.account_circle, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.viewingProfile(_activeProfileName),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.person_add_alt_1,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    tooltip: l10n.shareProfile,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (_activeProfileId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageAccessScreen(
                              profileId: _activeProfileId!,
                              profileName: _activeProfileName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SelectProfileScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.switchProfile),
                  ),
                ],
              ),
            ),

            // Welcome Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.health_and_safety,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.welcomeTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Device Selection Panel
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 0.5,
                ),
                boxShadow: Theme.of(context).brightness == Brightness.light
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      l10n.selectDevice,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDeviceIcon(
                        context: context,
                        icon: Icons.water_drop,
                        label: l10n.glucometer,
                        color: Colors.blue,
                        onTap: () => _showInputModal(
                          context,
                          l10n: l10n,
                          deviceType: 'glucose',
                          btDeviceType: 'Glucose',
                        ),
                      ),
                      _buildDeviceIcon(
                        context: context,
                        icon: Icons.favorite,
                        label: l10n.bpMeter,
                        color: Colors.red,
                        onTap: () => _showInputModal(
                          context,
                          l10n: l10n,
                          deviceType: 'blood_pressure',
                          btDeviceType: 'Blood Pressure',
                        ),
                      ),
                      _buildDeviceIcon(
                        context: context,
                        icon: Icons.watch,
                        label: l10n.armband,
                        color: Colors.green,
                        onTap: () {
                          if (_activeProfileId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DashboardScreen(
                                  device: null,
                                  services: [],
                                  deviceType: 'Armband',
                                  autoConnect: true,
                                  profileId: _activeProfileId!,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick Actions
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.quickActions,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.bluetooth_searching, color: Theme.of(context).colorScheme.primary),
                      title: Text(l10n.connectNewDevice),
                      subtitle: Text(l10n.connectNewDeviceSubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (_activeProfileId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScanScreen(profileId: _activeProfileId!),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.selectProfileFirst)),
                          );
                        }
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                      title: Text(l10n.viewHistory),
                      subtitle: Text(l10n.viewHistorySubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (_activeProfileId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryScreen(profileId: _activeProfileId!),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInputModal(
    BuildContext context, {
    required AppLocalizations l10n,
    required String deviceType,
    required String btDeviceType,
  }) {
    if (_activeProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectProfileFirst)),
      );
      return;
    }

    final localizedLabel = deviceType == 'glucose' ? l10n.glucometer : l10n.bpMeter;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.logReading(localizedLabel),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.howToLog,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.scanWithCamera),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoScanScreen(
                        deviceType: deviceType,
                        profileId: _activeProfileId!,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.bluetooth),
                label: Text(l10n.connectViaBluetooth),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DashboardScreen(
                        device: null,
                        services: [],
                        deviceType: btDeviceType,
                        autoConnect: true,
                        profileId: _activeProfileId!,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIcon({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(
                color: color,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
