import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ai/difficulty_engine.dart';
import '../../../core/theme/app_text.dart';
import 'audio_play_button.dart';
import 'family.dart';
import 'game_models.dart';
import 'game_shell.dart';

/// Game 3 — Voice / Sound Recognition (domain 'auditory').
///
/// Plays a family voice clip and asks "Whose voice is this?"; big face tiles are
/// the answers. Requires at least two family members that have both a labelled
/// face and a playable voice clip; otherwise a friendly card is shown.
class VoiceGame extends StatefulWidget {
  const VoiceGame({super.key, required this.patientId, this.difficulty});

  final String patientId;

  /// Explicit difficulty (for tests/preview); null → adaptive from history.
  final int? difficulty;

  @override
  State<VoiceGame> createState() => _VoiceGameState();
}

class _VoiceGameState extends State<VoiceGame> {
  static const String _game = 'voice';

  late final List<FamilyMember> _members =
      collectFamily().where((m) => m.hasFace && m.voice != null).toList();

  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];

  @override
  void initState() {
    super.initState();
    if (_members.length >= 2) {
      _difficulty = widget.difficulty ??
          DifficultyEngine.instance
              .startingDifficulty(game: _game, patientId: widget.patientId);
      _rounds = _buildRounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_members.length < 2) {
      return const AddMoreCard(
        title: 'Whose voice is this?',
        message: 'Ask your family to add photos and voice recordings.',
      );
    }
    return GameShell(
      title: 'Whose voice is this?',
      game: _game,
      domain: 'auditory',
      difficulty: _difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }

  List<GameRound> _buildRounds() {
    final Random rng = Random();
    final int options =
        min(_members.length, max(2, min(4, _difficulty + 1)));

    final List<GameRound> rounds = <GameRound>[];
    for (int i = 0; i < 5; i++) {
      final FamilyMember target = _members[rng.nextInt(_members.length)];
      final List<FamilyMember> others =
          _members.where((m) => m.name != target.name).toList()..shuffle(rng);
      final List<FamilyMember> picks = <FamilyMember>[
        target,
        ...others.take(options - 1),
      ]..shuffle(rng);

      rounds.add(GameRound(
        prompt: 'Whose voice is this?',
        stimulus: AudioPlayButton(src: target.voice!),
        answerId: target.name,
        choices: [
          for (final FamilyMember m in picks)
            GameChoice(
              id: m.name,
              width: 150,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FamilyPhoto(src: m.photo, name: m.name, size: 84),
                  const SizedBox(height: 8),
                  Text(
                    m.name,
                    textAlign: TextAlign.center,
                    style: AppText.body().copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
        ],
      ));
    }
    return rounds;
  }
}
