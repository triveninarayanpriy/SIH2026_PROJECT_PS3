import 'dart:math';

import 'package:flutter/material.dart';

import 'game_models.dart';
import 'game_shell.dart';

/// Everyday items used by the pattern game — clear icons + plain labels.
const List<GameItem> kPatternItems = <GameItem>[
  GameItem(id: 'cup', label: 'Cup', icon: Icons.local_cafe_rounded),
  GameItem(id: 'glass', label: 'Glass', icon: Icons.local_drink_rounded),
  GameItem(id: 'ball', label: 'Ball', icon: Icons.sports_soccer_rounded),
  GameItem(id: 'star', label: 'Star', icon: Icons.star_rounded),
  GameItem(id: 'flower', label: 'Flower', icon: Icons.local_florist_rounded),
  GameItem(id: 'sun', label: 'Sun', icon: Icons.wb_sunny_rounded),
  GameItem(id: 'heart', label: 'Heart', icon: Icons.favorite_rounded),
  GameItem(id: 'house', label: 'House', icon: Icons.home_rounded),
  GameItem(id: 'car', label: 'Car', icon: Icons.directions_car_rounded),
  GameItem(id: 'cake', label: 'Cake', icon: Icons.cake_rounded),
];

/// Builds [rounds] pattern-recognition rounds, scaled by [difficulty]:
///   * sequence length  3 → 7   (difficulty 1 → 5)
///   * pattern period    2 (or 3 at difficulty ≥ 4)
///   * answer tiles      2 (or 3 at difficulty ≥ 3)  → distractors scale
List<GameRound> buildPatternRounds({
  required int difficulty,
  int rounds = 5,
  Random? random,
}) {
  final Random rng = random ?? Random();
  final int seqLen = max(3, min(7, difficulty + 2));
  final int period = difficulty >= 4 ? 3 : 2;
  final int numChoices = difficulty >= 3 ? 3 : 2;

  final List<GameRound> out = <GameRound>[];
  for (int i = 0; i < rounds; i++) {
    final List<GameItem> pool = List<GameItem>.of(kPatternItems)..shuffle(rng);
    final List<GameItem> pattern = pool.take(period).toList();

    final List<GameItem> sequence = <GameItem>[
      for (int k = 0; k < seqLen; k++) pattern[k % period],
    ];
    final GameItem correct = pattern[seqLen % period];

    // Distractors: the pattern's other items first (plausible), then the pool.
    final List<GameItem> candidates = <GameItem>[
      ...pattern.where((it) => it.id != correct.id),
      ...pool.skip(period).where((it) => it.id != correct.id),
    ]..shuffle(rng);

    final List<GameItem> distractors = <GameItem>[];
    for (final GameItem c in candidates) {
      if (distractors.length >= numChoices - 1) break;
      if (distractors.every((d) => d.id != c.id)) distractors.add(c);
    }

    final List<GameItem> choices = <GameItem>[correct, ...distractors]
      ..shuffle(rng);

    out.add(GameRound(
      prompt: 'What comes next?',
      sequence: sequence,
      choices: choices,
      answerId: correct.id,
    ));
  }
  return out;
}

/// Launches the pattern game: builds the rounds once, then runs [GameShell].
class PatternGame extends StatefulWidget {
  const PatternGame({
    super.key,
    required this.patientId,
    this.difficulty = 2,
  });

  final String patientId;
  final int difficulty;

  @override
  State<PatternGame> createState() => _PatternGameState();
}

class _PatternGameState extends State<PatternGame> {
  late final List<GameRound> _rounds =
      buildPatternRounds(difficulty: widget.difficulty);

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'What comes next?',
      game: 'pattern',
      domain: 'attention',
      difficulty: widget.difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }
}
