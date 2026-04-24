# Known Issues

## Code Smells & Technical Debt

### Models Organization
- **FoodClassificationResult** lives in `lib/screens/meal_result_screen.dart` instead of `lib/models/`
  - This is a pre-existing issue — the class should be moved to `lib/models/food_classification_result.dart` for consistency
  - `NutritionAnalysisResult` is correctly located in `lib/models/nutrition_analysis_result.dart`
  - **Priority**: Low — no functional impact, but affects code organization
  - **Effort**: Small — requires moving the class and updating imports in dependent files
