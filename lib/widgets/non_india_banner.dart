// Non-India read-only banner (NUO-135).
//
// Sits at the top of the shell when the caller is outside India. The
// product spec calls for the exact copy "You're viewing as a family
// member. Logging is enabled only in India." — kept verbatim here so
// QA can grep for it.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/region_service.dart';
import '../theme/app_theme.dart';

class NonIndiaBanner extends StatefulWidget {
  const NonIndiaBanner({super.key});

  @override
  State<NonIndiaBanner> createState() => _NonIndiaBannerState();
}

class _NonIndiaBannerState extends State<NonIndiaBanner> {
  RegionInfo _region = RegionService.currentOrUnknown();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    RegionService.getRegion().then((r) {
      if (!mounted) return;
      setState(() {
        _region = r;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _region.writeAllowed) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      key: const Key('non_india_banner'),
      width: double.infinity,
      color: AppColors.amber.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.public, size: 18, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.regionBannerBody,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
