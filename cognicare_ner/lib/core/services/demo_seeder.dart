import '../models/alert.dart';
import '../models/daily_care.dart';
import '../models/game_result.dart';
import '../models/media_item.dart';
import '../models/patient_profile.dart';
import '../models/reminder.dart';
import '../ai/anomaly_detector.dart';
import '../../features/doctor/doctor_repository.dart';
import 'demo_mode.dart';
import 'firestore_service.dart';
import 'game_content.dart';
import 'local_db.dart';
import 'sync_service.dart';

/// Seeds a fully-populated demo patient for screenshots — behind [DemoMode].
///
/// All ids are deterministic so re-running overwrites the same records. The
/// game history is shaped to (a) draw nice per-domain trend charts and (b)
/// trigger a cognitive-drop alert in the 'memory' domain.
class DemoSeeder {
  DemoSeeder._();

  static const String _pid = DemoMode.patientId;

  /// Seeds when the build was launched with `--dart-define=DEMO=true`.
  static Future<void> maybeLoadFromEnvironment() async {
    if (const bool.fromEnvironment('DEMO')) {
      try {
        await load();
      } catch (_) {
        // A demo-seed hiccup must never block app startup.
      }
    }
  }

  static Future<void> load() async {
    await DemoMode.enable();

    // Clear prior demo alerts/sessions so the run is repeatable and re-fires.
    for (final GameResult s in LocalDb.allSessions()
        .where((s) => s.patientId == _pid)
        .toList()) {
      await LocalDb.deleteSession(s.id);
    }
    for (final Alert a
        in LocalDb.allAlerts().where((a) => a.patientId == _pid).toList()) {
      await LocalDb.deleteAlert(a.id);
    }

    // Profile.
    final PatientProfile profile = PatientProfile(
      id: _pid,
      name: 'Kamala Devi',
      age: 74,
      stage: 2,
      languages: <String>['Hindi', 'English'],
      region: 'Assam',
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
    );
    await SyncService.instance.saveProfile(profile);
    await LocalDb.setCaregiverPatientId(_pid);
    await LocalDb.setLinkedPatientId(_pid);
    SyncService.instance.setPatient(_pid);

    // Family faces + voices.
    const List<List<String>> fam = <List<String>>[
      <String>['fam1', 'Meera', 'assets/images/family/f1.png'],
      <String>['fam2', 'Rahul', 'assets/images/family/f2.png'],
      <String>['fam3', 'Anjali', 'assets/images/family/f3.png'],
    ];
    for (final List<String> f in fam) {
      await SyncService.instance.saveMedia(
        _pid,
        MediaItem(id: f[0], type: 'familyFace', url: f[2], label: f[1]),
      );
    }
    await SyncService.instance.saveMedia(
      _pid,
      MediaItem(
          id: 'voi1',
          type: 'familyVoice',
          url: 'assets/sounds/voice1.wav',
          label: 'Meera'),
    );
    await SyncService.instance.saveMedia(
      _pid,
      MediaItem(
          id: 'voi2',
          type: 'familyVoice',
          url: 'assets/sounds/voice2.wav',
          label: 'Rahul'),
    );
    await SyncService.instance.saveMedia(
      _pid,
      MediaItem(
          id: 'mus1',
          type: 'music',
          url: 'assets/sounds/music.wav',
          label: 'Favourite tune'),
    );

    // Personalised game content (Milestones, Routine, Objects) for Kamala.
    await _seedGameContent();

    // Reminders.
    await SyncService.instance.saveReminder(
      _pid,
      Reminder(
          id: 'rem1',
          type: 'medicine',
          title: 'Time for your medicine',
          time: '08:00',
          repeatDaily: true),
    );
    await SyncService.instance.saveReminder(
      _pid,
      Reminder(
          id: 'rem2',
          type: 'hydration',
          title: 'Please drink some water',
          time: '11:00',
          repeatDaily: true),
    );
    await SyncService.instance.saveReminder(
      _pid,
      Reminder(
          id: 'rem3',
          type: 'meal',
          title: 'Time to eat',
          time: '13:00',
          repeatDaily: true),
    );

    // A couple of daily-care logs.
    for (int d = 0; d < 3; d++) {
      final DateTime day = DateTime.now().subtract(Duration(days: d));
      await SyncService.instance.saveDailyCare(
        _pid,
        DailyCare(
          date:
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
          medsTaken: const <String>['morning', 'evening'],
          hydrationCount: 5 - d,
          mealsLogged: const <String>['breakfast', 'lunch', 'dinner'],
        ),
      );
    }

    // ~17 historical sessions across domains.
    final DateTime base = DateTime.now();
    int seq = 0;
    Future<void> add(String game, String domain, int correct, int daysAgo) async {
      await SyncService.instance.saveGameResult(GameResult(
        id: 'demo-sess-${seq++}',
        patientId: _pid,
        game: game,
        domain: domain,
        correct: correct,
        total: 5,
        durationMs: 4000 + (seq * 137) % 3000,
        difficulty: 2 + (daysAgo % 3),
        at: base.subtract(Duration(days: daysAgo, hours: seq % 12)),
      ));
    }

    // attention (pattern): improving trend.
    await add('pattern', 'attention', 3, 18);
    await add('pattern', 'attention', 4, 14);
    await add('pattern', 'attention', 4, 9);
    await add('pattern', 'attention', 5, 4);
    await add('pattern', 'attention', 5, 1);
    // auditory (voice): steady.
    await add('voice', 'auditory', 4, 16);
    await add('voice', 'auditory', 4, 11);
    await add('voice', 'auditory', 3, 6);
    await add('voice', 'auditory', 4, 2);
    // memory (faces): strong then a recent decline -> anomaly.
    await add('faces', 'memory', 5, 20);
    await add('faces', 'memory', 5, 17);
    await add('faces', 'memory', 4, 14);
    await add('faces', 'memory', 5, 11);
    await add('faces', 'memory', 4, 8);
    await add('faces', 'memory', 2, 3);
    await add('faces', 'memory', 2, 2);
    await add('faces', 'memory', 1, 1);
    // language (name completion): steady, mild.
    await add('name_completion', 'language', 3, 15);
    await add('name_completion', 'language', 4, 8);
    await add('name_completion', 'language', 3, 2);
    // executive (routine sequencing): a little harder for her.
    await add('routine', 'executive', 3, 13);
    await add('routine', 'executive', 2, 7);
    await add('routine', 'executive', 3, 1);
    // recognition/attention (objects) + episodic (milestone).
    await add('objects', 'attention', 4, 10);
    await add('objects', 'attention', 4, 3);
    await add('milestone', 'memory', 4, 12);
    await add('milestone', 'memory', 3, 5);

    // Persist per-game difficulty for the dashboard readouts.
    await LocalDb.setGameDifficulty('pattern', 3);
    await LocalDb.setGameDifficulty('faces', 2);
    await LocalDb.setGameDifficulty('voice', 2);
    await LocalDb.setGameDifficulty('name_completion', 2);
    await LocalDb.setGameDifficulty('routine', 2);
    await LocalDb.setGameDifficulty('objects', 2);
    await LocalDb.setGameDifficulty('milestone', 2);

    // Fire the anomaly detector on the fresh history.
    await AnomalyDetector.instance.runForPatient(_pid);

    // Populate the doctor dashboard cache so it shows the patient offline too.
    try {
      await FirestoreService().linkPatientToRole(
          uid: DemoMode.doctorUid, patientId: _pid, isDoctor: true);
    } catch (_) {}
    await _seedDoctorCache();
  }

