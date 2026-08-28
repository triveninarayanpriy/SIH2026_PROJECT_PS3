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
      await load();
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

    // Persist per-game difficulty for the dashboard readouts.
    await LocalDb.setGameDifficulty('pattern', 3);
    await LocalDb.setGameDifficulty('faces', 2);
    await LocalDb.setGameDifficulty('voice', 2);

    // Fire the anomaly detector on the fresh history.
    await AnomalyDetector.instance.runForPatient(_pid);

    // Populate the doctor dashboard cache so it shows the patient offline too.
    try {
      await FirestoreService().linkPatientToRole(
          uid: DemoMode.doctorUid, patientId: _pid, isDoctor: true);
    } catch (_) {}
    await _seedDoctorCache();
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

    await LocalDb.putSetting('doctorRows_${DemoMode.doctorUid}', <Map<String, dynamic>>[
      DoctorPatientRow(
        id: _pid,
        name: 'Kamala Devi',
        stage: 2,
        lastActive: lastActive,
        hasAlert: hasAlert,
      ).toMap(),
    ]);

    await LocalDb.putSetting('doctorDetail_$_pid', <String, dynamic>{
      'profile': LocalDb.getProfile(_pid)?.toMap(),
      'sessions': LocalDb.sessionsForPatient(_pid).map((s) => s.toMap()).toList(),
      'alerts':
          LocalDb.allAlerts().where((a) => a.patientId == _pid).map((a) => a.toMap()).toList(),
      'dailyCare': LocalDb.allDailyCare().map((c) => c.toMap()).toList(),
    });
  }
}
