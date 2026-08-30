import 'package:hive/hive.dart';

import 'model_utils.dart';

part 'patient_profile.g.dart';

/// A patient's core profile. One document per patient (`patients/{id}`).
@HiveType(typeId: 0)
class PatientProfile {
  PatientProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.stage,
    required this.languages,
    required this.region,
    required this.createdAt,
    this.clinicalNotes,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int age;

  /// Dementia stage, 1..5.
  @HiveField(3)
  final int stage;

  @HiveField(4)
  final List<String> languages;

  @HiveField(5)
  final String region;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final String? clinicalNotes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'stage': stage,
        'languages': languages,
        'region': region,
        'createdAt': createdAt.toIso8601String(),
        'clinicalNotes': clinicalNotes,
      };

  factory PatientProfile.fromMap(Map<String, dynamic> map) => PatientProfile(
        id: (map['id'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        age: (map['age'] as num?)?.toInt() ?? 0,
        stage: (map['stage'] as num?)?.toInt() ?? 1,
        languages: stringList(map['languages']),
        region: (map['region'] as String?) ?? '',
        createdAt: parseDate(map['createdAt']),
        clinicalNotes: map['clinicalNotes'] as String?,
      );
}
