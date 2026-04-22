import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
          InkWell(
            onTap: () => setState(() => _isVisible = false),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: AppColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
