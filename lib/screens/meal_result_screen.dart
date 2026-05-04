import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import '../models/meal_log.dart';
import '../services/meal_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Data class for food classification result from Gemini Vision.
class FoodClassificationResult {
  final String
  category; // HIGH_CARB, MODERATE_CARB, LOW_CARB, HIGH_PROTEIN, SWEETS
  final String glucoseImpact; // HIGH, MODERATE, LOW, VERY_HIGH
  final String tipEn;
  final String tipHi;
  final double confidence;

  const FoodClassificationResult({
    required this.category,
    required this.glucoseImpact,
    required this.tipEn,
    required this.tipHi,
    required this.confidence,
  });

  factory FoodClassificationResult.fromJson(Map<String, dynamic> json) {
    return FoodClassificationResult(
      category: json['category'] as String? ?? 'MODERATE_CARB',
      glucoseImpact: json['glucose_impact'] as String? ?? 'MODERATE',
      tipEn: json['tip_en'] as String? ?? '',
      tipHi: json['tip_hi'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Shows the food classification result: carb badge, tip, disclaimer, save.
class MealResultScreen extends StatefulWidget {
  final int profileId;
  final FoodClassificationResult result;
  final VoidCallback? onFallbackToQuickSelect;

  /// If provided, this screen will update the existing meal instead of
  /// creating a new one.
  final int? mealId;

  /// Existing meal type to pre-select in the dropdown.
  final String? existingMealType;

  const MealResultScreen({
    super.key,
    required this.profileId,
    required this.result,
    this.onFallbackToQuickSelect,
    this.mealId,
    this.existingMealType,
  });

  @override
  State<MealResultScreen> createState() => _MealResultScreenState();
}

class _MealResultScreenState extends State<MealResultScreen> {
  late String _selectedMealType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.existingMealType ?? _detectMealType();
  }

  /// Auto-detect meal type based on current time.
  String _detectMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'BREAKFAST';
    if (hour < 15) return 'LUNCH';
    if (hour < 18) return 'SNACK';
    return 'DINNER';
  }

  /// Returns badge color for the food category.
  Color _badgeColor() {
    switch (widget.result.category) {
      case 'HIGH_CARB':
        return AppColors.danger;
      case 'MODERATE_CARB':
        return AppColors.amber;
      case 'LOW_CARB':
        return AppColors.success;
      case 'HIGH_PROTEIN':
        return AppColors.primary;
      case 'SWEETS':
        return AppColors.danger;
      default:
        return AppColors.amber;
    }
  }

  /// Returns icon for the food category (color-blind safe).
  IconData _badgeIcon() {
    switch (widget.result.category) {
      case 'HIGH_CARB':
        return Icons.priority_high;
      case 'MODERATE_CARB':
        return Icons.remove;
      case 'LOW_CARB':
        return Icons.check_circle;
      case 'HIGH_PROTEIN':
        return Icons.fitness_center;
      case 'SWEETS':
        return Icons.warning;
      default:
        return Icons.remove;
    }
  }

  /// Returns localized label for the food category.
  String _badgeLabel(AppLocalizations l10n) {
    switch (widget.result.category) {
      case 'HIGH_CARB':
        return l10n.foodCategoryHighCarb;
      case 'MODERATE_CARB':
        return l10n.foodCategoryModerateCarb;
      case 'LOW_CARB':
        return l10n.foodCategoryLowCarb;
      case 'HIGH_PROTEIN':
        return l10n.foodCategoryHighProtein;
      case 'SWEETS':
        return l10n.foodCategorySweets;
      default:
        return l10n.foodCategoryModerateCarb;
    }
  }

  /// Returns localized label for meal type.
  String _mealTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'BREAKFAST':
        return l10n.mealTypeBreakfast;
      case 'LUNCH':
        return l10n.mealTypeLunch;
      case 'SNACK':
        return l10n.mealTypeSnack;
      case 'DINNER':
        return l10n.mealTypeDinner;
      default:
        return type;
    }
  }

  /// Get the tip in the user's locale.
  String _localizedTip() {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'hi' && widget.result.tipHi.isNotEmpty) {
      return widget.result.tipHi;
    }
    return widget.result.tipEn;
  }

  Future<void> _saveMeal() async {
    setState(() => _isSaving = true);

    try {
      final token = await StorageService().getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.foodPhotoSaveFailed),
            ),
          );
        }
        return;
      }

      final mealLog = MealLogCreate(
        profileId: widget.profileId,
        mealType: _selectedMealType,
        category: widget.result.category,
        glucoseImpact: widget.result.glucoseImpact,
        confidence: widget.result.confidence,
        inputMethod: 'PHOTO_GEMINI',
        timestamp: DateTime.now(),
      );

      if (widget.mealId != null) {
        await MealService().updateMeal(widget.mealId!, mealLog, token);
      } else {
        await MealService().saveMeal(mealLog, token);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.foodPhotoSaved)),
        );
        // Pop back to dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.foodPhotoSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(l10n.foodResultTitle),
        backgroundColor: AppColors.bgPage,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Carb badge ──
                  _buildCarbBadge(l10n),
                  const SizedBox(height: 24),

                  // ── Tip ──
                  _buildTipCard(l10n),
                  const SizedBox(height: 20),

                  // ── Meal type dropdown ──
                  _buildMealTypeSelector(l10n),
                  const SizedBox(height: 20),

                  // ── "Not correct? Change" button ──
                  _buildChangeButton(l10n),
                  const SizedBox(height: 24),

                  // ── Disclaimer ──
                  _buildDisclaimer(l10n),
                ],
              ),
            ),
          ),

          // ── Save button fixed at bottom ──
          _buildSaveButton(l10n),
        ],
      ),
    );
  }

  Widget _buildCarbBadge(AppLocalizations l10n) {
    final color = _badgeColor();
    final icon = _badgeIcon();
    final label = _badgeLabel(l10n);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(AppLocalizations l10n) {
    final tip = _localizedTip();
    if (tip.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector(AppLocalizations l10n) {
    final mealTypes = ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.foodMealTypeLabel,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassCardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMealType,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              items: mealTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_mealTypeLabel(type, l10n)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMealType = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangeButton(AppLocalizations l10n) {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          if (widget.onFallbackToQuickSelect != null) {
            widget.onFallbackToQuickSelect!();
          } else {
            Navigator.of(context).pop();
          }
        },
        icon: const Icon(Icons.edit, size: 18),
        label: Text(l10n.foodNotCorrectChange),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDisclaimer(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgGrouped,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.foodDisclaimer,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveMeal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.save),
          ),
        ),
      ),
    );
  }
}
