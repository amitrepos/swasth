import '../utils/datetime_utils.dart';

class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final String bloodGroup;
  final String? currentMedications;
  final List<String> medicalConditions;
  final String? otherMedicalCondition;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.bloodGroup,
    this.currentMedications,
    required this.medicalConditions,
    this.otherMedicalCondition,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      age: json['age'],
      gender: json['gender'],
      height: json['height'].toDouble(),
      weight: json['weight'].toDouble(),
      bloodGroup: json['blood_group'],
      currentMedications: json['current_medications'],
      medicalConditions: List<String>.from(json['medical_conditions'] ?? []),
      otherMedicalCondition: json['other_medical_condition'],
      createdAt: DateTimeUtils.parseUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'blood_group': bloodGroup,
      'current_medications': currentMedications,
      'medical_conditions': medicalConditions,
      'other_medical_condition': otherMedicalCondition,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
