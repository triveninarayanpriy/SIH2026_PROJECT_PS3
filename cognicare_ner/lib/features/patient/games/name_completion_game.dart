import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ai/difficulty_engine.dart';
import '../../../core/services/local_db.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../l10n/app_localizations.dart';
import 'family.dart';
import 'game_models.dart';
import 'game_shell.dart';

/// Game 1 — Family Name Completion (domain 'language').
///
/// Shows a family photo with the name partly hidden ("K a _ _ l a") and asks
/// the patient to complete it by choosing the full name. Reuses the labelled
/// family faces the caregiver already added — no extra setup needed.
class NameCompletionGame extends StatefulWidget {
  const NameCompletionGame({super.key, required this.patientId, this.difficulty});

  final String patientId;
  final int? difficulty;

  @override
  State<NameCompletionGame> createState() => _NameCompletionGameState();
}

class _NameCompletionGameState extends State<NameCompletionGame> {
  static const String _game = 'name_completion';

  late final List<FamilyMember> _faces =
      collectFamily().where((m) => m.hasFace && m.name.trim().isNotEmpty).toList();

  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];

  @override
  void initState() {
    super.initState();
    if (_faces.length >= 2) {
      _difficulty = widget.difficulty ??
          DifficultyEngine.instance
              .startingDifficulty(game: _game, patientId: widget.patientId);
      _rounds = _buildRounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    if (_faces.length < 2) {
      return AddMoreCard(
        title: t.gameCompleteName,
        message: t.addFamilyPhotos,
      );
    }
    return GameShell(
      title: t.gameCompleteName,
      game: _game,
      domain: 'language',
      difficulty: _difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }

  /// Reveal fewer letters as difficulty rises. Always keeps the first letter.
  String _mask(String name, int difficulty) {
    final List<String> chars = name.split('');
    if (chars.length <= 2) return name;
    // difficulty 1 -> keep first+last; higher -> keep only first.
    final bool keepLast = difficulty <= 2;
    final List<String> out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (chars[i] == ' ') {
        out.add(' ');
      } else if (i == 0 || (keepLast && i == chars.length - 1)) {
        out.add(chars[i]);
      } else {
        out.add('_');
      }
    }
    return out.join(' ');
  }

  List<GameRound> _buildRounds() {
    final Random rng = Random();
    final int options = min(_faces.length, max(2, min(4, _difficulty + 1)));
    final int roundCount =
        LocalDb.getSetting('gameConfig_name_completion_rounds') as int? ?? 5;

    final List<GameRound> rounds = <GameRound>[];
    for (int i = 0; i < roundCount; i++) {
      final FamilyMember target = _faces[rng.nextInt(_faces.length)];
      final List<FamilyMember> others =
          _faces.where((m) => m.name != target.name).toList()..shuffle(rng);
      final List<FamilyMember> picks = <FamilyMember>[
        target,
        ...others.take(options - 1),
      ]..shuffle(rng);

      rounds.add(GameRound(
        prompt: 'Who is this? Complete the name.',
        promptAudioPath:
            LocalDb.mediaByType('game_prompt_faces').firstOrNull?.localPath,
        stimulus: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FamilyPhoto(src: target.photo, size: 220),
            const SizedBox(height: 16),
            Text(
              _mask(target.name, _difficulty),
              textAlign: TextAlign.center,
              style: AppText.gameQuestion(color: AppColors.primaryDark)
                  .copyWith(letterSpacing: 2),
            ),
          ],
        ),
        answerId: target.name,
        choices: <GameChoice>[
          for (final FamilyMember m in picks)
            GameChoice(
              id: m.name,
              label: m.name,
              content: Text(m.name, textAlign: TextAlign.center, style: AppText.button()),
            ),
        ],
      ));
    }
    return rounds;
  }
}
