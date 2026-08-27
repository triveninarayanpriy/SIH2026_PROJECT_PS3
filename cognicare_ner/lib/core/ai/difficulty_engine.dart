import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/game_result.dart';
import '../services/local_db.dart';
import 'ai_service.dart';

/// Result of a Tier-2 refinement: a difficulty and where it came from.
class DifficultySuggestion {
  const DifficultySuggestion({
    required this.difficulty,
    required this.source,
    this.note,
  });

  final int difficulty;

  /// 'tier1' (on-device rule) or 'tier2' (AI-refined).
  final String source;

  /// One-line caregiver note (Tier 2 only).
  final String? note;
}

/// Adaptive difficulty engine.
///
/// Tier 1 (always used, offline): a simple accuracy rule over the last up-to-5
/// results, persisted per game so difficulty resumes across sessions.
/// Tier 2 (optional, online): an AI refinement that can nudge the level by one
/// and add a caregiver note; it fails gracefully back to Tier 1.
class DifficultyEngine {
  DifficultyEngine._();

  static final DifficultyEngine instance = DifficultyEngine._();

  static const int minDifficulty = 1;
  static const int maxDifficulty = 5;
  static const int defaultDifficulty = 2;

  int _clamp(int v) =>
      v < minDifficulty ? minDifficulty : (v > maxDifficulty ? maxDifficulty : v);

  /// Tier 1 rule. Pure and offline — always used.
  ///
  /// avg accuracy of the last up-to-5 results:
  ///   * > 0.85 and current < 5  -> current + 1
  ///   * < 0.50 and current > 1  -> current - 1
  ///   * else hold. Clamped 1..5.
  int nextDifficulty(List<GameResult> recentForThisGame, int current) {
    if (recentForThisGame.isEmpty) return _clamp(current);
    final List<GameResult> sorted = [...recentForThisGame]
      ..sort((a, b) => b.at.compareTo(a.at));
    final List<GameResult> last = sorted.take(5).toList();
    final double avg =
        last.map((r) => r.accuracy).reduce((a, b) => a + b) / last.length;

    if (avg > 0.85 && current < maxDifficulty) return _clamp(current + 1);
    if (avg < 0.50 && current > minDifficulty) return _clamp(current - 1);
    return _clamp(current);
  }

  /// Recent results for [game] and [patientId], newest first.
  List<GameResult> _recent(String game, String patientId) {
    return LocalDb.sessionsForPatient(patientId)
        .where((r) => r.game == game)
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
  }

  /// Computes AND persists the starting difficulty for the next session (Tier 1).
  int startingDifficulty({required String game, required String patientId}) {
    final int current =
        LocalDb.gameDifficulty(game, fallback: defaultDifficulty);
    final int next = nextDifficulty(_recent(game, patientId), current);
    LocalDb.setGameDifficulty(game, next); // persist for resume
    return next;
  }

  /// Tier 2 online refinement (optional).
  ///
  /// When online, asks [AiService] for a suggestion; if the AI disagrees with
  /// [ruleDifficulty] by exactly one level, the AI value is preferred. Falls
  /// back to Tier 1 when offline or on any error.
  Future<DifficultySuggestion> refine({
    required String game,
    required String patientId,
    required int ruleDifficulty,
  }) async {
    try {
      final bool online = (await Connectivity().checkConnectivity())
          .any((r) => r != ConnectivityResult.none);
      if (!online) {
        return DifficultySuggestion(
            difficulty: _clamp(ruleDifficulty), source: 'tier1');
      }

      final List<double> recent = _recent(game, patientId)
          .take(5)
          .map((r) => r.accuracy)
          .toList();
      final AiDifficultyResult ai = await AiService.instance.suggestDifficulty(
        game: game,
        current: ruleDifficulty,
        recentAccuracies: recent,
      );

      int chosen = ruleDifficulty;
      if ((ai.difficulty - ruleDifficulty).abs() == 1) {
        chosen = ai.difficulty; // prefer AI when it disagrees by one level
      }
      return DifficultySuggestion(
        difficulty: _clamp(chosen),
        source: 'tier2',
        note: ai.note,
      );
    } catch (_) {
      return DifficultySuggestion(
          difficulty: _clamp(ruleDifficulty), source: 'tier1');
    }
  }
}
