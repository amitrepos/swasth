// Nutrition analysis data model — detailed food breakdown from Gemini Vision.
// Related: backend/schemas.py (NutritionAnalysisResult, FoodItemNutrition)

class FoodItemNutrition {
  final String name;
  final double weightGrams;
  final double calories;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double fiberG;

  FoodItemNutrition({
    required this.name,
    required this.weightGrams,
    required this.calories,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.fiberG,
  });

  factory FoodItemNutrition.fromJson(Map<String, dynamic> json) {
    return FoodItemNutrition(
      name: json['name'] as String? ?? 'Unknown',
      weightGrams: (json['weight_grams'] as num?)?.toDouble() ?? 0.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight_grams': weightGrams,
      'calories': calories,
      'carbs_g': carbsG,
      'protein_g': proteinG,
      'fat_g': fatG,
      'fiber_g': fiberG,
    };
  }
}

class NutritionAnalysisResult {
  final List<FoodItemNutrition> foods;
  final double totalCalories;
  final double totalCarbsG;
  final double totalProteinG;
  final double totalFatG;
  final double totalFiberG;
  final String carbLevel; // low, medium, high
  final String sugarLevel; // low, medium, high
  final double? ironMg;
  final double? calciumMg;
  final double? vitaminCMg;
  final bool? isVegan;
  final bool? isVegetarian;
  final bool? isGlutenFree;
  final bool? isHighProtein;
  final int? mealScore;
  final String? mealScoreReason;

  NutritionAnalysisResult({
    required this.foods,
    required this.totalCalories,
    required this.totalCarbsG,
    required this.totalProteinG,
    required this.totalFatG,
    required this.totalFiberG,
    required this.carbLevel,
    required this.sugarLevel,
    this.ironMg,
    this.calciumMg,
    this.vitaminCMg,
    this.isVegan,
    this.isVegetarian,
    this.isGlutenFree,
    this.isHighProtein,
    this.mealScore,
    this.mealScoreReason,
  });

  factory NutritionAnalysisResult.fromJson(Map<String, dynamic> json) {
    final foodsList = json['foods'] as List<dynamic>? ?? [];
    return NutritionAnalysisResult(
      foods: foodsList
          .map((f) => FoodItemNutrition.fromJson(f as Map<String, dynamic>))
          .toList(),
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0.0,
      totalFiberG: (json['total_fiber_g'] as num?)?.toDouble() ?? 0.0,
      carbLevel: json['carb_level'] as String? ?? 'medium',
      sugarLevel: json['sugar_level'] as String? ?? 'medium',
      ironMg: (json['iron_mg'] as num?)?.toDouble(),
      calciumMg: (json['calcium_mg'] as num?)?.toDouble(),
      vitaminCMg: (json['vitamin_c_mg'] as num?)?.toDouble(),
      isVegan: json['is_vegan'] as bool?,
      isVegetarian: json['is_vegetarian'] as bool?,
      isGlutenFree: json['is_gluten_free'] as bool?,
      isHighProtein: json['is_high_protein'] as bool?,
      mealScore: json['meal_score'] as int?,
      mealScoreReason: json['meal_score_reason'] as String?,
    );
  }
}
