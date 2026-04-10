import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/quick_select_screen.dart';
import '../../screens/food_photo_screen.dart';

/// Shows a bottom sheet with options to log a meal (quick select or food photo).
void showMealInputModal(
  BuildContext context, {
  required int profileId,
  required VoidCallback onMealSaved,
}) {
  final l10n = AppLocalizations.of(context)!;

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
              l10n.logMeal,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.logMealSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('meal_quick_select_option'),
              icon: const Icon(Icons.restaurant_menu),
              label: Text(l10n.quickSelectOption),
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
                    builder: (_) => QuickSelectScreen(profileId: profileId),
                  ),
                );
                onMealSaved();
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('meal_scan_photo_option'),
              icon: const Icon(Icons.camera_alt),
              label: Text(l10n.scanFoodPhotoOption),
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
                    builder: (_) => FoodPhotoScreen(
                      profileId: profileId,
                      onFallbackToQuickSelect: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QuickSelectScreen(profileId: profileId),
                          ),
                        );
                      },
                    ),
                  ),
                );
                onMealSaved();
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.photoAiHint,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
