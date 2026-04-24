// HTTP service for meal logging endpoints.
// Related: backend/routes_meals.py, lib/models/meal_log.dart

import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/meal_log.dart';
import '../models/nutrition_analysis_result.dart';
import '../screens/meal_result_screen.dart';
import 'api_client.dart';
import 'api_exception.dart';

class MealService {
  static String get _baseUrl => '${AppConfig.serverHost}/api/meals';

  /// Helper to build and send a multipart image request.
  /// Reduces duplication between parseImage and analyzeNutrition.
  Future<http.Response> _sendImageRequest({
    required String endpoint,
    required int profileId,
    required XFile file,
    required String token,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$_baseUrl/$endpoint?profile_id=$profileId');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(ApiClient.headers(token: token));
    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: MediaType.parse(file.mimeType ?? 'image/jpeg'),
      ),
    );

    try {
      final streamed = await request.send().timeout(timeout);
      return await http.Response.fromStream(streamed);
    } catch (_) {
      throw const NetworkException();
    }
  }

  /// Save a new meal log via POST /api/meals.
  Future<MealLog> saveMeal(MealLogCreate data, String token) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse(_baseUrl),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(data.toJson()),
      ),
      successCodes: const [201],
    );
    return MealLog.fromJson(body);
  }

  /// Get meals for a profile via GET /api/meals?profile_id=X&days=Y.
  Future<List<MealLog>> getMeals(
    int profileId,
    String token, {
    int days = 30,
  }) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl?profile_id=$profileId&days=$days'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.map((j) => MealLog.fromJson(j)).toList();
  }

  /// Get today's meals via GET /api/meals?profile_id=X&days=1.
  Future<List<MealLog>> getTodayMeals(int profileId, String token) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl?profile_id=$profileId&days=1'),
        headers: ApiClient.headers(token: token),
      ),
    );
    final meals = list.map((j) => MealLog.fromJson(j)).toList();
    meals.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return meals;
  }

  /// Delete a meal via DELETE /api/meals/{id}.
  Future<void> deleteMeal(int mealId, String token) async {
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        Uri.parse('$_baseUrl/$mealId'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [200, 204],
    );
  }

  /// Parse a food photo via POST /api/meals/parse-image?profile_id=X.
  /// Uses MultipartRequest so we can't route through [ApiClient.send] —
  /// manually map errors here instead. Keeps the 30-second timeout because
  /// Gemini Vision takes longer than a normal API call.
  Future<FoodClassificationResult> parseImage(
    int profileId,
    XFile file,
    String token,
  ) async {
    final response = await _sendImageRequest(
      endpoint: 'parse-image',
      profileId: profileId,
      file: file,
      token: token,
    );

    if (response.statusCode == 200) {
      try {
        return FoodClassificationResult.fromJson(jsonDecode(response.body));
      } on FormatException {
        throw const ServerException();
      }
    }
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode >= 500) {
      throw ServerException(ApiClient.errorDetail(response, ''));
    }
    throw ValidationException(
      ApiClient.errorDetail(response, 'Failed to parse image.'),
    );
  }

  /// Analyze food photo for detailed nutrition via POST /api/meals/analyze-nutrition.
  /// Returns detailed breakdown: macros, micros, flags, meal score.
  Future<NutritionAnalysisResult> analyzeNutrition(
    int profileId,
    XFile file,
    String token,
  ) async {
    final response = await _sendImageRequest(
      endpoint: 'analyze-nutrition',
      profileId: profileId,
      file: file,
      token: token,
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        // Note: analyze_nutrition backend raises HTTPException for all errors,
        // so it never returns {"error": ...} on HTTP 200. This check is kept
        // as a defensive measure in case the backend behavior changes.
        if (json is Map<String, dynamic> && json.containsKey('error')) {
          final errorMsg = json['error'];
          throw ValidationException(
            errorMsg is String ? errorMsg : 'Analysis failed',
          );
        }
        return NutritionAnalysisResult.fromJson(json);
      } on FormatException {
        throw const ServerException();
      }
    }
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode >= 500) {
      throw ServerException(ApiClient.errorDetail(response, ''));
    }
    throw ValidationException(
      ApiClient.errorDetail(response, 'Failed to analyze nutrition.'),
    );
  }
}
