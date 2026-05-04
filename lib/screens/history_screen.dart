import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../models/meal_log.dart';
import '../services/api_exception.dart';
import '../services/error_mapper.dart';
import '../services/health_reading_service.dart';
import '../services/meal_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/home/meal_input_modal.dart';
import 'edit_reading_screen.dart';
import 'quick_select_screen.dart';
import 'meal_result_screen.dart';

/// Unified timeline of health events for one profile.
///
/// Stage 1 of the meal-correlation feature: shows readings AND meals
/// interleaved by timestamp. Filter chip lets the user narrow to one
/// type. There is intentionally NO correlation math, NO clinical claim
/// about whether a meal caused a glucose change, and NO causation
/// language anywhere — those land in Stage 2/3 with Dr. Rajesh + Legal
/// review.
class HistoryScreen extends StatefulWidget {
  final int profileId;
  const HistoryScreen({super.key, required this.profileId});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

/// Sealed view-model for a unified timeline row. Either a reading or
/// a meal — never both. The history list is built by interleaving
/// these and sorting by `timestamp` desc.
sealed class _TimelineItem {
  DateTime get timestamp;
}

class _ReadingItem extends _TimelineItem {
  final HealthReading reading;
  _ReadingItem(this.reading);
  @override
  DateTime get timestamp => reading.readingTimestamp;
}

class _MealItem extends _TimelineItem {
  final MealLog meal;
  _MealItem(this.meal);
  @override
  DateTime get timestamp => meal.timestamp;
}

class HistoryScreenState extends State<HistoryScreen> {
  final HealthReadingService _readingService = HealthReadingService();
  final MealService _mealService = MealService();
  bool _isLoading = true;
  List<HealthReading> _readings = [];
  List<MealLog> _meals = [];

  /// `null` = all (readings + meals), `'glucose'`, `'blood_pressure'`,
  /// or `'meals'`.
  String? _filterType;
  bool _canEdit = true;

  /// Called by ShellScreen when this tab becomes active.
  void refresh() => _loadAll();

  @override
  void initState() {
    super.initState();
    _loadAccessLevel();
    _loadAll();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _loadAccessLevel();
      _loadAll();
    }
  }

  Future<void> _loadAccessLevel() async {
    final level = await StorageService().getActiveProfileAccessLevel();
    if (mounted) setState(() => _canEdit = level != 'viewer');
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadReadings(), _loadMeals()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadReadings() async {
    try {
      final token = await StorageService().getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Backend filter only handles reading types — meals are filtered
      // client-side from a separate endpoint. Pass null for the meal
      // filter case so we still keep readings cached when the user
      // toggles back.
      final backendFilter =
          (_filterType == 'glucose' || _filterType == 'blood_pressure')
          ? _filterType
          : null;

      final readings = await _readingService.getReadings(
        token: token,
        profileId: widget.profileId,
        readingType: backendFilter,
        limit: 100,
      );

      // Cache readings for offline use
      await StorageService().saveReadings(
        widget.profileId,
        readings.map((r) => r.toCacheJson()).toList(),
      );

      readings.sort((a, b) => b.readingTimestamp.compareTo(a.readingTimestamp));
      
      // Filter out steps readings from history
      final filteredReadings = readings.where((r) => r.readingType != 'steps').toList();
      
      if (mounted) setState(() => _readings = filteredReadings);
    } catch (e) {
      if (e is UnauthorizedException) {
        if (mounted) await ErrorMapper.showSnack(context, e);
        return;
      }
      // Non-auth / offline error: serve cached readings if available.
      final cached = await StorageService().getCachedReadings(widget.profileId);
      if (cached != null && cached.isNotEmpty) {
        var readings = cached.map((j) => HealthReading.fromJson(j)).toList();
        if (_filterType == 'glucose' || _filterType == 'blood_pressure') {
          readings = readings
              .where((r) => r.readingType == _filterType)
              .toList();
        }
        readings = readings.where((r) => r.readingType != 'steps').toList();
        readings.sort(
          (a, b) => b.readingTimestamp.compareTo(a.readingTimestamp),
        );
        if (mounted) setState(() => _readings = readings);
        return;
      }
      if (mounted) setState(() => _readings = []);
    }
  }

  Future<void> _loadMeals() async {
    try {
      final token = await StorageService().getToken();
      if (token == null) return;
      final meals = await _mealService.getMeals(
        widget.profileId,
        token,
        days: 90,
      );
      meals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) setState(() => _meals = meals);
    } catch (e) {
      if (e is UnauthorizedException) {
        if (mounted) await ErrorMapper.showSnack(context, e);
        return;
      }
      // Silent for non-auth errors: meals are a secondary timeline source.
      if (mounted) setState(() => _meals = []);
    }
  }

