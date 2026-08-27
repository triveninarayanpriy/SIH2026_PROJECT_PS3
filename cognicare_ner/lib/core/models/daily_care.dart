import 'package:hive/hive.dart';

import 'model_utils.dart';

part 'daily_care.g.dart';

/// One day's care log. Stored under `patients/{patientId}/dailyCare/{date}`
/// and keyed locally by [date].
@HiveType(typeId: 4)
class DailyCare {
  DailyCare({
    required this.date,
    required this.medsTaken,
    required this.hydrationCount,
    required this.mealsLogged,
  });

  /// 'yyyy-MM-dd' — also the document/box key.
  @HiveField(0)
  final String date;

  @HiveField(1)
  final List<String> medsTaken;

  @HiveField(2)
  final int hydrationCount;

  @HiveField(3)
  final List<String> mealsLogged;

  Map<String, dynamic> toMap() => {
        'date': date,
        'medsTaken': medsTaken,
        'hydrationCount': hydrationCount,
        'mealsLogged': mealsLogged,
      };

  factory DailyCare.fromMap(Map<String, dynamic> map) => DailyCare(
        date: (map['date'] as String?) ?? '',
        medsTaken: stringList(map['medsTaken']),
        hydrationCount: (map['hydrationCount'] as num?)?.toInt() ?? 0,
        mealsLogged: stringList(map['mealsLogged']),
      );
}
