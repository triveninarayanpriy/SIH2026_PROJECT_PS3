import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ai/difficulty_engine.dart';
import '../../../core/services/game_content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/platform_media.dart';
import '../../../l10n/app_localizations.dart';
import 'family.dart';
import 'game_models.dart';
import 'game_shell.dart';

/// Game 3 — Daily Routine Sequencing (domain 'executive').
///
/// The caregiver defines the patient's daily routine in order. Each round shows
/// the steps done so far and asks "What comes next?" — a gentle way to exercise
/// sequencing without drag-and-drop, and it maps cleanly onto the remote's
/// number keys.
class RoutineGame extends StatefulWidget {
  const RoutineGame({super.key, required this.patientId, this.difficulty});

  final String patientId;
  final int? difficulty;

  @override
  State<RoutineGame> createState() => _RoutineGameState();
}

class _RoutineGameState extends State<RoutineGame> {
  static const String _game = 'routine';

  late final List<RoutineStep> _steps = GameContent.routine();
  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];

  @override
  void initState() {
    super.initState();
    if (_steps.length >= 3) {
      _difficulty = widget.difficulty ??
          DifficultyEngine.instance
              .startingDifficulty(game: _game, patientId: widget.patientId);
      _rounds = _buildRounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    if (_steps.length < 3) {
      return AddMoreCard(
        title: t.whatComesNext,
        message: 'Ask your family to set up the daily routine (at least 3 steps).',
      );
    }
    return GameShell(
      title: t.whatComesNext,
      game: _game,
      domain: 'executive',
      difficulty: _difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }

  List<GameRound> _buildRounds() {
    final Random rng = Random();
    final int options = max(2, min(4, _difficulty + 1));
    final List<GameRound> rounds = <GameRound>[];

    // First round asks what comes first; each later round: given steps[0..i-1],
    // pick steps[i].
    for (int i = 0; i < _steps.length; i++) {
      final RoutineStep correct = _steps[i];
      final List<RoutineStep> distractors =
          _steps.where((s) => s.id != correct.id).toList()..shuffle(rng);
      final List<RoutineStep> picks = <RoutineStep>[
        correct,
        ...distractors.take(options - 1),
      ]..shuffle(rng);

      final List<RoutineStep> done = _steps.sublist(0, i);

      rounds.add(GameRound(
        prompt: done.isEmpty
            ? 'What comes first?'
            : 'After ${done.last.label}, what comes next?',
        stimulus: _DoneStrip(done: done),
        answerId: correct.id,
        choices: <GameChoice>[
          for (final RoutineStep s in picks)
            GameChoice(
              id: s.id,
              label: s.label,
              content: _StepChip(step: s),
            ),
        ],
      ));
    }
    return rounds;
  }
}

/// Horizontal strip of the routine steps completed so far.
class _DoneStrip extends StatelessWidget {
  const _DoneStrip({required this.done});
  final List<RoutineStep> done;

  @override
  Widget build(BuildContext context) {
    if (done.isEmpty) {
      // "What comes first?" — a friendly start marker.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.wb_sunny_rounded, size: 64, color: AppColors.gentleWarning),
          SizedBox(height: 8),
          Icon(Icons.help_outline_rounded, size: 40, color: AppColors.primary),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (int i = 0; i < done.length; i++) ...<Widget>[
          _StepChip(step: done[i], muted: true),
          if (i < done.length - 1)
            const Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted),
        ],
        const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
        const Icon(Icons.help_outline_rounded, size: 40, color: AppColors.primary),
      ],
    );
  }
}

/// A single routine step tile: optional image + label.
class _StepChip extends StatelessWidget {
  const _StepChip({required this.step, this.muted = false});
  final RoutineStep step;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (step.imageSrc.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MediaImage(
              src: step.imageSrc,
              width: muted ? 56 : 88,
              height: muted ? 56 : 88,
              fit: BoxFit.cover,
            ),
          )
        else
          Icon(Icons.schedule_rounded,
              size: muted ? 40 : 64, color: AppColors.secondary),
        const SizedBox(height: 6),
        SizedBox(
          width: muted ? 72 : 110,
          child: Text(
            step.label,
            textAlign: TextAlign.center,
            style: (muted ? AppText.body(color: AppColors.textMuted) : AppText.button())
                .copyWith(fontSize: muted ? 13 : 18),
          ),
        ),
      ],
    );
  }
}
