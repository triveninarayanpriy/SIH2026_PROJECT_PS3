import 'package:hive/hive.dart';

import 'model_utils.dart';

part 'game_result.g.dart';

/// The uniform result object every cognitive game produces. Stored under
/// `patients/{patientId}/sessions`. Powers the AI difficulty engine, the
/// progress charts, and the anomaly detector.
@HiveType(typeId: 3)
class GameResult {
  GameResult({
    required this.id,
    required this.patientId,
    required this.game,
    required this.domain,
    required this.correct,
    required this.total,
    required this.durationMs,
    required this.difficulty,
    required this.at,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  /// e.g. 'pattern' | 'faces' | 'voice'
  @HiveField(2)
  final String game;

  /// e.g. 'attention' | 'memory' | 'recognition'
  @HiveField(3)
  final String domain;

  @HiveField(4)
  final int correct;

  @HiveField(5)
  final int total;

  @HiveField(6)
  final int durationMs;

  /// AI-assigned difficulty, 1..5.
  @HiveField(7)
  final int difficulty;

  @HiveField(8)
  final DateTime at;

  double get accuracy => total == 0 ? 0 : correct / total;

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'game': game,
        'domain': domain,
        'correct': correct,
        'total': total,
        'durationMs': durationMs,
        'difficulty': difficulty,
        'at': at.toIso8601String(),
        'accuracy': accuracy,
      };

  factory GameResult.fromMap(Map<String, dynamic> map) => GameResult(
        id: (map['id'] as String?) ?? '',
        patientId: (map['patientId'] as String?) ?? '',
        game: (map['game'] as String?) ?? '',
        domain: (map['domain'] as String?) ?? '',
        correct: (map['correct'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
        difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
        at: parseDate(map['at']),
      );
}
