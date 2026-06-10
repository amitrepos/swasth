// Medication intake data model — mirrors backend Medication schemas (NUO-127).
// Related: backend/schemas.py (MedicationCreate/Update/Response), backend/models.py (Medication)

import '../utils/datetime_utils.dart';

class Medication {
  final int id;
  final int profileId;
  final int? loggedBy;
  final String name;
  final String? dose;
  final String? frequency;
  final String intakePeriod;
  final DateTime takenAt;
  final String? notes;
  final bool hasPhoto;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.profileId,
    this.loggedBy,
    required this.name,
    this.dose,
    this.frequency,
    required this.intakePeriod,
    required this.takenAt,
    this.notes,
    this.hasPhoto = false,
    required this.createdAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as int,
      profileId: json['profile_id'] as int,
      loggedBy: json['logged_by'] as int?,
      name: json['name'] as String,
      dose: json['dose'] as String?,
      frequency: json['frequency'] as String?,
      intakePeriod: json['intake_period'] as String? ?? 'MORNING',
      takenAt: DateTimeUtils.parseUtc(json['taken_at']),
      notes: json['notes'] as String?,
      hasPhoto: json['has_photo'] as bool? ?? false,
      createdAt: DateTimeUtils.parseUtc(json['created_at']),
    );
  }
}

/// Payload for POST /api/medications.
class MedicationCreate {
  final int profileId;
  final String name;
  final String? dose;
  final String? frequency;
  final String intakePeriod;
  final DateTime takenAt;
  final String? notes;

  MedicationCreate({
    required this.profileId,
    required this.name,
    this.dose,
    this.frequency,
    required this.intakePeriod,
    required this.takenAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'name': name,
    if (dose != null && dose!.isNotEmpty) 'dose': dose,
    if (frequency != null && frequency!.isNotEmpty) 'frequency': frequency,
    'intake_period': intakePeriod,
    'taken_at': takenAt.toUtc().toIso8601String(),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}

/// Payload for PATCH /api/medications/{id}.
///
/// All fields are optional; only provided fields are updated.
class MedicationUpdate {
  final String? name;
  final String? dose;
  final String? frequency;
  final String? intakePeriod;
  final DateTime? takenAt;
  final String? notes;

  MedicationUpdate({
    this.name,
    this.dose,
    this.frequency,
    this.intakePeriod,
    this.takenAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (dose != null) 'dose': dose,
    if (frequency != null) 'frequency': frequency,
    if (intakePeriod != null) 'intake_period': intakePeriod,
    if (takenAt != null) 'taken_at': takenAt!.toUtc().toIso8601String(),
    if (notes != null) 'notes': notes,
  };
}
