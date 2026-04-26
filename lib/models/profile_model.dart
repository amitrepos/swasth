import '../utils/datetime_utils.dart';

class ProfileModel {
  final int id;
  final String name;
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;
  final String? bloodGroup;
  final List<String>? medicalConditions;
  final String? otherMedicalCondition;
  final String? medications;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorWhatsapp;
  final String phoneNumber;
  final String accessLevel; // "owner" or "viewer"
  final String? relationship;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProfileModel({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.bloodGroup,
    this.medicalConditions,
    this.otherMedicalCondition,
    this.medications,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorWhatsapp,
    required this.phoneNumber,
    required this.accessLevel,
    this.relationship,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      gender: json['gender'],
      height: json['height']?.toDouble(),
      weight: json['weight']?.toDouble(),
      bloodGroup: json['blood_group'],
      medicalConditions: json['medical_conditions'] != null
          ? List<String>.from(json['medical_conditions'])
          : null,
      otherMedicalCondition: json['other_medical_condition'],
      medications: json['current_medications'],
      doctorName: json['doctor_name'] as String?,
      doctorSpecialty: json['doctor_specialty'] as String?,
      doctorWhatsapp: json['doctor_whatsapp'] as String?,
      phoneNumber: json['phone_number'] as String,
      accessLevel: json['access_level'],
      relationship: json['relationship'] as String?,
      createdAt: DateTimeUtils.parseUtc(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTimeUtils.parseUtc(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'blood_group': bloodGroup,
      'medical_conditions': medicalConditions,
      'other_medical_condition': otherMedicalCondition,
      'current_medications': medications,
      'doctor_name': doctorName,
      'doctor_specialty': doctorSpecialty,
      'doctor_whatsapp': doctorWhatsapp,
      'phone_number': phoneNumber,
      'access_level': accessLevel,
      'relationship': relationship,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
