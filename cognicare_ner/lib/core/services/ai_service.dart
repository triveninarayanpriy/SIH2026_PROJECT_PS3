import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// One AI difficulty suggestion: a level (1..5) + a one-line caregiver note.
class AiDifficultyNote {
  const AiDifficultyNote({required this.suggestedLevel, required this.note});

  final int suggestedLevel;
  final String note;
}

/// Online AI helper using FREE LLM APIs — Groq first, Gemini as a fallback.
///
/// PRIVACY: only ANONYMIZED data is ever sent off-device — the game name, the
/// difficulty level, and numeric accuracy scores. The patient's name, photos,
/// and voice are NEVER sent. Any failure returns null so the app falls back to
/// the on-device Tier-1 rule.
class AiService {
  AiService._();

  static final AiService instance = AiService._();

  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqModel = 'llama-3.3-70b-versatile';
  static const String _geminiModel = 'gemini-1.5-flash';
  static const Duration _timeout = Duration(seconds: 12);

  String _key(String name) {
    try {
      return dotenv.maybeGet(name)?.trim() ?? '';
    } catch (_) {
      // dotenv not loaded (e.g. .env missing) — treat as no key.
      return '';
    }
  }

  /// Whether at least one API key is configured.
  bool get isConfigured =>
      _key('GROQ_API_KEY').isNotEmpty || _key('GEMINI_API_KEY').isNotEmpty;

  /// Suggests a difficulty (1..5) + a one-line caregiver note from recent
  /// scores. Tries Groq, then Gemini. Returns null on ANY error.
  Future<AiDifficultyNote?> suggestDifficultyNote({
    required List<double> recentScores,
    required String game,
    required int currentLevel,
  }) async {
    final String prompt = _buildPrompt(
      recentScores: recentScores,
      game: game,
      currentLevel: currentLevel,
    );
    final AiDifficultyNote? viaGroq = await _tryGroq(prompt);
    if (viaGroq != null) return viaGroq;
    return _tryGemini(prompt);
  }

  String _buildPrompt({
    required List<double> recentScores,
    required String game,
    required int currentLevel,
  }) {
    // ANONYMIZED payload only: accuracy percentages, level, game name.
    final List<int> pct = recentScores.map((s) => (s * 100).round()).toList();
    return 'You tune a cognitive game for an elderly dementia patient. '
        'Game: "$game". Current difficulty level: $currentLevel (1-5, 5 hardest). '
        'Recent accuracy percentages, oldest to newest: $pct. '
        'Choose the next difficulty (1-5) so it stays gently challenging but not '
        'frustrating, and write ONE short plain-language sentence for the '
        'caregiver about how the patient is doing. '
        'Respond with ONLY this JSON, no markdown: '
        '{"suggestedLevel": <int 1-5>, "note": "<one sentence>"}';
  }

  Future<AiDifficultyNote?> _tryGroq(String prompt) async {
    final String key = _key('GROQ_API_KEY');
    if (key.isEmpty) return null;
    try {
      final http.Response resp = await http
          .post(
            Uri.parse(_groqUrl),
            headers: <String, String>{
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'model': _groqModel,
              'temperature': 0.2,
              'response_format': <String, String>{'type': 'json_object'},
              'messages': <Map<String, String>>[
                {'role': 'system', 'content': 'You reply with strict JSON only.'},
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data =
          jsonDecode(resp.body) as Map<String, dynamic>;
      final Object? choices = data['choices'];
      final Object? first = (choices is List && choices.isNotEmpty) ? choices.first : null;
      final Object? message = (first is Map) ? first['message'] : null;
      final Object? content = (message is Map) ? message['content'] : null;
      return _parseNote(content is String ? content : null);
    } catch (_) {
      return null;
    }
  }

  Future<AiDifficultyNote?> _tryGemini(String prompt) async {
    final String key = _key('GEMINI_API_KEY');
    if (key.isEmpty) return null;
    try {
      final Uri url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_geminiModel:generateContent?key=$key',
      );
      final http.Response resp = await http
          .post(
            url,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'contents': <Map<String, dynamic>>[
                {
                  'parts': <Map<String, String>>[
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': <String, dynamic>{
                'temperature': 0.2,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data =
          jsonDecode(resp.body) as Map<String, dynamic>;
      final Object? candidates = data['candidates'];
      final Object? first =
          (candidates is List && candidates.isNotEmpty) ? candidates.first : null;
      final Object? content = (first is Map) ? first['content'] : null;
      final Object? parts = (content is Map) ? content['parts'] : null;
      final Object? part = (parts is List && parts.isNotEmpty) ? parts.first : null;
      final Object? text = (part is Map) ? part['text'] : null;
      return _parseNote(text is String ? text : null);
    } catch (_) {
      return null;
    }
  }

  /// Strict-ish JSON parse (tolerates accidental ```json fences).
  AiDifficultyNote? _parseNote(String? content) {
    if (content == null) return null;
    try {
      String s = content.trim();
      if (s.startsWith('```')) {
        s = s
            .replaceAll(RegExp(r'^```[a-zA-Z]*'), '')
            .replaceAll('```', '')
            .trim();
      }
      final Map<String, dynamic> obj = jsonDecode(s) as Map<String, dynamic>;
      final int? level = (obj['suggestedLevel'] as num?)?.toInt();
      final String? note = obj['note'] as String?;
      if (level == null || note == null || level < 1 || level > 5) return null;
      return AiDifficultyNote(suggestedLevel: level, note: note.trim());
    } catch (_) {
      return null;
    }
  }
}
