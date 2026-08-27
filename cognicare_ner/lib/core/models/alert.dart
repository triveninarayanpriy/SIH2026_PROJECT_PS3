import 'package:hive/hive.dart';

import 'model_utils.dart';

part 'alert.g.dart';

/// An anomaly / early-warning alert. Stored under
/// `patients/{patientId}/alerts`.
@HiveType(typeId: 5)
class Alert {
  Alert({
    required this.id,
    required this.patientId,
    required this.type,
    required this.domain,
    required this.deltaPct,
    required this.at,
    required this.seen,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  /// Currently always 'cognitive_drop'.
  @HiveField(2)
  final String type;

  @HiveField(3)
  final String domain;

  /// Relative drop vs baseline, as a percentage (e.g. 22.0 for a 22% drop).
  @HiveField(4)
  final double deltaPct;

  @HiveField(5)
  final DateTime at;

  @HiveField(6)
  final bool seen;

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'type': type,
        'domain': domain,
        'deltaPct': deltaPct,
        'at': at.toIso8601String(),
        'seen': seen,
      };

  factory Alert.fromMap(Map<String, dynamic> map) => Alert(
        id: (map['id'] as String?) ?? '',
        patientId: (map['patientId'] as String?) ?? '',
        type: (map['type'] as String?) ?? 'cognitive_drop',
        domain: (map['domain'] as String?) ?? '',
        deltaPct: (map['deltaPct'] as num?)?.toDouble() ?? 0,
        at: parseDate(map['at']),
        seen: (map['seen'] as bool?) ?? false,
      );
}
