// Context: Quick Select meal logging — primary entry point for food tracking.
// 3 large buttons for Bihar elderly patients (50-70yo). Two taps max.
// Related: lib/services/meal_service.dart, lib/models/meal_log.dart

import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../models/meal_log.dart';
import '../services/error_mapper.dart';
import '../services/meal_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Auto-detect meal type based on current hour.
String detectMealType([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 11) return 'BREAKFAST';
  if (hour < 15) return 'LUNCH';
  if (hour < 18) return 'SNACK';
  return 'DINNER';
}

/// Map meal category to glucose impact.
String glucoseImpactFor(String category) {
  switch (category) {
    case 'HIGH_CARB':
      return 'HIGH';
    case 'SWEETS':
      return 'VERY_HIGH';
    case 'MODERATE_CARB':
      return 'MODERATE';
    case 'LOW_CARB':
      return 'LOW';
    case 'HIGH_PROTEIN':
      return 'LOW';
    default:
      return 'MODERATE';
  }
}

/// Icon for glucose impact level (color-blind safe).
String impactIcon(String glucoseImpact) {
  switch (glucoseImpact) {
    case 'LOW':
      return '\u2705'; // check mark
    case 'MODERATE':
      return '\u2796'; // minus
    case 'HIGH':
      return '\u26A0\uFE0F'; // warning
    case 'VERY_HIGH':
      return '\u2757'; // exclamation
    default:
      return '\u2796';
  }
}

class QuickSelectScreen extends StatefulWidget {
  final int profileId;

  /// Pre-selected meal type, set when the user reaches this screen
  /// from a specific dashboard slot tap (Breakfast / Lunch / Snack /
  /// Dinner). When `null` (e.g. user opened the generic meal modal),
  /// the screen falls back to [detectMealType] which uses the current
  /// hour. The fallback is the bug we're fixing — without an explicit
  /// type, a user tapping "Breakfast" at 4pm got their meal saved
  /// as `SNACK` because 3-6pm is the snack window in
  /// [detectMealType].
  final String? mealType;

  const QuickSelectScreen({super.key, required this.profileId, this.mealType});

  @override
  State<QuickSelectScreen> createState() => _QuickSelectScreenState();
}

class _QuickSelectScreenState extends State<QuickSelectScreen> {
  final MealService _mealService = MealService();
  final StorageService _storageService = StorageService();
  bool _showMoreOptions = false;
  bool _saving = false;

  Future<void> _onCategoryTap(String category) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.error)),
          );
        }
        return;
      }

      final data = MealLogCreate(
        profileId: widget.profileId,
        category: category,
        glucoseImpact: glucoseImpactFor(category),
        // Prefer the explicit meal type passed in (from a dashboard
        // slot tap). Fall back to time-based detection only when the
        // user reached this screen without tapping a specific slot.
        mealType: widget.mealType ?? detectMealType(),
        inputMethod: 'QUICK_SELECT',
        timestamp: DateTime.now(),
        userConfirmed: true,
      );

      await _mealService.saveMeal(data, token);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.mealSavedSuccess),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        await ErrorMapper.showSnack(
          context,
          e,
          backgroundColor: AppColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(l10n.quickSelectTitle),
        backgroundColor: AppColors.bgPage,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Detected meal type chip
                    _MealTypeChip(
                      mealType: widget.mealType ?? detectMealType(),
                    ),
                    const SizedBox(height: 20),

                    // --- 3 primary buttons ---
                    _MealButton(
                      key: const Key('meal_high_carb'),
                      emoji: '\uD83C\uDF5A', // rice bowl
                      label: l10n.mealHighCarb,
                      impact: impactIcon(glucoseImpactFor('HIGH_CARB')),
                      color: AppColors.amber,
                      onTap: () => _onCategoryTap('HIGH_CARB'),
                      saving: _saving,
                    ),
                    const SizedBox(height: 12),
                    _MealButton(
                      key: const Key('meal_low_carb'),
                      emoji: '\uD83E\uDD57', // salad
                      label: l10n.mealLowCarb,
                      impact: impactIcon(glucoseImpactFor('LOW_CARB')),
                      color: AppColors.success,
                      onTap: () => _onCategoryTap('LOW_CARB'),
                      saving: _saving,
                    ),
                    const SizedBox(height: 12),
                    _MealButton(
                      key: const Key('meal_sweets'),
                      emoji: '\uD83C\uDF6C', // candy
                      label: l10n.mealSweets,
                      impact: impactIcon(glucoseImpactFor('SWEETS')),
                      color: AppColors.danger,
                      onTap: () => _onCategoryTap('SWEETS'),
                      saving: _saving,
                    ),

                    const SizedBox(height: 16),

                    // --- More options toggle ---
                    Center(
                      child: TextButton(
                        onPressed: () => setState(
                          () => _showMoreOptions = !_showMoreOptions,
                        ),
                        child: Text(
                          _showMoreOptions
                              ? l10n.mealLessOptions
                              : l10n.mealMoreOptions,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    // --- 2 extra buttons ---
                    if (_showMoreOptions) ...[
                      const SizedBox(height: 8),
                      _MealButton(
                        emoji: '\uD83E\uDD69', // meat
                        label: l10n.mealHighProtein,
                        impact: impactIcon(glucoseImpactFor('HIGH_PROTEIN')),
                        color: AppColors.primary,
                        onTap: () => _onCategoryTap('HIGH_PROTEIN'),
                        saving: _saving,
                      ),
                      const SizedBox(height: 12),
                      _MealButton(
                        emoji: '\uD83C\uDF71', // bento
                        label: l10n.mealModerateCarb,
                        impact: impactIcon(glucoseImpactFor('MODERATE_CARB')),
                        color: AppColors.amber,
                        onTap: () => _onCategoryTap('MODERATE_CARB'),
                        saving: _saving,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // --- Disclaimer ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                l10n.mealDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip showing auto-detected meal type (e.g. "Lunch").
class _MealTypeChip extends StatelessWidget {
  final String mealType;

  const _MealTypeChip({required this.mealType});

  String _label(AppLocalizations l10n) {
    switch (mealType) {
      case 'BREAKFAST':
        return l10n.mealTypeBreakfast;
      case 'LUNCH':
        return l10n.mealTypeLunch;
      case 'SNACK':
        return l10n.mealTypeSnack;
      case 'DINNER':
        return l10n.mealTypeDinner;
      default:
        return mealType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgPill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _label(l10n),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Full-width 72dp meal category button with emoji, single localized label.
class _MealButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String impact;
  final Color color;
  final VoidCallback onTap;
  final bool saving;

  const _MealButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.impact,
    required this.color,
    required this.onTap,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ElevatedButton(
        onPressed: saving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(impact, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
