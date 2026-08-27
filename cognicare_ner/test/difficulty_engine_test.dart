import 'package:cognicare_ner/core/ai/difficulty_engine.dart';
import 'package:cognicare_ner/core/models/game_result.dart';
import 'package:flutter_test/flutter_test.dart';

GameResult _r(int correct, int total, {DateTime? at}) => GameResult(
      id: 'x',
      patientId: 'p',
      game: 'pattern',
      domain: 'attention',
      correct: correct,
      total: total,
      durationMs: 1000,
      difficulty: 2,
      at: at ?? DateTime(2026),
    );

void main() {
  final DifficultyEngine e = DifficultyEngine.instance;

  test('holds when there is no history', () {
    expect(e.nextDifficulty(const <GameResult>[], 3), 3);
  });

  test('increases when avg accuracy > 0.85 and below max', () {
    expect(e.nextDifficulty(<GameResult>[_r(5, 5), _r(5, 5)], 2), 3);
  });

  test('never exceeds 5', () {
    expect(e.nextDifficulty(<GameResult>[_r(5, 5)], 5), 5);
  });

  test('decreases when avg accuracy < 0.50 and above min', () {
    expect(e.nextDifficulty(<GameResult>[_r(1, 5), _r(1, 5)], 3), 2);
  });

  test('never drops below 1', () {
    expect(e.nextDifficulty(<GameResult>[_r(1, 5)], 1), 1);
  });

  test('holds in the middle band', () {
    expect(e.nextDifficulty(<GameResult>[_r(3, 5)], 2), 2);
  });

  test('uses only the last 5 results by date', () {
    final List<GameResult> recent = <GameResult>[
      for (int i = 0; i < 5; i++) _r(5, 5, at: DateTime(2026, 1, 10 + i)),
      _r(0, 5, at: DateTime(2025)), // old failure, should be ignored
    ];
    expect(e.nextDifficulty(recent, 2), 3);
  });
}
