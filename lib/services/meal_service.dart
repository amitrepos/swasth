// HTTP service for meal logging endpoints.
// Related: backend/routes_meals.py, lib/models/meal_log.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/meal_log.dart';
import 'api_client.dart';

const _kTimeout = Duration(seconds: 20);

class MealService {
  static String get _baseUrl => '${AppConfig.serverHost}/api/meals';

  /// Save a new meal log via POST /api/meals.
  Future<MealLog> saveMeal(MealLogCreate data, String token) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: ApiClient.headers(token: token),
            body: jsonEncode(data.toJson()),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 201) {
        return MealLog.fromJson(jsonDecode(response.body));
      }
      throw Exception(ApiClient.errorDetail(response, 'Failed to save meal'));
    } catch (e) {
      throw Exception('Failed to save meal: $e');
    }
  }

  /// Get meals for a profile via GET /api/meals?profile_id=X&days=Y.
  Future<List<MealLog>> getMeals(
    int profileId,
    String token, {
    int days = 30,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl?profile_id=$profileId&days=$days'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List)
            .map((j) => MealLog.fromJson(j))
            .toList();
      }
      throw Exception(ApiClient.errorDetail(response, 'Failed to get meals'));
    } catch (e) {
      throw Exception('Failed to get meals: $e');
    }
  }

  /// Get today's meals via GET /api/meals/today?profile_id=X.
  Future<List<MealLog>> getTodayMeals(int profileId, String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/today?profile_id=$profileId'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List)
            .map((j) => MealLog.fromJson(j))
            .toList();
      }
      throw Exception(
        ApiClient.errorDetail(response, 'Failed to get today meals'),
      );
    } catch (e) {
      throw Exception('Failed to get today meals: $e');
    }
  }

  /// Delete a meal via DELETE /api/meals/{id}.
  Future<void> deleteMeal(int mealId, String token) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/$mealId'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          ApiClient.errorDetail(response, 'Failed to delete meal'),
        );
      }
    } catch (e) {
      throw Exception('Failed to delete meal: $e');
    }
  }

  /// Parse a food photo via POST /api/meals/parse-image?profile_id=X.
  Future<MealLog> parseImage(int profileId, File file, String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/parse-image?profile_id=$profileId');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiClient.headers(token: token))
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return MealLog.fromJson(jsonDecode(response.body));
      }
      throw Exception(ApiClient.errorDetail(response, 'Failed to parse image'));
    } catch (e) {
      throw Exception('Failed to parse image: $e');
    }
  }
}
