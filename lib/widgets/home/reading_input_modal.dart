import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/photo_scan_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/reading_confirmation_screen.dart';
import '../../screens/scan_screen.dart';

/// Shows a bottom sheet with options to log a reading (camera, BLE, manual).
void showReadingInputModal(
  BuildContext context, {
  required int profileId,
  required String deviceType,
  required String btDeviceType,
  required VoidCallback onReadingSaved,
}) {
  final l10n = AppLocalizations.of(context)!;
  final isSpo2 = deviceType == 'spo2';
  final isSteps = deviceType == 'steps';

  final String localizedLabel;
  if (isSpo2) {
    localizedLabel = 'SpO2';
  } else if (isSteps) {
    localizedLabel = l10n.lastSteps;
  } else {
    localizedLabel = deviceType == 'glucose' ? l10n.glucometer : l10n.bpMeter;
  }

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.howToLog,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Camera scan — only for glucose and BP (not SpO2/Steps)
            if (!isSpo2 && !isSteps) ...[
              ElevatedButton.icon(
                key: const Key('reading_scan_camera'),
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.scanWithCamera),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoScanScreen(
                        deviceType: deviceType,
                        profileId: profileId,
                      ),
                    ),
                  );
                  onReadingSaved();
                },
              ),
              const SizedBox(height: 12),
            ],

            // Bluetooth — for glucose, BP, and SpO2 (armband)
            if (!isSteps) ...[
              OutlinedButton.icon(
                key: const Key('reading_bluetooth'),
                icon: Icon(isSpo2 ? Icons.watch : Icons.bluetooth),
                label: Text(isSpo2 ? l10n.armband : l10n.connectViaBluetooth),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  if (isSpo2) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanScreen(
                          deviceType: 'Armband',
                          profileId: profileId,
                        ),
                      ),
                    );
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DashboardScreen(
                          device: null,
                          services: [],
                          deviceType: btDeviceType,
                          autoConnect: false, // Don't auto-scan, let user select device
                          profileId: profileId,
                        ),
                      ),
                    );
                  }
                  onReadingSaved();
                },
              ),
              const SizedBox(height: 12),
            ],

            // Manual entry — always available
            OutlinedButton.icon(
              key: const Key('reading_manual_entry'),
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.enterManually),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReadingConfirmationScreen(
                      ocrResult: null,
                      deviceType: deviceType,
                      profileId: profileId,
                    ),
                  ),
                );
                onReadingSaved();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