  /// Seeds caregiver-authored content for the four personalised games so the
  /// demo build is immediately playable. Images reuse the bundled family assets.
  static Future<void> _seedGameContent() async {
    // Milestones (Game 2).
    await GameContent.saveMilestone(Milestone(
      id: 'demo-ms-1',
      title: 'Wedding day, 1971',
      story: 'This is your wedding day in the village, many years ago.',
      question: 'In which year did you get married?',
      answer: '1971',
      distractors: <String>['1965', '1980'],
      imageUrl: 'assets/images/family/f1.png',
    ));
    await GameContent.saveMilestone(Milestone(
      id: 'demo-ms-2',
      title: 'First grandchild',
      story: 'The day your first grandchild was born, the whole family gathered.',
      question: 'Who was born on that happy day?',
      answer: 'Your grandchild',
      distractors: <String>['Your neighbour', 'A cousin'],
      imageUrl: 'assets/images/family/f2.png',
    ));

    // Daily routine (Game 3).
    const List<List<String>> steps = <List<String>>[
      <String>['demo-rt-1', 'Wake up'],
      <String>['demo-rt-2', 'Drink tea'],
      <String>['demo-rt-3', 'Take medicine'],
      <String>['demo-rt-4', 'Morning walk'],
      <String>['demo-rt-5', 'Eat lunch'],
    ];
    for (int i = 0; i < steps.length; i++) {
      await GameContent.saveRoutineStep(
          RoutineStep(id: steps[i][0], label: steps[i][1], order: i));
    }

    // Objects (Game 4).
    const List<List<String>> objs = <List<String>>[
      <String>['demo-ob-1', 'Gamosa', 'assets/images/family/f3.png'],
      <String>['demo-ob-2', 'Tea cup', 'assets/images/family/f1.png'],
      <String>['demo-ob-3', 'Betel-nut box', 'assets/images/family/f2.png'],
    ];
    for (final List<String> o in objs) {
      await GameContent.saveObject(
          CulturalObject(id: o[0], name: o[1], imageUrl: o[2]));
    }
  }

