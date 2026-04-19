// Context: Manages multi-profile switching, local storage sync, and API calls.
// Related: lib/models/profile_model.dart, backend/routes.py

import 'dart:convert';

import '../config/app_config.dart';
import '../models/invite_model.dart';
import '../models/profile_model.dart';
import 'api_client.dart';

class ProfileService {
  final String _baseUrl = '${AppConfig.serverHost}/api/profiles';
  final String _invitesUrl = '${AppConfig.serverHost}/api/invites';

  Future<List<ProfileModel>> getProfiles(String token) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse(_baseUrl),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.map((j) => ProfileModel.fromJson(j)).toList();
  }

  Future<ProfileModel> createProfile(
    String token,
    Map<String, dynamic> data,
  ) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse(_baseUrl),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(data),
      ),
      successCodes: const [201],
    );
    return ProfileModel.fromJson(body);
  }

  Future<ProfileModel> getProfile(String token, int profileId) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/$profileId'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return ProfileModel.fromJson(body);
  }

  Future<ProfileModel> updateProfile(
    String token,
    int profileId,
    Map<String, dynamic> data,
  ) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.put(
        Uri.parse('$_baseUrl/$profileId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(data),
      ),
    );
    return ProfileModel.fromJson(body);
  }

  Future<void> deleteProfile(String token, int profileId) async {
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        Uri.parse('$_baseUrl/$profileId'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [204],
    );
  }

  Future<void> sendInvite(
    String token,
    int profileId,
    String email, {
    String? relationship,
    String accessLevel = 'viewer',
  }) async {
    final body = <String, dynamic>{'email': email, 'access_level': accessLevel};
    if (relationship != null) body['relationship'] = relationship;
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$_baseUrl/$profileId/invite'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(body),
      ),
      successCodes: const [201],
    );
  }

  Future<void> cancelInvite(String token, int profileId, int inviteId) async {
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        Uri.parse('$_baseUrl/$profileId/invites/$inviteId'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [204],
    );
  }

  Future<List<Map<String, dynamic>>> getProfileAccess(
    String token,
    int profileId,
  ) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/$profileId/access'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return List<Map<String, dynamic>>.from(list);
  }

  Future<void> updateAccessLevel(
    String token,
    int profileId,
    int userId,
    String accessLevel,
  ) async {
    await ApiClient.send(
      () => ApiClient.httpClient.patch(
        Uri.parse('$_baseUrl/$profileId/access/$userId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({'access_level': accessLevel}),
      ),
      successCodes: const [200],
    );
  }

  Future<void> updateRelationship(
    String token,
    int profileId,
    int userId,
    String relationship,
  ) async {
    await ApiClient.send(
      () => ApiClient.httpClient.patch(
        Uri.parse('$_baseUrl/$profileId/access/$userId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({'relationship': relationship}),
      ),
      successCodes: const [200],
    );
  }

  Future<void> revokeAccess(String token, int profileId, int userId) async {
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        Uri.parse('$_baseUrl/$profileId/access/$userId'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [204],
    );
  }

  Future<List<InviteModel>> getPendingInvites(String token) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_invitesUrl/pending'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.map((j) => InviteModel.fromJson(j)).toList();
  }

  Future<int> respondToInvite(String token, int inviteId, bool accept) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$_invitesUrl/$inviteId/respond'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({'action': accept ? 'accept' : 'reject'}),
      ),
    );
    return (body['profile_id'] as int?) ?? 0;
  }
}
