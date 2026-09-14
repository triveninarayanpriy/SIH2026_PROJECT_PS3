import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ai/difficulty_engine.dart';
import '../../../core/services/local_db.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../l10n/app_localizations.dart';
import 'game_models.dart';
import 'game_shell.dart';

/// Geometric shapes and colors often used in clinical cognitive assessments (e.g. MoCA, MMSE).
const List<GameItem> kPatternItems = <GameItem>[
  GameItem(id: 'blue_square', label: 'Blue Square', icon: Icons.square_rounded, color: Colors.blue),
  GameItem(id: 'red_circle', label: 'Red Circle', icon: Icons.circle, color: Colors.red),
  GameItem(id: 'green_triangle', label: 'Green Triangle', icon: Icons.change_history_rounded, color: Colors.green),
  GameItem(id: 'orange_star', label: 'Orange Star', icon: Icons.star_rounded, color: Colors.orange),
  GameItem(id: 'purple_diamond', label: 'Purple Diamond', icon: Icons.diamond_rounded, color: Colors.purple),
  GameItem(id: 'teal_hexagon', label: 'Teal Hexagon', icon: Icons.hexagon_rounded, color: Colors.teal),
  GameItem(id: 'yellow_circle', label: 'Yellow Circle', icon: Icons.circle, color: Colors.amber),
  GameItem(id: 'pink_square', label: 'Pink Square', icon: Icons.square_rounded, color: Colors.pink),
  GameItem(id: 'brown_triangle', label: 'Brown Triangle', icon: Icons.change_history_rounded, color: Colors.brown),
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

    final List<GameItem> candidates = <GameItem>[
      ...pattern.where((it) => it.id != correct.id),
      ...pool.skip(period).where((it) => it.id != correct.id),
    ]..shuffle(rng);

    final List<GameItem> distractors = <GameItem>[];
    for (final GameItem c in candidates) {
      if (distractors.length >= numChoices - 1) break;
      if (distractors.every((d) => d.id != c.id)) distractors.add(c);
    }

    final List<GameItem> answerItems = <GameItem>[correct, ...distractors]
      ..shuffle(rng);

    final Widget stimulus = _PatternSequence(sequence: sequence);

    out.add(GameRound(
      prompt: 'What comes next?',
      promptAudioPath: LocalDb.mediaByType('game_prompt_pattern').firstOrNull?.localPath,
      stimulus: stimulus,
      answerId: correct.id,
      choices: [
        for (final GameItem it in answerItems)
          GameChoice(
            id: it.id,
            label: it.label,
            width: 128,
            height: 128,
            content: _PatternShape(item: it, size: 56, showLabel: true),
          ),
      ],
    ));
  }
  return out;
}

/// A single bold, solid shape (no clinical-looking outline icons) plus optional
/// label — much clearer for elderly eyes than a small icon.
class _PatternShape extends StatelessWidget {
  const _PatternShape({required this.item, this.size = 48, this.showLabel = false});

  final GameItem item;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final Color color = item.color ?? AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(item.icon, size: size, color: color),
        if (showLabel) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: AppText.body().copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// The stimulus sequence: a horizontally-scrollable row of bold shape cards that
/// always ends with a clear, highlighted "?" card — no wrapping, no overlap.
class _PatternSequence extends StatelessWidget {
  const _PatternSequence({required this.sequence});

  final List<GameItem> sequence;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final GameItem it in sequence)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _cell(child: _PatternShape(item: it, size: 44)),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted),
          ),
          _cell(
            highlight: true,
            child: const Icon(Icons.help_outline_rounded,
                size: 40, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _cell({required Widget child, bool highlight = false}) {
    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? AppColors.primary : AppColors.border,
          width: highlight ? 2.5 : 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// Launches the pattern game: resolves the adaptive difficulty, builds the
/// rounds once, then runs [GameShell].
class PatternGame extends StatefulWidget {
  const PatternGame({super.key, required this.patientId, this.difficulty});

  final String patientId;

  /// Explicit difficulty (for tests/preview); null → adaptive from history.
  final int? difficulty;

  @override
  State<PatternGame> createState() => _PatternGameState();
}

class _PatternGameState extends State<PatternGame> {
  static const String _game = 'pattern';

  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];
  int _roundCount = 5;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _roundCount = LocalDb.getSetting('gameConfig_pattern_rounds') as int? ?? 5;
    _enabled = LocalDb.getSetting('gameConfig_pattern_enabled') as bool? ?? true;
    _difficulty = widget.difficulty ??
        DifficultyEngine.instance
            .startingDifficulty(game: _game, patientId: widget.patientId);
    _rounds = buildPatternRounds(difficulty: _difficulty, rounds: _roundCount);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    if (!_enabled) {
      return Scaffold(
        appBar: AppBar(title: Text(t.whatComesNext)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'This game is currently turned off by your caregiver.',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return GameShell(
      title: t.whatComesNext,
      game: _game,
      domain: 'attention',
      difficulty: _difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }
}

