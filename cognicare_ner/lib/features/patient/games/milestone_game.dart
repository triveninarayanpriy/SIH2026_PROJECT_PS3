import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ai/difficulty_engine.dart';
import '../../../core/services/game_content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/platform_media.dart';
import 'family.dart';
import 'game_models.dart';
import 'game_shell.dart';

/// Game 2 — Milestone & Life Events Recall (domain 'memory', episodic).
///
/// For each caregiver-authored life event it shows the photo, tells the story
/// (the caregiver's own recording if present, else TTS), and asks a question
/// with the real answer among gentle distractors.
class MilestoneGame extends StatefulWidget {
  const MilestoneGame({super.key, required this.patientId, this.difficulty});

  final String patientId;
  final int? difficulty;

  @override
  State<MilestoneGame> createState() => _MilestoneGameState();
}

class _MilestoneGameState extends State<MilestoneGame> {
  static const String _game = 'milestone';

  late final List<Milestone> _milestones =
      GameContent.milestones().where((m) => m.answer.trim().isNotEmpty).toList();
  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];

  @override
  void initState() {
    super.initState();
    if (_milestones.isNotEmpty) {
      _difficulty = widget.difficulty ??
          DifficultyEngine.instance
              .startingDifficulty(game: _game, patientId: widget.patientId);
      _rounds = _buildRounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_milestones.isEmpty) {
      return const AddMoreCard(
        title: 'Do you remember?',
        message: 'Ask your family to add a few special memories to recall.',
      );
    }
    return GameShell(
      title: 'Do you remember?',
      game: _game,
      domain: 'memory',
      difficulty: _difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }

  List<GameRound> _buildRounds() {
    final Random rng = Random();
    final List<Milestone> order = List<Milestone>.of(_milestones)..shuffle(rng);
    final int options = max(2, min(4, _difficulty + 1));

    final List<GameRound> rounds = <GameRound>[];
    for (final Milestone m in order) {
      final List<String> distractors = List<String>.of(m.distractors)..shuffle(rng);
      final List<String> optionLabels = <String>{
        m.answer,
        ...distractors.take(options - 1),
      }.toList()
        ..shuffle(rng);

      final String spoken =
          m.story.trim().isEmpty ? m.question : '${m.story}  ${m.question}';

      rounds.add(GameRound(
        prompt: spoken,
        promptAudioPath: m.audioSrc.isNotEmpty ? m.audioSrc : null,
        stimulus: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (m.imageSrc.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: MediaImage(
                  src: m.imageSrc,
                  width: 260,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            if (m.story.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                m.story,
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        answerId: m.answer,
        choices: <GameChoice>[
          for (final String label in optionLabels)
            GameChoice(
              id: label,
              label: label,
              content: Text(label, textAlign: TextAlign.center, style: AppText.button()),
            ),
        ],
      ));
    }
    return rounds;
  }
}
