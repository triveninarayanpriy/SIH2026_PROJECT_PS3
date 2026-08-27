import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

/// Speaks prompts to the patient.
///
/// PRIMARY path: play a caregiver-recorded clip (just_audio) when one exists for
/// a prompt — the familiar family voice. FALLBACK only: device text-to-speech
/// (flutter_tts) in the patient's chosen locale.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  /// promptKey -> recorded clip source (http url or local path).
  final Map<String, String> _clips = <String, String>{};

  /// Patient's chosen TTS locale; falls back to hi-IN then en-IN.
  String _localeId = 'hi-IN';
  bool _ttsReady = false;

  void setLocale(String localeId) {
    if (localeId.trim().isNotEmpty) _localeId = localeId;
  }

  /// Registers a caregiver-recorded clip for a prompt (primary path).
  void registerClip(String promptKey, String source) =>
      _clips[promptKey] = source;

  void clearClips() => _clips.clear();

  /// Plays the prompt: a mapped/explicit recorded clip first, otherwise speaks
  /// [promptKey] with device TTS.
  Future<void> play(
    String promptKey, {
    String? audioPath,
    String? localeId,
  }) async {
    final String? src = (audioPath != null && audioPath.isNotEmpty)
        ? audioPath
        : _clips[promptKey];
    if (src != null && src.isNotEmpty) {
      await _playClip(src);
      return;
    }
    await speak(promptKey, localeId: localeId);
  }

  Future<void> _playClip(String src) async {
    try {
      if (src.startsWith('http')) {
        await _player.setUrl(src);
      } else {
        await _player.setFilePath(src);
      }
      await _player.seek(Duration.zero);
      // Don't await completion — playback runs for a few seconds.
      _player.play();
    } catch (_) {
      // Missing/unsupported clip — silent rather than crash.
    }
  }

  /// FALLBACK only: device text-to-speech. Uses [localeId] / the chosen locale,
  /// then hi-IN, then en-IN — whichever the device supports first.
  Future<void> speak(String text, {String? localeId}) async {
    if (text.trim().isEmpty) return;
    await _ensureReady();
    final List<String> candidates = <String>[
      if (localeId != null && localeId.isNotEmpty) localeId,
      _localeId,
      'hi-IN',
      'en-IN',
    ];
    for (final String loc in candidates) {
      try {
        final Object? available = await _tts.isLanguageAvailable(loc);
        if (available == true) {
          await _tts.setLanguage(loc);
          break;
        }
      } catch (_) {
        // Try the next candidate.
      }
    }
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // TTS engine unavailable — degrade silently.
    }
  }

  Future<void> _ensureReady() async {
    if (_ttsReady) return;
    _ttsReady = true;
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
  }
}
