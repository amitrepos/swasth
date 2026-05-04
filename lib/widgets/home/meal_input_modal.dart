import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/quick_select_screen.dart';
import '../../screens/food_photo_screen.dart';

/// Shows a bottom sheet with options to log a meal (quick select or food photo).
///
/// [mealType] — when non-null, the resulting [QuickSelectScreen] /
/// [FoodPhotoScreen] save the meal with this exact `meal_type` instead
/// of falling back to `detectMealType()` (current hour). Pass the slot
/// the user tapped on the dashboard ("BREAKFAST" / "LUNCH" / "SNACK" /
/// "DINNER") so the saved meal matches the user's intent regardless
/// of when in the day they're logging.
void showMealInputModal(
  BuildContext context, {
  required int profileId,
  required VoidCallback onMealSaved,
  String? mealType,
  int? mealId,
  String? existingMealType,
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
              mealId != null ? l10n.editMeal : l10n.logMeal,
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
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuickSelectScreen(
                      profileId: profileId,
                      mealType: mealType,
                      mealId: mealId,
                    ),
                  ),
                );
                // Refresh home screen if meal was saved successfully
                if (result == true) {
                  onMealSaved();
                }
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
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FoodPhotoScreen(
                      profileId: profileId,
                      mealType: mealType,
                      mealId: mealId,
                      existingMealType: existingMealType,
                      onFallbackToQuickSelect: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuickSelectScreen(
                              profileId: profileId,
                              mealType: mealType,
                              mealId: mealId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
                // Refresh home screen if meal was saved successfully
                if (result == true) {
                  onMealSaved();
                }
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
