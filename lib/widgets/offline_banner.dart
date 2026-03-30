import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.amber.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.offlineBanner,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
