import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ai/difficulty_engine.dart';
import '../../../core/theme/app_text.dart';
import 'family.dart';
import 'game_models.dart';
import 'game_shell.dart';

/// Game 2 — Family Member Recognition (domain 'memory').
///
/// Shows one family photo large and asks "Who is this?"; name tiles are built
/// from the labelled family faces. Falls back to a friendly card when fewer
/// than two labelled faces exist.
class FamilyGame extends StatefulWidget {
  const FamilyGame({super.key, required this.patientId, this.difficulty});

  final String patientId;

  /// Explicit difficulty (for tests/preview); null → adaptive from history.
  final int? difficulty;

  @override
  State<FamilyGame> createState() => _FamilyGameState();
}

class _FamilyGameState extends State<FamilyGame> {
  static const String _game = 'faces';

  late final List<FamilyMember> _faces =
      collectFamily().where((m) => m.hasFace).toList();

  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];

  @override
  void initState() {
    super.initState();
    // Only resolve/persist difficulty when there's actually a session to play.
    if (_faces.length >= 2) {
      _difficulty = widget.difficulty ??
          DifficultyEngine.instance
              .startingDifficulty(game: _game, patientId: widget.patientId);
      _rounds = _buildRounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_faces.length < 2) {
      return const AddMoreCard(
        title: 'Who is this?',
        message: 'Ask your family to add photos of family members.',
      );
    }
    return GameShell(
      title: 'Who is this?',
      game: _game,
      domain: 'memory',
      difficulty: _difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }

  List<GameRound> _buildRounds() {
    final Random rng = Random();
    // difficulty scales the number of options (2..4), capped by how many faces
    // exist — more options = harder recall.
    final int options =
        min(_faces.length, max(2, min(4, _difficulty + 1)));

    final List<GameRound> rounds = <GameRound>[];
    for (int i = 0; i < 5; i++) {
      final FamilyMember target = _faces[rng.nextInt(_faces.length)];
      final List<FamilyMember> others =
          _faces.where((m) => m.name != target.name).toList()..shuffle(rng);
      final List<FamilyMember> picks = <FamilyMember>[
        target,
        ...others.take(options - 1),
      ]..shuffle(rng);

      rounds.add(GameRound(
        prompt: 'Who is this?',
        // No name on the stimulus placeholder so it never reveals the answer.
        stimulus: FamilyPhoto(src: target.photo, size: 240),
        answerId: target.name,
        choices: [
          for (final FamilyMember m in picks)
            GameChoice(
              id: m.name,
              label: m.name,
              content: Text(
                m.name,
                textAlign: TextAlign.center,
                style: AppText.button(),
              ),
            ),
        ],
      ));
    }
    return rounds;
  }
}
