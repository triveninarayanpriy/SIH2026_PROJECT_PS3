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
/// Shows a family photo and the name with ONE letter hidden (e.g. "Tri _ eni");
/// the patient picks the missing letter from clickable options. Names come from
/// the labelled family faces the caregiver added.
class NameCompletionGame extends StatefulWidget {
  const NameCompletionGame({super.key, required this.patientId, this.difficulty});

  final String patientId;
  final int? difficulty;

  @override
  State<NameCompletionGame> createState() => _NameCompletionGameState();
}

class _NameCompletionGameState extends State<NameCompletionGame> {
  static const String _game = 'name_completion';

  // Family members with a face and a name of at least 3 letters (so there's a
  // middle letter to hide).
  late final List<FamilyMember> _faces = collectFamily()
      .where((m) => m.hasFace && m.name.trim().runes.length >= 3)
      .toList();

  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];

  @override
  void initState() {
    super.initState();
    if (_faces.isNotEmpty) {
      _difficulty = widget.difficulty ??
          DifficultyEngine.instance
              .startingDifficulty(game: _game, patientId: widget.patientId);
      _rounds = _buildRounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    if (_faces.isEmpty || _rounds.isEmpty) {
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

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  List<GameRound> _buildRounds() {
    final Random rng = Random();
    final int options = max(2, min(4, _difficulty + 1));
    final int roundCount =
        LocalDb.getSetting('gameConfig_name_completion_rounds') as int? ?? 5;

    // Pool of letters seen across all family names, for plausible distractors.
    final Set<String> letterPool = <String>{};
    for (final FamilyMember m in _faces) {
      for (final int r in m.name.trim().runes) {
        final String ch = String.fromCharCode(r);
        if (ch.trim().isNotEmpty) letterPool.add(ch.toUpperCase());
      }
    }

    final List<GameRound> rounds = <GameRound>[];
    int guard = 0;
    while (rounds.length < roundCount && guard < roundCount * 6) {
      guard++;
      final FamilyMember target = _faces[rng.nextInt(_faces.length)];
      final List<String> chars =
          target.name.trim().runes.map((r) => String.fromCharCode(r)).toList();
      // Candidate hide positions: not the first char, not spaces.
      final List<int> positions = <int>[
        for (int i = 1; i < chars.length; i++)
          if (chars[i].trim().isNotEmpty) i,
      ];
      if (positions.isEmpty) continue;
      final int hideIdx = positions[rng.nextInt(positions.length)];
      final String answer = chars[hideIdx].toUpperCase();

      // Distractor letters: other letters from family names, then the alphabet.
      final List<String> distractors = (letterPool.toList()..shuffle(rng))
          .where((c) => c != answer)
          .toList();
      final List<String> alpha = _alphabet.split('')..shuffle(rng);
      for (final String c in alpha) {
        if (distractors.length >= options - 1) break;
        if (c != answer && !distractors.contains(c)) distractors.add(c);
      }
      final List<String> optionLetters = <String>[
        answer,
        ...distractors.take(options - 1),
      ]..shuffle(rng);

      rounds.add(GameRound(
        prompt: 'Complete the name.',
        promptAudioPath:
            LocalDb.mediaByType('game_prompt_faces').firstOrNull?.localPath,
        stimulus: _NameStimulus(
          photo: target.photo,
          chars: chars,
          hideIdx: hideIdx,
        ),
        answerId: answer,
        choices: <GameChoice>[
          for (final String letter in optionLetters)
            GameChoice(
              id: letter,
              label: letter,
              width: 96,
              height: 96,
              content: Text(
                letter,
                style: AppText.gameQuestion(color: AppColors.inkDark),
              ),
            ),
        ],
      ));
    }
    return rounds;
  }
}

/// Photo + the name with one letter shown as a blank box.
class _NameStimulus extends StatelessWidget {
  const _NameStimulus({required this.photo, required this.chars, required this.hideIdx});

  final String? photo;
  final List<String> chars;
  final int hideIdx;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FamilyPhoto(src: photo, size: 160),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (int i = 0; i < chars.length; i++)
              if (chars[i].trim().isEmpty)
                const SizedBox(width: 14)
              else if (i == hideIdx)
                Container(
                  width: 40,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.skyBg.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.ink, width: 2.5),
                  ),
                  child: Text('?',
                      style: AppText.gameQuestion(color: AppColors.ink)),
                )
              else
                Text(
                  chars[i],
                  style: AppText.gameQuestion(color: AppColors.inkDark)
                      .copyWith(letterSpacing: 1),
                ),
          ],
        ),
      ],
    );
  }
}
