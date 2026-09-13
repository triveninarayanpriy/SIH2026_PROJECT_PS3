import 'dart:convert';

import 'local_db.dart';

/// Caregiver-authored content for the four personalised games.
///
/// Stored as JSON strings in the LocalDb `appState` box (keys below) so no new
/// Hive adapters are required and everything stays fully offline. Widgets can
/// react to changes with `LocalDb.appStateBox.listenable(keys: [<key>])`.

class GameContentKeys {
  static const String milestones = 'game_milestones';
  static const String routine = 'game_routine';
  static const String objects = 'game_objects';
}

/// A life event to recall (Game 2). The [audioPath]/[audioUrl] is an optional
/// caregiver recording of the story + question; otherwise TTS reads [story] and
/// [question].
class Milestone {
  Milestone({
    required this.id,
    required this.title,
    required this.story,
    required this.question,
    required this.answer,
    required this.distractors,
    this.imagePath,
    this.imageUrl = '',
    this.audioPath,
    this.audioUrl = '',
  });

  final String id;
  final String title;
  final String story;
  final String question;
  final String answer;
  final List<String> distractors;
  final String? imagePath;
  final String imageUrl;
  final String? audioPath;
  final String audioUrl;

  String get imageSrc => (imagePath?.isNotEmpty ?? false) ? imagePath! : imageUrl;
  String get audioSrc => (audioPath?.isNotEmpty ?? false) ? audioPath! : audioUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'story': story,
        'question': question,
        'answer': answer,
        'distractors': distractors,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
        'audioPath': audioPath,
        'audioUrl': audioUrl,
      };

  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
        id: (j['id'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        story: (j['story'] as String?) ?? '',
        question: (j['question'] as String?) ?? '',
        answer: (j['answer'] as String?) ?? '',
        distractors:
            (j['distractors'] as List?)?.map((e) => e.toString()).toList() ??
                <String>[],
        imagePath: j['imagePath'] as String?,
        imageUrl: (j['imageUrl'] as String?) ?? '',
        audioPath: j['audioPath'] as String?,
        audioUrl: (j['audioUrl'] as String?) ?? '',
      );
}

/// One step in the patient's daily routine (Game 3). [order] defines the
/// correct sequence (ascending).
class RoutineStep {
  RoutineStep({
    required this.id,
    required this.label,
    required this.order,
    this.imagePath,
    this.imageUrl = '',
  });

  final String id;
  final String label;
  final int order;
  final String? imagePath;
  final String imageUrl;

  String get imageSrc => (imagePath?.isNotEmpty ?? false) ? imagePath! : imageUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'order': order,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
      };

  factory RoutineStep.fromJson(Map<String, dynamic> j) => RoutineStep(
        id: (j['id'] as String?) ?? '',
        label: (j['label'] as String?) ?? '',
        order: (j['order'] as num?)?.toInt() ?? 0,
        imagePath: j['imagePath'] as String?,
        imageUrl: (j['imageUrl'] as String?) ?? '',
      );
}

/// A culturally-relevant / personal object to identify (Game 4).
class CulturalObject {
  CulturalObject({
    required this.id,
    required this.name,
    this.imagePath,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String? imagePath;
  final String imageUrl;

  String get imageSrc => (imagePath?.isNotEmpty ?? false) ? imagePath! : imageUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
      };

  factory CulturalObject.fromJson(Map<String, dynamic> j) => CulturalObject(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        imagePath: j['imagePath'] as String?,
        imageUrl: (j['imageUrl'] as String?) ?? '',
      );
}

/// Read/write access to the caregiver-authored game content.
class GameContent {
  GameContent._();

  static List<Map<String, dynamic>> _readList(String key) {
    final Object? raw = LocalDb.getSetting(key);
    if (raw is! String || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> _writeList(String key, List<Map<String, dynamic>> items) {
    return LocalDb.putSetting(key, jsonEncode(items));
  }

  // ---- Milestones -------------------------------------------------------
  static List<Milestone> milestones() =>
      _readList(GameContentKeys.milestones).map(Milestone.fromJson).toList();

  static Future<void> saveMilestone(Milestone m) async {
    final List<Milestone> all = milestones();
    final int i = all.indexWhere((e) => e.id == m.id);
    if (i >= 0) {
      all[i] = m;
    } else {
      all.add(m);
    }
    await _writeList(
        GameContentKeys.milestones, all.map((e) => e.toJson()).toList());
  }

  static Future<void> deleteMilestone(String id) async {
    final List<Milestone> all = milestones()..removeWhere((e) => e.id == id);
    await _writeList(
        GameContentKeys.milestones, all.map((e) => e.toJson()).toList());
  }

  // ---- Routine ----------------------------------------------------------
  static List<RoutineStep> routine() {
    final List<RoutineStep> steps =
        _readList(GameContentKeys.routine).map(RoutineStep.fromJson).toList();
    steps.sort((a, b) => a.order.compareTo(b.order));
    return steps;
  }

  static Future<void> saveRoutineStep(RoutineStep s) async {
    final List<RoutineStep> all = routine();
    final int i = all.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      all[i] = s;
    } else {
      all.add(s);
    }
    await _writeList(
        GameContentKeys.routine, all.map((e) => e.toJson()).toList());
  }

  static Future<void> deleteRoutineStep(String id) async {
    final List<RoutineStep> all = routine()..removeWhere((e) => e.id == id);
    await _writeList(
        GameContentKeys.routine, all.map((e) => e.toJson()).toList());
  }

  // ---- Objects ----------------------------------------------------------
  static List<CulturalObject> objects() =>
      _readList(GameContentKeys.objects).map(CulturalObject.fromJson).toList();

  static Future<void> saveObject(CulturalObject o) async {
    final List<CulturalObject> all = objects();
    final int i = all.indexWhere((e) => e.id == o.id);
    if (i >= 0) {
      all[i] = o;
    } else {
      all.add(o);
    }
    await _writeList(
        GameContentKeys.objects, all.map((e) => e.toJson()).toList());
  }

  static Future<void> deleteObject(String id) async {
    final List<CulturalObject> all = objects()..removeWhere((e) => e.id == id);
    await _writeList(
        GameContentKeys.objects, all.map((e) => e.toJson()).toList());
  }
}
