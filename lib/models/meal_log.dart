// Meal log data model — mirrors backend MealLogCreate / MealLogResponse schemas.
// Related: backend/schemas.py (MealLogCreate, MealLogResponse)

class MealLog {
  final int id;
  final int profileId;
  final int? loggedBy;
  final String category;
  final String glucoseImpact;
  final String? tipEn;
  final String? tipHi;
  final String mealType;
  final String? photoPath;
  final String inputMethod;
  final double? confidence;
  final bool userConfirmed;
  final String? userCorrectedCategory;
  final DateTime timestamp;
  final DateTime createdAt;

  MealLog({
    required this.id,
    required this.profileId,
    this.loggedBy,
    required this.category,
    required this.glucoseImpact,
    this.tipEn,
    this.tipHi,
    required this.mealType,
    this.photoPath,
    required this.inputMethod,
    this.confidence,
    required this.userConfirmed,
    this.userCorrectedCategory,
    required this.timestamp,
    required this.createdAt,
  });

  static DateTime _parseUtc(dynamic val) {
    if (val == null) return DateTime.now();
    final dtStr = val.toString();
    if (!dtStr.endsWith('Z') && !dtStr.contains('+')) {
      return DateTime.parse('${dtStr}Z').toLocal();
    }
    return DateTime.parse(dtStr).toLocal();
  }

  factory MealLog.fromJson(Map<String, dynamic> json) {
    return MealLog(
      id: json['id'],
      profileId: json['profile_id'],
      loggedBy: json['logged_by'],
      category: json['category'],
      glucoseImpact: json['glucose_impact'],
      tipEn: json['tip_en'],
      tipHi: json['tip_hi'],
      mealType: json['meal_type'],
      photoPath: json['photo_path'],
      inputMethod: json['input_method'],
      confidence: (json['confidence'] as num?)?.toDouble(),
      userConfirmed: json['user_confirmed'] ?? true,
      userCorrectedCategory: json['user_corrected_category'],
      timestamp: _parseUtc(json['timestamp']),
      createdAt: _parseUtc(json['created_at']),
    );
  }
}

class MealLogCreate {
  final int profileId;
  final String category;
  final String glucoseImpact;
  final String mealType;
  final String inputMethod;
  final DateTime timestamp;
  final String? tipEn;
  final String? tipHi;
  final double? confidence;
  final bool userConfirmed;
  final String? userCorrectedCategory;
  // Nutrition fields (from Gemini Vision analysis)
  final double? totalCalories;
  final double? totalCarbsG;
  final double? totalProteinG;
  final double? totalFatG;
  final double? totalFiberG;
  final int? mealScore;

  MealLogCreate({
    required this.profileId,
    required this.category,
    required this.glucoseImpact,
    required this.mealType,
    required this.inputMethod,
    required this.timestamp,
    this.tipEn,
    this.tipHi,
    this.confidence,
    this.userConfirmed = true,
    this.userCorrectedCategory,
    this.totalCalories,
    this.totalCarbsG,
    this.totalProteinG,
    this.totalFatG,
    this.totalFiberG,
    this.mealScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'category': category,
      'glucose_impact': glucoseImpact,
      'meal_type': mealType,
      'input_method': inputMethod,
      'timestamp': timestamp.toIso8601String(),
      if (tipEn != null) 'tip_en': tipEn,
      if (tipHi != null) 'tip_hi': tipHi,
      if (confidence != null) 'confidence': confidence,
      'user_confirmed': userConfirmed,
      if (userCorrectedCategory != null)
        'user_corrected_category': userCorrectedCategory,
      // Nutrition fields
      if (totalCalories != null) 'total_calories': totalCalories,
      if (totalCarbsG != null) 'total_carbs_g': totalCarbsG,
      if (totalProteinG != null) 'total_protein_g': totalProteinG,
      if (totalFatG != null) 'total_fat_g': totalFatG,
      if (totalFiberG != null) 'total_fiber_g': totalFiberG,
      if (mealScore != null) 'meal_score': mealScore,
    };
  }
}
