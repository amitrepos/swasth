import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import '../models/meal_log.dart';
import '../models/nutrition_analysis_result.dart';
import '../services/connectivity_service.dart';
import '../services/meal_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Hour thresholds for detecting meal type based on current time.
const _kBreakfastEndHour = 11; // Before 11:00 = Breakfast
const _kLunchEndHour = 15;     // Before 15:00 = Lunch
const _kSnackEndHour = 18;     // Before 18:00 = Snack, else Dinner

/// Shows detailed nutrition analysis result: macros, micros, flags, meal score.
class NutritionResultScreen extends StatefulWidget {
  final int profileId;
  final NutritionAnalysisResult result;
  final String? mealType;
  final VoidCallback? onFallbackToQuickSelect;

  const NutritionResultScreen({
    super.key,
    required this.profileId,
    required this.result,
    this.mealType,
    this.onFallbackToQuickSelect,
  });

  @override
  State<NutritionResultScreen> createState() => _NutritionResultScreenState();
}

class _NutritionResultScreenState extends State<NutritionResultScreen> {
  late String _selectedMealType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.mealType ?? _detectMealType();
  }

  String _detectMealType() {
    // Use UTC time as a more reliable default for travelers / wrong-clock devices
    // The user can override via the dropdown, so this is just a sensible default
    final hour = DateTime.now().toUtc().hour;
    if (hour < _kBreakfastEndHour) return 'BREAKFAST';
    if (hour < _kLunchEndHour) return 'LUNCH';
    if (hour < _kSnackEndHour) return 'SNACK';
    return 'DINNER';
  }

  Color _carbLevelColor() {
    switch (widget.result.carbLevel.toLowerCase()) {
      case 'low':
        return AppColors.success;
      case 'medium':
        return AppColors.amber;
      case 'high':
        return AppColors.danger;
      default:
        return AppColors.amber;
    }
  }

  Color _sugarLevelColor() {
    switch (widget.result.sugarLevel.toLowerCase()) {
      case 'low':
        return AppColors.success;
      case 'medium':
        return AppColors.amber;
      case 'high':
        return AppColors.danger;
      default:
        return AppColors.amber;
    }
  }

  String _mealTypeLabel(String type) {
    final l10n = AppLocalizations.of(context)!;
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

  /// Maps carb_level (low/medium/high) to MealLog category.
  String _categoryFromCarbLevel() {
    switch (widget.result.carbLevel.toLowerCase()) {
      case 'low':
        return 'LOW_CARB';
      case 'high':
        return 'HIGH_CARB';
      case 'medium':
      default:
        return 'MODERATE_CARB';
    }
  }

  /// Maps sugar_level (low/medium/high) to glucose impact.
  String _glucoseImpactFromSugarLevel() {
    switch (widget.result.sugarLevel.toLowerCase()) {
      case 'low':
        return 'LOW';
      case 'high':
        return 'HIGH';
      case 'medium':
      default:
        return 'MODERATE';
    }
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
        category: _categoryFromCarbLevel(),
        glucoseImpact: _glucoseImpactFromSugarLevel(),
        inputMethod: 'PHOTO_GEMINI',
        timestamp: DateTime.now(),
      );

      // Check connectivity and queue offline if needed
      final isOnline = await ConnectivityService().isServerReachable();
      if (!isOnline) {
        // Queue for offline sync
        await StorageService().addToSyncQueue(mealLog.toJson());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.mealSavedOffline),
              backgroundColor: AppColors.amber,
            ),
          );
          Navigator.of(context).pop(true);
        }
        return;
      }

      await MealService().saveMeal(mealLog, token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.mealSavedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.foodPhotoSaveFailed),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = widget.result;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nutritionAnalysisTitle),
        actions: [
          DropdownButton<String>(
            key: const Key('meal_type_dropdown'),
            value: _selectedMealType,
            underline: const SizedBox(),
            items: ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER']
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(_mealTypeLabel(type)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMealType = value);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Meal Score Card
            if (result.mealScore != null)
              _buildMealScoreCard(result),

            const SizedBox(height: 16),

            // Carb & Sugar Level Badges
            Row(
              children: [
                Expanded(
                  child: _buildLevelBadge(
                    label: l10n.carbLevel,
                    level: result.carbLevel,
                    color: _carbLevelColor(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLevelBadge(
                    label: l10n.sugarLevel,
                    level: result.sugarLevel,
                    color: _sugarLevelColor(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Total Macros
            Text(
              l10n.totalNutrition,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _buildMacroGrid(result, l10n),

            const SizedBox(height: 24),

            // Food Items
            if (result.foods.isNotEmpty) ...[
              Text(
                l10n.detectedFoods,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ...result.foods.map((food) => _buildFoodItemCard(food, l10n)),
              const SizedBox(height: 24),
            ],

            // Micronutrients
            if (result.ironMg != null ||
                result.calciumMg != null ||
                result.vitaminCMg != null) ...[
              Text(
                l10n.micronutrients,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _buildMicronutrients(result, l10n),
              const SizedBox(height: 24),
            ],

            // Diet Flags
            if (result.isVegan != null ||
                result.isVegetarian != null ||
                result.isGlutenFree != null ||
                result.isHighProtein != null) ...[
              Text(
                l10n.dietFlags,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildDietFlags(result),
              ),
              const SizedBox(height: 24),
            ],

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgGrouped,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.mealDisclaimer,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              key: const Key('save_meal_button'),
              onPressed: _isSaving ? null : _saveMeal,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(l10n.saveMeal),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealScoreCard(NutritionAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              '${result.mealScore}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.mealHealthScore,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (result.mealScoreReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.mealScoreReason!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge({
    required String label,
    required String level,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            level.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroGrid(NutritionAnalysisResult result, AppLocalizations l10n) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMacroCard(
          label: l10n.calories,
          value: '${result.totalCalories.round()}',
          unit: l10n.kcalUnit,
          icon: Icons.local_fire_department,
          color: AppColors.danger,
        ),
        _buildMacroCard(
          label: l10n.carbs,
          value: '${result.totalCarbsG.toStringAsFixed(1)}',
          unit: l10n.gramsUnit,
          icon: Icons.grain,
          color: AppColors.amber,
        ),
        _buildMacroCard(
          label: l10n.protein,
          value: '${result.totalProteinG.toStringAsFixed(1)}',
          unit: l10n.gramsUnit,
          icon: Icons.fitness_center,
          color: AppColors.primary,
        ),
        _buildMacroCard(
          label: l10n.fat,
          value: '${result.totalFatG.toStringAsFixed(1)}',
          unit: l10n.gramsUnit,
          icon: Icons.opacity,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildMacroCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItemCard(FoodItemNutrition food, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgGrouped,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  food.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                '${food.weightGrams.round()}g',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildMiniMacro('${food.calories.round()} ${l10n.kcalUnit}', AppColors.danger),
              _buildMiniMacro('${food.carbsG.toStringAsFixed(1)}${l10n.gramsUnit} ${l10n.carbsUnit}', AppColors.amber),
              _buildMiniMacro('${food.proteinG.toStringAsFixed(1)}${l10n.gramsUnit} ${l10n.proteinUnit}', AppColors.primary),
              _buildMiniMacro('${food.fatG.toStringAsFixed(1)}${l10n.gramsUnit} ${l10n.fatUnit}', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMacro(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMicronutrients(NutritionAnalysisResult result, AppLocalizations l10n) {
    return Row(
      children: [
        if (result.ironMg != null)
          Expanded(
            child: _buildMicronutrientItem(
              label: l10n.iron,
              value: '${result.ironMg!.toStringAsFixed(1)} mg',
              icon: Icons.favorite,
            ),
          ),
        if (result.calciumMg != null)
          Expanded(
            child: _buildMicronutrientItem(
              label: l10n.calcium,
              value: '${result.calciumMg!.toStringAsFixed(1)} mg',
              icon: Icons.shield,
            ),
          ),
        if (result.vitaminCMg != null)
          Expanded(
            child: _buildMicronutrientItem(
              label: l10n.vitaminC,
              value: '${result.vitaminCMg!.toStringAsFixed(1)} mg',
              icon: Icons.brightness_1,
            ),
          ),
      ],
    );
  }

  Widget _buildMicronutrientItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDietFlags(NutritionAnalysisResult result) {
    final flags = <Widget>[];
    final l10n = AppLocalizations.of(context)!;

    if (result.isVegan == true) {
      flags.add(_buildFlagChip(l10n.vegan, AppColors.success));
    }
    if (result.isVegetarian == true) {
      flags.add(_buildFlagChip(l10n.vegetarian, AppColors.success));
    }
    if (result.isGlutenFree == true) {
      flags.add(_buildFlagChip(l10n.glutenFree, AppColors.amber));
    }
    if (result.isHighProtein == true) {
      flags.add(_buildFlagChip(l10n.highProtein, AppColors.primary));
    }

    return flags;
  }

  Widget _buildFlagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
