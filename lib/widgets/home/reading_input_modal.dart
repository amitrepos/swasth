import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/photo_scan_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/reading_confirmation_screen.dart';

/// Shows a bottom sheet with options to log a reading (camera, BLE, manual).
void showReadingInputModal(
  BuildContext context, {
  required int profileId,
  required String deviceType,
  required String btDeviceType,
  required VoidCallback onReadingSaved,
}) {
  final l10n = AppLocalizations.of(context)!;
  final localizedLabel = deviceType == 'glucose'
      ? l10n.glucometer
      : l10n.bpMeter;

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
            OutlinedButton.icon(
              key: const Key('reading_bluetooth'),
              icon: const Icon(Icons.bluetooth),
              label: Text(l10n.connectViaBluetooth),
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
                    builder: (_) => DashboardScreen(
                      device: null,
                      services: [],
                      deviceType: btDeviceType,
                      autoConnect: true,
                      profileId: profileId,
                    ),
                  ),
                );
                onReadingSaved();
              },
            ),
            const SizedBox(height: 12),
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
