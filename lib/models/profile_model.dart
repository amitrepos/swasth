class ProfileModel {
  final int id;
  final String name;
  final int? age;
  final String? gender;
  final double? height;
  final String? bloodGroup;
  final List<String>? medicalConditions;
  final String? otherMedicalCondition;
  final String? medications;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorWhatsapp;
  final String accessLevel; // "owner" or "viewer"
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProfileModel({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.height,
    this.bloodGroup,
    this.medicalConditions,
    this.otherMedicalCondition,
    this.medications,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorWhatsapp,
    required this.accessLevel,
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
      bloodGroup: json['blood_group'],
      medicalConditions: json['medical_conditions'] != null
          ? List<String>.from(json['medical_conditions'])
          : null,
      otherMedicalCondition: json['other_medical_condition'],
      medications: json['current_medications'],
      doctorName: json['doctor_name'] as String?,
      doctorSpecialty: json['doctor_specialty'] as String?,
      doctorWhatsapp: json['doctor_whatsapp'] as String?,
      accessLevel: json['access_level'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
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
      'blood_group': bloodGroup,
      'medical_conditions': medicalConditions,
      'other_medical_condition': otherMedicalCondition,
      'current_medications': medications,
      'access_level': accessLevel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
