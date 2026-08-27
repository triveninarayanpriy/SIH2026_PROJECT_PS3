import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text for OPTIONAL voice answers in games.
///
/// Offline-first via the on-device speech_to_text plugin. Tapping is always the
/// guaranteed answer path; voice is only an enhancement. An optional online
/// "boost" (Groq Whisper) can transcribe a recorded clip for higher accuracy
/// and fails gracefully back to on-device / tapping.
class SttService {
  SttService._();

  static final SttService instance = SttService._();

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _available = false;

  bool get isListening => _stt.isListening;

  /// Initializes the plugin once; returns whether speech is available.
  Future<bool> ensureInit() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _stt.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Listens once and calls [onResult] with the recognized words (empty string
  /// if unavailable). Auto-stops after [listenFor].
  Future<void> listen({
    String? localeId,
    required void Function(String text) onResult,
    Duration listenFor = const Duration(seconds: 6),
  }) async {
    final bool ok = await ensureInit();
    if (!ok) {
      onResult('');
      return;
    }
    try {
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult) onResult(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          localeId: localeId,
          listenFor: listenFor,
        ),
      );
    } catch (_) {
      onResult('');
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
  }

  /// Optional online boost: transcribe a recorded clip with Groq Whisper
  /// (whisper-large-v3). Returns the text, or null on any error (no key,
  /// offline, web, bad response) so callers fall back to on-device / tapping.
  Future<String?> transcribeWithGroq(String filePath) async {
    String key;
    try {
      key = dotenv.maybeGet('GROQ_API_KEY')?.trim() ?? '';
    } catch (_) {
      key = '';
    }
    if (key.isEmpty) return null;
    try {
      final bool online = (await Connectivity().checkConnectivity())
          .any((r) => r != ConnectivityResult.none);
      if (!online) return null;

      final http.MultipartRequest req = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
      )
        ..headers['Authorization'] = 'Bearer $key'
        ..fields['model'] = 'whisper-large-v3'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final http.StreamedResponse streamed =
          await req.send().timeout(const Duration(seconds: 20));
      if (streamed.statusCode != 200) return null;
      final http.Response resp = await http.Response.fromStream(streamed);
      final Map<String, dynamic> data =
          jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['text'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }
}
