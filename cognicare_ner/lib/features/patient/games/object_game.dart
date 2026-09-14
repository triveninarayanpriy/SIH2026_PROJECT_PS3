import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ai/difficulty_engine.dart';
import '../../../core/services/game_content.dart';
import '../../../core/services/local_db.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/platform_media.dart';
import '../../../l10n/app_localizations.dart';
import 'family.dart';
import 'game_models.dart';
import 'game_shell.dart';

/// Game 4 — Cultural & Personal Object Identification (domain 'attention').
///
/// Shows a culturally-relevant or personal object photo and asks the patient to
/// pick its name from name tiles. Content is curated by the caregiver
/// ([GameContent.objects]). Falls back to a friendly card with fewer than two.
class ObjectGame extends StatefulWidget {
  const ObjectGame({super.key, required this.patientId, this.difficulty});

  final String patientId;
  final int? difficulty;

  @override
  State<ObjectGame> createState() => _ObjectGameState();
}

class _ObjectGameState extends State<ObjectGame> {
  static const String _game = 'objects';

  late final List<CulturalObject> _objects = GameContent.objects();
  int _difficulty = DifficultyEngine.defaultDifficulty;
  List<GameRound> _rounds = const <GameRound>[];

  @override
  void initState() {
    super.initState();
    if (_objects.length >= 2) {
      _difficulty = widget.difficulty ??
          DifficultyEngine.instance
              .startingDifficulty(game: _game, patientId: widget.patientId);
      _rounds = _buildRounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    if (_objects.length < 2) {
      return AddMoreCard(
        title: t.gameWhatIsThis,
        message: 'Ask your family to add familiar objects with their names.',
      );
    }
    return GameShell(
      title: t.gameWhatIsThis,
      game: _game,
      domain: 'attention',
      difficulty: _difficulty,
      rounds: _rounds,
      patientId: widget.patientId,
    );
  }

  List<GameRound> _buildRounds() {
    final Random rng = Random();
    final int options = min(_objects.length, max(2, min(4, _difficulty + 1)));
    final int roundCount =
        LocalDb.getSetting('gameConfig_objects_rounds') as int? ?? 5;

    final List<GameRound> rounds = <GameRound>[];
    for (int i = 0; i < roundCount; i++) {
      final CulturalObject target = _objects[rng.nextInt(_objects.length)];
      final List<CulturalObject> others =
          _objects.where((o) => o.name != target.name).toList()..shuffle(rng);
      final List<CulturalObject> picks = <CulturalObject>[
        target,
        ...others.take(options - 1),
      ]..shuffle(rng);

      rounds.add(GameRound(
        prompt: 'What is this?',
        stimulus: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: MediaImage(
            src: target.imageSrc,
            width: 240,
            height: 240,
            fit: BoxFit.cover,
          ),
        ),
        answerId: target.id,
        choices: <GameChoice>[
          for (final CulturalObject o in picks)
            GameChoice(
              id: o.id,
              label: o.name,
              content: Text(o.name, textAlign: TextAlign.center, style: AppText.button()),
            ),
        ],
      ));
    }
    return rounds;
  }
}
