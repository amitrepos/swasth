class InviteModel {
  final int id;
  final int profileId;
  final String profileName;
  final String invitedByName;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  InviteModel({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.invitedByName,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      id: json['id'],
      profileId: json['profile_id'],
      profileName: json['profile_name'],
      invitedByName: json['invited_by_name'],
      status: json['status'],
      expiresAt: DateTime.parse(json['expires_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'profile_name': profileName,
      'invited_by_name': invitedByName,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
