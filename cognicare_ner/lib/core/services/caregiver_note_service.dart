import 'dart:convert';

import '../models/game_result.dart';
import 'ai_service.dart';
import 'local_db.dart';

/// A generated summary note plus provenance.
class CareNote {
  const CareNote({required this.text, required this.isAi, required this.generatedAt});

  final String text;
  final bool isAi;
  final DateTime generatedAt;
}

/// Human-readable labels for the domain keys used across the app.
const Map<String, String> kDomainLabels = <String, String>{
  'memory': 'Memory',
  'attention': 'Attention',
  'auditory': 'Listening',
  'language': 'Language',
  'executive': 'Sequencing',
};

/// Anonymised weekly summary derived entirely on-device.
class WeeklyStats {
  WeeklyStats({
    required this.sessionsThisWeek,
    required this.overallThisWeek,
    required this.overallPriorWeek,
    required this.perDomain,
    required this.decliningDomains,
    required this.hasAlert,
  });

  final int sessionsThisWeek;
  final double? overallThisWeek; // 0..1
  final double? overallPriorWeek; // 0..1
  final Map<String, double> perDomain; // domain -> 0..1 this week
  final List<String> decliningDomains;
  final bool hasAlert;

  /// Change in overall accuracy vs prior week, in percentage points (or null).
  double? get deltaPct {
    if (overallThisWeek == null || overallPriorWeek == null) return null;
    return (overallThisWeek! - overallPriorWeek!) * 100;
  }

  static WeeklyStats compute(String patientId) {
    final DateTime now = DateTime.now();
    final DateTime weekAgo = now.subtract(const Duration(days: 7));
    final DateTime twoWeeksAgo = now.subtract(const Duration(days: 14));

    final List<GameResult> all = LocalDb.sessionsForPatient(patientId);
    final List<GameResult> thisWeek =
        all.where((s) => s.at.isAfter(weekAgo)).toList();
    final List<GameResult> priorWeek = all
        .where((s) => s.at.isAfter(twoWeeksAgo) && s.at.isBefore(weekAgo))
        .toList();

    double? avg(List<GameResult> xs) => xs.isEmpty
        ? null
        : xs.map((s) => s.accuracy).reduce((a, b) => a + b) / xs.length;

    final Map<String, List<double>> byDomain = <String, List<double>>{};
    for (final GameResult s in thisWeek) {
      byDomain.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
    }
    final Map<String, double> perDomain = <String, double>{
      for (final MapEntry<String, List<double>> e in byDomain.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length,
    };

    // Declining: this-week domain avg noticeably below its prior-week avg.
    final Map<String, List<double>> priorByDomain = <String, List<double>>{};
    for (final GameResult s in priorWeek) {
      priorByDomain.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
    }
    final List<String> declining = <String>[];
    perDomain.forEach((String d, double now) {
      final List<double>? prior = priorByDomain[d];
      if (prior != null && prior.isNotEmpty) {
        final double p = prior.reduce((a, b) => a + b) / prior.length;
        if (now < p - 0.15) declining.add(d);
      }
    });

    final bool hasAlert =
        LocalDb.allAlerts().any((a) => a.patientId == patientId && !a.seen);

    return WeeklyStats(
      sessionsThisWeek: thisWeek.length,
      overallThisWeek: avg(thisWeek),
      overallPriorWeek: avg(priorWeek),
      perDomain: perDomain,
      decliningDomains: declining,
      hasAlert: hasAlert,
    );
  }

  /// Anonymised, name-free summary safe to send to an LLM.
  String toAnonymizedSummary() {
    final StringBuffer b = StringBuffer();
    b.write('Sessions this week: $sessionsThisWeek. ');
    if (overallThisWeek != null) {
      b.write('Overall accuracy this week: ${(overallThisWeek! * 100).round()}%. ');
    }
    if (deltaPct != null) {
      final String dir = deltaPct! >= 0 ? 'up' : 'down';
      b.write('That is $dir ${deltaPct!.abs().round()} points vs last week. ');
    }
    if (perDomain.isNotEmpty) {
      final String parts = perDomain.entries
          .map((e) =>
              '${kDomainLabels[e.key] ?? e.key} ${(e.value * 100).round()}%')
          .join(', ');
      b.write('By area: $parts. ');
    }
    if (decliningDomains.isNotEmpty) {
      final String d = decliningDomains
          .map((e) => kDomainLabels[e] ?? e)
          .join(', ');
      b.write('Weaker this week: $d. ');
    }
    if (hasAlert) b.write('An early-warning alert is active. ');
    return b.toString().trim();
  }
}

/// The 6th AI feature: warm, plain-language weekly notes for the caregiver and a
/// clinician-toned variant for the doctor. Uses the free LLMs when a key is set,
/// and a deterministic on-device template otherwise, so it never blocks or
/// requires the network. Results are cached in LocalDb per patient.
class CaregiverNoteService {
  CaregiverNoteService._();
  static final CaregiverNoteService instance = CaregiverNoteService._();

