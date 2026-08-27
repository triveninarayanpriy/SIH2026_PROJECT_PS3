import 'package:flutter/widgets.dart';

/// A single visual token (icon + label) — used by the pattern game's sequence
/// and answer tiles. Data-driven so difficulty can scale how many are shown.
@immutable
class GameItem {
  const GameItem({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}

/// One answer option: a stable [id] and the inner [content] shown in its big
/// single-tap tile. Optional fixed [width]/[height] (else the tile sizes to the
/// content with a large minimum target).
@immutable
class GameChoice {
  const GameChoice({
    required this.id,
    required this.content,
    this.width,
    this.height,
  });

  final String id;
  final Widget content;
  final double? width;
  final double? height;
}

/// One round the [GameShell] presents: a spoken prompt, a [stimulus] question
/// area (a sequence / a photo / an audio button — whatever the game supplies),
/// the big answer [choices], and which choice id is correct.
@immutable
class GameRound {
  const GameRound({
    required this.prompt,
    required this.stimulus,
    required this.choices,
    required this.answerId,
    this.promptAudioPath,
  });

  final String prompt;
  final String? promptAudioPath;
  final Widget stimulus;
  final List<GameChoice> choices;
  final String answerId;
}
