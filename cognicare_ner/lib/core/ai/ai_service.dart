/// One online AI difficulty suggestion: a level (1..5) + a caregiver note.
class AiDifficultyResult {
  const AiDifficultyResult({required this.difficulty, required this.note});

  final int difficulty;
  final String note;
}

/// Online AI helper (Groq / Gemini over http, key from `.env`).
///
/// Stub for now — implemented in the next build. Callers (the difficulty
/// engine) must always be able to fall back to the on-device Tier-1 rule, so
/// this throws until it is configured.
class AiService {
  AiService._();

  static final AiService instance = AiService._();

  /// Whether an API key / endpoint has been wired up yet.
  bool get isConfigured => false;

  /// Suggests a difficulty (1..5) and a one-line caregiver note from recent
  /// accuracies. Throws when unavailable — the caller must catch and fall back.
  Future<AiDifficultyResult> suggestDifficulty({
    required String game,
    required int current,
    required List<double> recentAccuracies,
  }) async {
    // TODO(ai): call the LLM over http using a key from .env (next build).
    throw StateError('AiService is not configured yet.');
  }
}