  String _cacheKey(String patientId, bool clinical) =>
      clinical ? 'doctorNote_$patientId' : 'caregiverNote_$patientId';

  /// Returns the last generated note for this patient, if any.
  CareNote? cached(String patientId, {bool clinical = false}) {
    final Object? raw = LocalDb.getSetting(_cacheKey(patientId, clinical));
    if (raw is! String || raw.isEmpty) return null;
    try {
      final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
      return CareNote(
        text: (j['text'] as String?) ?? '',
        isAi: (j['isAi'] as bool?) ?? false,
        generatedAt: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cache(String patientId, bool clinical, CareNote note) {
    return LocalDb.putSetting(
      _cacheKey(patientId, clinical),
      jsonEncode(<String, dynamic>{
        'text': note.text,
        'isAi': note.isAi,
        'at': note.generatedAt.toIso8601String(),
      }),
    );
  }

  /// Generates a fresh note (AI when possible, else template) and caches it.
  Future<CareNote> generate(String patientId, {bool clinical = false}) async {
    final WeeklyStats stats = WeeklyStats.compute(patientId);
    final String summary = stats.toAnonymizedSummary();

    String? ai;
    if (AiService.instance.isConfigured && stats.sessionsThisWeek > 0) {
      final String system = clinical
          ? 'You are a concise clinical assistant writing for a physician. '
              'Two or three sentences, objective and specific, no fluff. '
              'Never invent data beyond what is given. Do not use the patient\'s name.'
          : 'You write warm, reassuring, plain-language notes for a family '
              'caregiver of a person with dementia. Two or three short sentences, '
              'kind and encouraging, gently honest about any concern, and end with '
              'one simple suggestion. Do not use the patient\'s name.';
      final String user =
          'Weekly cognitive-game summary (anonymised): $summary\n'
          'Write the ${clinical ? 'clinical' : 'caregiver'} note now.';
      ai = await AiService.instance.generateText(systemPrompt: system, userPrompt: user);
    }

    final CareNote note = CareNote(
      text: (ai != null && ai.trim().isNotEmpty)
          ? ai.trim()
          : _fallback(stats, clinical: clinical),
      isAi: ai != null && ai.trim().isNotEmpty,
      generatedAt: DateTime.now(),
    );
    await _cache(patientId, clinical, note);
    return note;
  }

  /// Deterministic on-device note when no AI key / offline / no network.
  String _fallback(WeeklyStats s, {required bool clinical}) {
    if (s.sessionsThisWeek == 0) {
      return clinical
          ? 'No game sessions recorded this week; unable to assess trend.'
          : 'No activities were recorded this week. A short, familiar game '
              'together can be a gentle way to start again.';
    }
    final int overall = ((s.overallThisWeek ?? 0) * 100).round();
    final String strongest = s.perDomain.isEmpty
        ? ''
        : (s.perDomain.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    final String strongLabel = kDomainLabels[strongest] ?? strongest;
    final String weak = s.decliningDomains.isEmpty
        ? ''
        : (kDomainLabels[s.decliningDomains.first] ?? s.decliningDomains.first);

    if (clinical) {
      final StringBuffer b = StringBuffer();
      b.write('${s.sessionsThisWeek} sessions this week; overall accuracy $overall%');
      if (s.deltaPct != null) {
        b.write(', ${s.deltaPct! >= 0 ? 'up' : 'down'} '
            '${s.deltaPct!.abs().round()} points vs prior week');
      }
      b.write('. ');
      if (weak.isNotEmpty) {
        b.write('$weak shows a decline and warrants monitoring. ');
      }
      if (s.hasAlert) b.write('An automated cognitive-drop alert is active.');
      return b.toString().trim();
    }

    final StringBuffer b = StringBuffer();
    b.write('This week ${s.sessionsThisWeek == 1 ? 'there was 1 session' : 'there were ${s.sessionsThisWeek} sessions'}');
    if (strongLabel.isNotEmpty) b.write(', and $strongLabel is going well');
    b.write('. ');
    if (weak.isNotEmpty) {
      b.write('$weak felt a little harder — try shorter, calmer rounds there. ');
    } else {
      b.write('Keep the familiar routine going — it is really helping. ');
    }
    if (s.hasAlert) {
      b.write('There is a gentle heads-up worth a look on the dashboard.');
    }
    return b.toString().trim();
  }
}