  /// Writes the doctor's cached rows + detail (LocalDb appState) so the doctor
  /// dashboard is populated even without a cloud round-trip.
  static Future<void> _seedDoctorCache() async {
    final DateTime? lastActive = LocalDb.allSessions()
        .where((s) => s.patientId == _pid)
        .map((s) => s.at)
        .fold<DateTime?>(null, (DateTime? m, DateTime at) =>
            (m == null || at.isAfter(m)) ? at : m);
    final bool hasAlert = LocalDb.allAlerts()
        .any((a) => a.patientId == _pid && !a.seen);

    // Kamala Devi — the real, fully-seeded patient (from LocalDb).
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
      DoctorPatientRow(
        id: _pid,
        name: 'Kamala Devi',
        stage: 2,
        lastActive: lastActive,
        hasAlert: hasAlert,
      ).toMap(),
    ];
    await LocalDb.putSetting('doctorDetail_$_pid', <String, dynamic>{
      'profile': LocalDb.getProfile(_pid)?.toMap(),
      'sessions': LocalDb.sessionsForPatient(_pid).map((s) => s.toMap()).toList(),
      'alerts':
          LocalDb.allAlerts().where((a) => a.patientId == _pid).map((a) => a.toMap()).toList(),
      'dailyCare': LocalDb.allDailyCare().map((c) => c.toMap()).toList(),
    });

    // Two more patients so the doctor list shows the full triage range.
    rows.add(_syntheticPatient(
      id: 'PT-1033',
      name: 'Rameshwar Sen',
      age: 81,
      stage: 3,
      region: 'Kolkata',
      baseAccuracy: 0.60, // -> amber "Watch"
      lastActiveDaysAgo: 1,
    ));
    rows.add(_syntheticPatient(
      id: 'PT-1088',
      name: 'Anandi Bai',
      age: 69,
      stage: 1,
      region: 'Pune',
      baseAccuracy: 0.90, // -> green "Stable"
      lastActiveDaysAgo: 0,
    ));

    await LocalDb.putSetting('doctorRows_${DemoMode.doctorUid}', rows);
  }

  /// Builds a synthetic doctor patient (row + cached detail) for the demo list.
  /// Writes the detail cache and returns the row map.
  static Map<String, dynamic> _syntheticPatient({
    required String id,
    required String name,
    required int age,
    required int stage,
    required String region,
    required double baseAccuracy,
    required int lastActiveDaysAgo,
  }) {
    final DateTime now = DateTime.now();
    const List<List<String>> games = <List<String>>[
      <String>['pattern', 'attention'],
      <String>['faces', 'memory'],
      <String>['voice', 'auditory'],
      <String>['name_completion', 'language'],
      <String>['routine', 'executive'],
    ];
    final List<Map<String, dynamic>> sessions = <Map<String, dynamic>>[];
    int seq = 0;
    for (int day = 18; day >= 1; day -= 3) {
      for (final List<String> g in games) {
        // Small deterministic wobble around the base accuracy.
        final double jitter = ((seq * 37) % 20 - 10) / 100.0;
        final double acc = (baseAccuracy + jitter).clamp(0.1, 1.0);
        final int correct = (acc * 5).round().clamp(0, 5);
        sessions.add(GameResult(
          id: '$id-s${seq++}',
          patientId: id,
          game: g[0],
          domain: g[1],
          correct: correct,
          total: 5,
          durationMs: 30000 + (seq * 211) % 40000,
          difficulty: stage,
          at: now.subtract(Duration(days: day, hours: seq % 10)),
        ).toMap());
      }
    }
    final List<Map<String, dynamic>> care = <Map<String, dynamic>>[];
    for (int d = 0; d < 7; d++) {
      final DateTime day = now.subtract(Duration(days: d));
      final bool good = baseAccuracy > 0.7;
      care.add(DailyCare(
        date:
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        medsTaken: good || d.isEven ? const <String>['morning', 'evening'] : const <String>['morning'],
        hydrationCount: good ? 6 : 4,
        mealsLogged: good ? const <String>['breakfast', 'lunch', 'dinner'] : const <String>['breakfast', 'lunch'],
      ).toMap());
    }

    LocalDb.putSetting('doctorDetail_$id', <String, dynamic>{
      'profile': PatientProfile(
        id: id,
        name: name,
        age: age,
        stage: stage,
        languages: const <String>['English'],
        region: region,
        createdAt: now.subtract(const Duration(days: 60)),
      ).toMap(),
      'sessions': sessions,
      'alerts': const <Map<String, dynamic>>[],
      'dailyCare': care,
    });

    return DoctorPatientRow(
      id: id,
      name: name,
      stage: stage,
      lastActive: now.subtract(Duration(days: lastActiveDaysAgo, hours: 2)),
      hasAlert: false,
    ).toMap();
  }
}
