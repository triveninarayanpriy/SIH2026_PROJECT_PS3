/// Text-to-speech service.
///
/// Stub for now — the real `flutter_tts` wiring (device voice, offline) lands
/// with the voice build. `SpeakLabel` and game prompts already call [speak], so
/// no call sites change when it becomes real.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  /// Speaks [text] aloud.
  Future<void> speak(String text) async {
    // TODO(tts): wire flutter_tts here (device voice, works offline).
  }

  /// Stops any current utterance.
  Future<void> stop() async {
    // TODO(tts): stop the current utterance.
  }
}
