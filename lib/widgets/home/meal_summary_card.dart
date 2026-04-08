import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../models/meal_log.dart';
import '../../services/meal_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Displays today's logged meals as colored badge pills.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.todaysMeals.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 2,
          ),
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
              : (_meals == null || _meals!.isEmpty)
              ? _buildEmptyState(l10n)
              : _buildMealBadges(),
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
        return '\u2705';
      case 'MODERATE':
        return '\u2796';
      case 'HIGH':
        return '\u26A0\uFE0F';
      case 'VERY_HIGH':
        return '\u2757';
      default:
        return '\u2796';
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
