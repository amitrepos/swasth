import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Shows connected BLE device status as badge pills.
class DeviceStatusCard extends StatelessWidget {
  final bool armbandConnected;
  final bool bpMonitorConnected;
  final bool phoneSensorsActive;

  const DeviceStatusCard({
    super.key,
    this.armbandConnected = false,
    this.bpMonitorConnected = false,
    this.phoneSensorsActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final devices = [
      _DeviceInfo(l10n.armband, armbandConnected),
      _DeviceInfo('Phone', phoneSensorsActive),
      _DeviceInfo('BP Monitor', bpMonitorConnected),
    ];

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          const Icon(Icons.watch, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.connectedDevices.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: devices.map((d) => _buildBadge(d)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(_DeviceInfo device) {
    final color = device.connected
        ? AppColors.statusNormal
        : AppColors.textSecondary;
    final bgColor = device.connected
        ? AppColors.statusNormal.withValues(alpha: 0.08)
        : const Color(0x1494A3B8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            device.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceInfo {
  final String name;
  final bool connected;
  const _DeviceInfo(this.name, this.connected);
}
