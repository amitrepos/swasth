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
                  IconButton(
                    key: Key('history_view_reading_${reading.id}'),
                    icon: const Icon(Icons.visibility_outlined),
                    color: AppColors.textSecondary,
                    onPressed: () => _viewReadingDetails(reading),
                    tooltip: l10n.viewDetails,
                  ),
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

  void _viewReadingDetails(HealthReading reading) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _ReadingDetailsSheet(
        reading: reading,
        l10n: l10n,
        localizedStatus: _localizedStatus(reading.statusFlag, l10n),
        statusColor: _getStatusColor(reading.statusFlag),
        typeIcon: _getTypeIcon(reading.readingType),
        sampleTypeLabel: _localizedSampleType(reading.sampleType, l10n),
        mealContextLabel: _localizedMealContext(reading.mealContext, l10n),
        readingTypeLabel: _localizedReadingTypeLabel(reading.readingType, l10n),
      ),
    );
  }

  String _localizedSampleType(String? sampleType, AppLocalizations l10n) {
    switch (sampleType) {
      case 'fasting':
        return l10n.fasting;
      case 'before_meal':
        return l10n.beforeMeal;
      case 'post_meal':
        return l10n.afterMeal;
      case 'random':
        return l10n.mealContextRandom;
      default:
        return sampleType ?? '';
    }
  }

  String _localizedMealContext(String? mealContext, AppLocalizations l10n) {
    switch (mealContext) {
      case 'fasting':
        return l10n.fasting;
      case 'before_meal':
        return l10n.beforeMeal;
      case 'post_meal':
        return l10n.afterMeal;
      case 'random':
        return l10n.mealContextRandom;
      default:
        return mealContext ?? '';
    }
  }

  String _localizedReadingTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'glucose':
        return l10n.glucoseReadingTitle;
      case 'blood_pressure':
        return l10n.bpReadingTitle;
      case 'spo2':
        return 'SpO₂';
      case 'steps':
        return 'Steps';
      case 'weight':
        return l10n.weightLabel;
      default:
        return type;
    }
  }

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
                      key: Key('history_view_meal_${meal.id}'),
                      icon: const Icon(Icons.visibility_outlined),
                      color: AppColors.textSecondary,
                      onPressed: () => _viewMealDetails(meal),
                      tooltip: l10n.viewMealDetails,
                    ),
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

  /// Returns the tip text for the user's current locale from a multilingual
  /// [tipsJson] map (`{"en": "...", "hi": "...", ...}`). Falls back to English
  /// if the current locale is missing, then to empty string.
  String _localizedTip(Map<String, dynamic>? tipsJson) {
    if (tipsJson == null || tipsJson.isEmpty) return '';
    final code = Localizations.localeOf(context).languageCode;
    return (tipsJson[code] as String?) ?? (tipsJson['en'] as String?) ?? '';
  }

  void _viewMealDetails(MealLog meal) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _MealDetailsSheet(
        meal: meal,
        l10n: l10n,
        localizedTip: _localizedTip(meal.tips),
        mealTypeLabel: _localizedMealType(meal.mealType, l10n),
        categoryLabel: _localizedCarbLoadFromCategory(
          meal.userCorrectedCategory ?? meal.category,
          l10n,
        ),
        categoryColor: _carbLoadColorFromCategory(
          meal.userCorrectedCategory ?? meal.category,
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

/// Bottom sheet showing the per-type details we persisted for a health
/// reading (BP / glucose / SpO2 / steps / weight). All labels resolve from
/// the user's current locale.
class _ReadingDetailsSheet extends StatelessWidget {
  final HealthReading reading;
  final AppLocalizations l10n;
  final String localizedStatus;
  final Color statusColor;
  final IconData typeIcon;
  final String sampleTypeLabel;
  final String mealContextLabel;
  final String readingTypeLabel;

  const _ReadingDetailsSheet({
    required this.reading,
    required this.l10n,
    required this.localizedStatus,
    required this.statusColor,
    required this.typeIcon,
    required this.sampleTypeLabel,
    required this.mealContextLabel,
    required this.readingTypeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row with type icon
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(typeIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.readingDetailsTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        readingTypeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Primary value (big number)
            _buildPrimaryValue(),
            const SizedBox(height: 16),

            // Status badge
            if (localizedStatus.isNotEmpty) _buildStatusBadge(),
            const SizedBox(height: 16),

            // Per-type detail rows
            ..._buildTypeSpecificRows(),

            const SizedBox(height: 8),

            // Notes (any type)
            if (reading.notes != null && reading.notes!.trim().isNotEmpty)
              _detailRow(
                label: l10n.notesLabel,
                value: reading.notes!,
                icon: Icons.notes,
              ),

            // Recorded timestamp
            _detailRow(
              label: l10n.recordedAt,
              value: DateFormat('MMM dd, yyyy • hh:mm a')
                  .format(reading.readingTimestamp.toLocal()),
              icon: Icons.schedule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryValue() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.12),
            statusColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          reading.displayValue,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: statusColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '${l10n.statusLabel}: $localizedStatus',
            style: TextStyle(
              fontSize: 13,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTypeSpecificRows() {
    switch (reading.readingType) {
      case 'blood_pressure':
        return [
          if (reading.systolic != null)
            _detailRow(
              label: l10n.systolicLabel,
              value: '${reading.systolic!.round()} ${reading.bpUnit ?? 'mmHg'}',
              icon: Icons.arrow_upward,
            ),
          if (reading.diastolic != null)
            _detailRow(
              label: l10n.diastolicLabel,
              value:
                  '${reading.diastolic!.round()} ${reading.bpUnit ?? 'mmHg'}',
              icon: Icons.arrow_downward,
            ),
          if (reading.meanArterialPressure != null)
            _detailRow(
              label: l10n.mapLabel,
              value:
                  '${reading.meanArterialPressure!.round()} ${reading.bpUnit ?? 'mmHg'}',
              icon: Icons.show_chart,
            ),
          if (reading.pulseRate != null)
            _detailRow(
              label: l10n.pulse,
              value: '${reading.pulseRate!.round()} bpm',
              icon: Icons.favorite,
            ),
        ];
      case 'glucose':
        return [
          if (sampleTypeLabel.isNotEmpty)
            _detailRow(
              label: l10n.sampleTypeLabel,
              value: sampleTypeLabel,
              icon: Icons.science_outlined,
            ),
          if (mealContextLabel.isNotEmpty &&
              mealContextLabel != sampleTypeLabel)
            _detailRow(
              label: l10n.mealContextSection,
              value: mealContextLabel,
              icon: Icons.restaurant_menu,
            ),
        ];
      case 'steps':
        return [
          if (reading.stepsGoal != null)
            _detailRow(
              label: l10n.stepsGoalLabel,
              value: '${reading.stepsGoal}',
              icon: Icons.flag_outlined,
            ),
        ];
      default:
        return const [];
    }
  }

  Widget _detailRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgGrouped,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet showing whatever nutrition data we persisted for a meal
/// (calories/carbs/protein/fat/fiber + meal score + tips). All labels and
/// tip text resolve from the user's current locale.
class _MealDetailsSheet extends StatelessWidget {
  final MealLog meal;
  final AppLocalizations l10n;
  final String localizedTip;
  final String mealTypeLabel;
  final String categoryLabel;
  final Color categoryColor;

  const _MealDetailsSheet({
    required this.meal,
    required this.l10n,
    required this.localizedTip,
    required this.mealTypeLabel,
    required this.categoryLabel,
    required this.categoryColor,
  });

  bool get _hasAnyNutrition =>
      meal.totalCalories != null ||
      meal.totalCarbsG != null ||
      meal.totalProteinG != null ||
      meal.totalFatG != null ||
      meal.totalFiberG != null ||
      meal.mealScore != null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mealDetailsTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              mealTypeLabel,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            if (!_hasAnyNutrition)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgGrouped,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.noNutritionData,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (meal.mealScore != null) ...[
                _buildScoreCard(),
                const SizedBox(height: 16),
              ],
              _buildCategoryBadge(),
              const SizedBox(height: 16),
              Text(
                l10n.totalNutrition,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _buildMacroRows(),
            ],

            if (localizedTip.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.healthTip,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizedTip,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary,
            child: Text(
              '${meal.mealScore}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.mealHealthScore,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: categoryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            categoryLabel,
            style: TextStyle(
              fontSize: 13,
              color: categoryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRows() {
    final rows = <Widget>[];
    if (meal.totalCalories != null) {
      rows.add(_macroRow(
        l10n.calories,
        '${meal.totalCalories!.round()} ${l10n.kcalUnit}',
        Icons.local_fire_department,
        AppColors.danger,
      ));
    }
    if (meal.totalCarbsG != null) {
      rows.add(_macroRow(
        l10n.carbs,
        '${meal.totalCarbsG!.toStringAsFixed(1)} ${l10n.gramsUnit}',
        Icons.grain,
        AppColors.amber,
      ));
    }
    if (meal.totalProteinG != null) {
      rows.add(_macroRow(
        l10n.protein,
        '${meal.totalProteinG!.toStringAsFixed(1)} ${l10n.gramsUnit}',
        Icons.fitness_center,
        AppColors.primary,
      ));
    }
    if (meal.totalFatG != null) {
      rows.add(_macroRow(
        l10n.fat,
        '${meal.totalFatG!.toStringAsFixed(1)} ${l10n.gramsUnit}',
        Icons.opacity,
        AppColors.textSecondary,
      ));
    }
    if (meal.totalFiberG != null) {
      rows.add(_macroRow(
        l10n.fiber,
        '${meal.totalFiberG!.toStringAsFixed(1)} ${l10n.gramsUnit}',
        Icons.eco,
        AppColors.success,
      ));
    }
    return Column(children: rows);
  }

  Widget _macroRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
