// Context: Manages multi-profile switching, local storage sync, and API calls.
// Related: lib/models/profile_model.dart, backend/routes.py

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/profile_model.dart';
import '../models/invite_model.dart';
import 'api_client.dart';

class ProfileService {
  final String _baseUrl = '${AppConfig.serverHost}/api/profiles';
  final String _invitesUrl = '${AppConfig.serverHost}/api/invites';

  Future<List<ProfileModel>> getProfiles(String token) async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: ApiClient.headers(token: token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ProfileModel.fromJson(json)).toList();
    } else {
      throw Exception(ApiClient.errorDetail(response, 'Failed to get profiles'));
    }
  }

  Future<ProfileModel> createProfile(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: ApiClient.headers(token: token),
      body: json.encode(data),
    );

    if (response.statusCode == 201) {
      return ProfileModel.fromJson(json.decode(response.body));
    } else {
      throw Exception(ApiClient.errorDetail(response, 'Failed to create profile'));
    }
  }

  Future<ProfileModel> getProfile(String token, int profileId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$profileId'),
      headers: ApiClient.headers(token: token),
    );

    if (response.statusCode == 200) {
      return ProfileModel.fromJson(json.decode(response.body));
    } else {
      throw Exception(ApiClient.errorDetail(response, 'Failed to get profile'));
    }
  }

  Future<ProfileModel> updateProfile(String token, int profileId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$profileId'),
      headers: ApiClient.headers(token: token),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return ProfileModel.fromJson(json.decode(response.body));
    } else {
      throw Exception(ApiClient.errorDetail(response, 'Failed to update profile'));
    }
  }

  Future<void> deleteProfile(String token, int profileId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$profileId'),
      headers: ApiClient.headers(token: token),
    );

    if (response.statusCode != 204) {
      throw Exception(ApiClient.errorDetail(response, 'Failed to delete profile'));
    }
  }

  Future<void> sendInvite(String token, int profileId, String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$profileId/invite'),
      headers: ApiClient.headers(token: token),
      body: json.encode({'email': email}),
    );

    if (response.statusCode != 201) {
      throw Exception(ApiClient.errorDetail(response, 'Failed to send invite'));
    }
  }

  Future<void> cancelInvite(String token, int profileId, int inviteId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$profileId/invites/$inviteId'),
      headers: ApiClient.headers(token: token),
    );

    if (response.statusCode != 204) {
      throw Exception(ApiClient.errorDetail(response, 'Failed to cancel invite'));
    }
  }

  Future<List<Map<String, dynamic>>> getProfileAccess(String token, int profileId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$profileId/access'),
      headers: ApiClient.headers(token: token),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception(ApiClient.errorDetail(response, 'Failed to get profile access'));
    }
  }

  Future<void> revokeAccess(String token, int profileId, int userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$profileId/access/$userId'),
      headers: ApiClient.headers(token: token),
    );

    if (response.statusCode != 204) {
      throw Exception(ApiClient.errorDetail(response, 'Failed to revoke access'));
    }
  }

  Future<List<InviteModel>> getPendingInvites(String token) async {
    final response = await http.get(
      Uri.parse('$_invitesUrl/pending'),
      headers: ApiClient.headers(token: token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => InviteModel.fromJson(json)).toList();
    } else {
      throw Exception(ApiClient.errorDetail(response, 'Failed to get pending invites'));
    }
  }

  Future<int> respondToInvite(String token, int inviteId, bool accept) async {
    final response = await http.post(
      Uri.parse('$_invitesUrl/$inviteId/respond'),
      headers: ApiClient.headers(token: token),
      body: json.encode({'action': accept ? 'accept' : 'reject'}),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return body['profile_id'] ?? 0;
    } else {
      throw Exception(ApiClient.errorDetail(response, 'Failed to respond to invite'));
    }
  }
}
