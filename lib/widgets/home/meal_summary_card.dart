import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../models/meal_log.dart';
import '../../services/meal_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Displays today's logged meals as colored badge pills + meal slot prompts.
///
/// If no meals logged: shows tappable "No meals logged today" text.
/// Uses [MealService.getTodayMeals] to fetch data.
class MealSummaryCard extends StatefulWidget {
  final int profileId;
  final VoidCallback? onTapLogMeal;

  const MealSummaryCard({
    super.key,
    required this.profileId,
    this.onTapLogMeal,
  });

  @override
  State<MealSummaryCard> createState() => MealSummaryCardState();
}

class MealSummaryCardState extends State<MealSummaryCard> {
  final MealService _mealService = MealService();
  final StorageService _storageService = StorageService();
  List<MealLog>? _meals;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMeals();
  }

  @override
  void didUpdateWidget(covariant MealSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      loadMeals();
    }
  }

  Future<void> loadMeals() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storageService.getToken();
      if (token == null || !mounted) return;
      final meals = await _mealService.getTodayMeals(widget.profileId, token);
      if (mounted) {
        setState(() {
          _meals = meals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _meals = [];
          _isLoading = false;
        });
      }
    }
  }

  /// Number of meals loaded today (used by MetricsGrid).
  int get todayMealCount => _meals?.length ?? 0;

  /// Which meal types have been logged today.
  Set<String> get _loggedMealTypes =>
      _meals?.map((m) => m.mealType).toSet() ?? {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final hasMeals = _meals != null && _meals!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.todaysMeals.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (hasMeals && widget.onTapLogMeal != null)
              GestureDetector(
                onTap: widget.onTapLogMeal,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasMeals) _buildEmptyState(l10n),
                    if (hasMeals) _buildMealBadges(),
                    const SizedBox(height: 12),
                    _buildMealSlots(l10n),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return GestureDetector(
      onTap: widget.onTapLogMeal,
      child: Row(
        children: [
          const Text(
            '\uD83C\uDF5A', // 🍚
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.noMealsToday,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const TextSpan(text: ' — '),
                  TextSpan(
                    text: l10n.tapToLogMeal,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealBadges() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _meals!.map((meal) {
        final icon = _impactIcon(meal.glucoseImpact);
        final label = _mealLabel(meal);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _impactColor(meal.glucoseImpact).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$icon $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _impactColor(meal.glucoseImpact),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Meal slot row: Breakfast / Lunch / Snack / Dinner with logged state.
  Widget _buildMealSlots(AppLocalizations l10n) {
    final logged = _loggedMealTypes;
    final slots = [
      _MealSlotData('BREAKFAST', l10n.mealSlotBreakfast, '\uD83C\uDF5E'),
      _MealSlotData('LUNCH', l10n.mealSlotLunch, '\uD83C\uDF5B'),
      _MealSlotData('SNACK', l10n.mealSlotSnack, '\uD83C\uDF6A'),
      _MealSlotData('DINNER', l10n.mealSlotDinner, '\uD83C\uDF5C'),
    ];

    return Row(
      children: slots.map((slot) {
        final isLogged = logged.contains(slot.type);
        return Expanded(
          child: GestureDetector(
            onTap: !isLogged ? widget.onTapLogMeal : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: isLogged
                    ? AppColors.statusNormal.withValues(alpha: 0.06)
                    : AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLogged
                      ? AppColors.statusNormal
                      : AppColors.glassCardBorder,
                  width: isLogged ? 1.5 : 1,
                  style: isLogged ? BorderStyle.solid : BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Text(slot.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(
                    slot.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isLogged
                          ? AppColors.statusNormal
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    isLogged ? l10n.mealSlotLogged : l10n.mealSlotTapToLog,
                    style: TextStyle(
                      fontSize: 7,
                      color: isLogged
                          ? AppColors.statusNormal
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _mealLabel(MealLog meal) {
    final category = meal.userCorrectedCategory ?? meal.category;
    final type = _localizedMealType(meal.mealType);
    return '$type ($category)'
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  String _localizedMealType(String mealType) {
    final l10n = AppLocalizations.of(context)!;
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

  String _impactIcon(String glucoseImpact) {
    switch (glucoseImpact) {
      case 'LOW':
        return '\u2705'; // ✅
      case 'MODERATE':
        return '\uD83C\uDF5C'; // 🍜
      case 'HIGH':
        return '\u26A0\uFE0F'; // ⚠️
      case 'VERY_HIGH':
        return '\uD83C\uDF6C'; // 🍬
      default:
        return '\uD83C\uDF5C'; // 🍜
    }
  }

  Color _impactColor(String glucoseImpact) {
    switch (glucoseImpact) {
      case 'LOW':
        return AppColors.statusNormal;
      case 'MODERATE':
        return AppColors.amber;
      case 'HIGH':
        return AppColors.statusElevated;
      case 'VERY_HIGH':
        return AppColors.statusCritical;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _MealSlotData {
  final String type;
  final String label;
  final String icon;
  const _MealSlotData(this.type, this.label, this.icon);
}