  /// Builds the unified timeline by merging readings + meals and
  /// applying the active filter. Sorted by timestamp desc.
  List<_TimelineItem> get _timelineItems {
    final items = <_TimelineItem>[];
    
    // Filter readings based on selected filter type
    List<HealthReading> filteredReadings = _readings;
    if (_filterType == 'glucose' || _filterType == 'blood_pressure') {
      filteredReadings = _readings
          .where((r) => r.readingType == _filterType)
          .toList();
    }
    
    // Add readings to timeline (when filter is null or a reading type)
    if (_filterType == null ||
        _filterType == 'glucose' ||
        _filterType == 'blood_pressure') {
      items.addAll(filteredReadings.map(_ReadingItem.new));
    }
    
    // Add meals to timeline (when filter is null or meals)
    if (_filterType == null || _filterType == 'meals') {
      items.addAll(_meals.map(_MealItem.new));
    }
    
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Future<void> _deleteReading(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteReading),
        content: Text(l10n.deleteReadingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCritical,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = await StorageService().getToken();
        if (token == null) throw Exception('Not authenticated');

        await _readingService.deleteReading(id, token);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.readingDeleted),
              backgroundColor: AppColors.statusNormal,
            ),
          );
          _loadAll();
        }
      } catch (e) {
        if (mounted) {
          await ErrorMapper.showSnack(context, e);
        }
      }
    }
  }

  Future<void> _deleteMeal(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMeal),
        content: Text(l10n.deleteMealConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCritical,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = await StorageService().getToken();
        if (token == null) throw Exception('Not authenticated');

        await _mealService.deleteMeal(id, token);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.mealDeleted),
              backgroundColor: AppColors.statusNormal,
            ),
          );
          _loadAll();
        }
      } catch (e) {
        if (mounted) {
          await ErrorMapper.showSnack(context, e);
        }
      }
    }
  }

  String _localizedStatus(String? flag, AppLocalizations l10n) {
    switch (flag) {
      case 'NORMAL':
        return l10n.statusNormal;
      case 'ELEVATED':
        return l10n.statusElevated;
      case 'HIGH - STAGE 1':
        return l10n.statusHighStage1;
      case 'HIGH - STAGE 2':
        return l10n.statusHighStage2;
      case 'LOW':
        return l10n.statusLow;
      case 'CRITICAL':
        return l10n.statusCritical;
      default:
        return flag ?? '';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'NORMAL':
        return AppColors.statusNormal;
      case 'ELEVATED':
        return AppColors.statusElevated;
      case 'HIGH':
      case 'HIGH - STAGE 1':
      case 'HIGH - STAGE 2':
        return AppColors.statusHigh;
      case 'CRITICAL':
        return AppColors.statusCritical;
      case 'LOW':
        return AppColors.statusLow;
      default:
        return AppColors.statusLow;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'glucose':
        return Icons.water_drop;
      case 'blood_pressure':
        return Icons.favorite;
      default:
        return Icons.medical_services;
    }
  }

  String _localizedMealType(String mealType, AppLocalizations l10n) {
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

  /// Factual food-category descriptor — never a clinical claim. "High-carb
  /// meal" describes the typical carbohydrate content of the food
  /// category, not what happened to the patient's glucose. Causation
  /// language is forbidden in Stage 1 (NMC § 3.3 — non-doctor clinical
  /// advice). Stage 2 will introduce a doctor-reviewed rule-based summary.
  /// Maps category (LOW_CARB, MODERATE_CARB, HIGH_CARB, HIGH_PROTEIN, SWEETS)
  /// to localized carb load label for display.
  String _localizedCarbLoadFromCategory(String category, AppLocalizations l10n) {
    switch (category) {
      case 'LOW_CARB':
        return l10n.mealCarbLoadLow;
      case 'MODERATE_CARB':
        return l10n.mealCarbLoadModerate;
      case 'HIGH_CARB':
      case 'SWEETS':
        return l10n.mealCarbLoadHigh;
      case 'HIGH_PROTEIN':
        return l10n.mealCarbLoadLow; // High protein typically has low carb impact
      default:
        return l10n.mealCarbLoadModerate;
    }
  }

  /// Maps category to carb-load colour palette.
  /// `statusCritical` (red) is reserved for actual clinical readings
  /// (BP/glucose) and must never be used here.
  Color _carbLoadColorFromCategory(String category) {
    switch (category) {
      case 'LOW_CARB':
      case 'HIGH_PROTEIN':
        return AppColors.success; // Green
      case 'MODERATE_CARB':
        return AppColors.amber; // Yellow/amber
      case 'HIGH_CARB':
      case 'SWEETS':
        return AppColors.carbLoadHigh; // Orange (not red - not clinical)
      default:
        return AppColors.textSecondary;
    }
  }

  /// Non-color shape cue per category for color-blind safety.
  /// Icons describe food content, not severity.
  IconData _carbLoadIconFromCategory(String category) {
    switch (category) {
      case 'LOW_CARB':
        return Icons.eco;
      case 'MODERATE_CARB':
        return Icons.restaurant;
      case 'HIGH_CARB':
        return Icons.rice_bowl;
      case 'SWEETS':
        return Icons.cake_outlined;
      case 'HIGH_PROTEIN':
        return Icons.fitness_center;
      default:
        return Icons.restaurant;
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _timelineItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.filterByType,
            onSelected: (value) {
              setState(() {
                _filterType = value == 'all' ? null : value;
              });
              // Reload data with the new filter
              _loadReadings();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text(l10n.allReadings)),
              PopupMenuItem(value: 'glucose', child: Text(l10n.glucoseOnly)),
              PopupMenuItem(value: 'blood_pressure', child: Text(l10n.bpOnly)),
              PopupMenuItem(value: 'meals', child: Text(l10n.mealsOnly)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    _filterType == 'meals'
                        ? l10n.noMealsYet
                        : l10n.noReadingsYet,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noReadingsSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                // +1 for the meal-label disclaimer banner when any
                // meals are visible. The banner is index 0; real items
                // shift by one.
                itemCount:
                    _meals.isNotEmpty &&
                        _filterType != 'glucose' &&
                        _filterType != 'blood_pressure'
                    ? items.length + 1
                    : items.length,
                itemBuilder: (context, index) {
                  final hasBanner =
                      _meals.isNotEmpty &&
                      _filterType != 'glucose' &&
                      _filterType != 'blood_pressure';
                  if (hasBanner && index == 0) {
                    return _buildMealLabelDisclaimer(l10n);
                  }
                  final item = items[hasBanner ? index - 1 : index];
                  return switch (item) {
                    _ReadingItem(:final reading) => _buildReadingTile(
                      reading,
                      l10n,
                    ),
                    _MealItem(:final meal) => _buildMealTile(meal, l10n),
                  };
                },
              ),
            ),
    );
  }

  /// Neutral footnote shown above the timeline whenever meals are
  /// visible. Required by Dr. Rajesh's review — patients will draw
  /// inferences from meal-and-reading proximity regardless of our
  /// internal Stage 1 contract, so we anchor the meaning explicitly.
  Widget _buildMealLabelDisclaimer(AppLocalizations l10n) {
    return Padding(
      key: const Key('history_meal_disclaimer'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgGrouped,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.mealLabelDisclaimer,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingTile(HealthReading reading, AppLocalizations l10n) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 16,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(reading.statusFlag).withOpacity(0.1),
          child: Icon(
            _getTypeIcon(reading.readingType),
            color: _getStatusColor(reading.statusFlag),
          ),
        ),
        title: Text(
          reading.displayValue,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(reading.statusFlag).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _localizedStatus(reading.statusFlag, l10n),
                style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(reading.statusFlag),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat(
                'MMM dd, yyyy • hh:mm a',
              ).format(reading.readingTimestamp.toLocal()),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: _canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isEditableType(reading.readingType))
                    IconButton(
                      key: Key('history_edit_reading_${reading.id}'),
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.textSecondary,
                      onPressed: () => _editReading(reading),
                      tooltip: l10n.editReading,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.statusCritical,
                    onPressed: () => _deleteReading(reading.id),
                    tooltip: l10n.delete,
                  ),
                ],
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  bool _isEditableType(String type) =>
      type == 'glucose' || type == 'blood_pressure' || type == 'weight';

  Future<void> _editReading(HealthReading reading) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditReadingScreen(reading: reading),
      ),
    );
    if (updated == true) {
      _loadAll();
    }
  }

  Widget _buildMealTile(MealLog meal, AppLocalizations l10n) {
    final mealType = _localizedMealType(meal.mealType, l10n);
    final category = (meal.userCorrectedCategory ?? meal.category).replaceAll(
      '_',
      ' ',
    );
    // Use category (not glucoseImpact) for visual indicators to ensure consistency
    final carbColor = _carbLoadColorFromCategory(meal.userCorrectedCategory ?? meal.category);
    final carbIcon = _carbLoadIconFromCategory(meal.userCorrectedCategory ?? meal.category);
    final carbLabel = _localizedCarbLoadFromCategory(meal.userCorrectedCategory ?? meal.category, l10n);

    return GlassCard(
      key: Key('history_meal_tile_${meal.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 16,
      child: Semantics(
        label: '$mealType, $category, $carbLabel',
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: carbColor.withValues(alpha: 0.10),
            child: const Text('🍚', style: TextStyle(fontSize: 18)),
          ),
          title: Text(
            mealType,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: carbColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(carbIcon, size: 14, color: carbColor),
                    const SizedBox(width: 4),
                    Text(
                      carbLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: carbColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(meal.timestamp.toLocal()),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          trailing: _canEdit
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('history_edit_meal_${meal.id}'),
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.textSecondary,
                      onPressed: () => _editMeal(meal),
                      tooltip: l10n.editMeal,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.statusCritical,
                      onPressed: () => _deleteMeal(meal.id),
                      tooltip: l10n.delete,
                    ),
                  ],
                )
              : null,
          isThreeLine: true,
        ),
      ),
    );
  }

  Future<void> _editMeal(MealLog meal) async {
    showMealInputModal(
      context,
      profileId: widget.profileId,
      mealType: meal.mealType,
      mealId: meal.id,
      existingMealType: meal.mealType,
      onMealSaved: () {
        if (mounted) {
          _loadAll();
        }
      },
    );
  }
}
