import 'package:flutter/widgets.dart';

/// A single visual token used in a game — an icon plus a clear label.
///
/// Data-driven: games build their sequences and answer tiles from these, so
/// difficulty can scale how many are shown without changing the UI.
@immutable
class GameItem {
  const GameItem({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}

/// One round the [GameShell] presents: a spoken prompt, the sequence to show
/// (the UI appends a "?" slot), the big answer tiles, and which one is correct.
@immutable
class GameRound {
  const GameRound({
    required this.prompt,
    required this.sequence,
    required this.choices,
    required this.answerId,
    this.promptAudioPath,
  });

  /// e.g. "What comes next?" — read aloud via SpeakLabel.
  final String prompt;

  /// Optional caregiver-recorded clip for the prompt.
  final String? promptAudioPath;

  /// Items shown left-to-right; a "?" slot is drawn after them.
  final List<GameItem> sequence;

  /// Big answer tiles (2–3). Exactly one has id == [answerId].
  final List<GameItem> choices;

  final String answerId;
}
