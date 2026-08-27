import 'package:hive_flutter/hive_flutter.dart';

import '../models/alert.dart';
import '../models/daily_care.dart';
import '../models/game_result.dart';
import '../models/media_item.dart';
import '../models/patient_profile.dart';
import '../models/reminder.dart';

/// Offline-first local store built on Hive.
///
/// One shared store per device: because all three roles run from a single app
/// install, the caregiver side writing here is immediately visible to the
/// patient side reading here. Writes are also mirrored into [syncQueue] so a
/// later sync service can push them to Firestore when a connection returns.
///
/// Call [LocalDb.init] once at startup (after Firebase) in every entrypoint.
class LocalDb {
  LocalDb._();

  // Box names.
  static const String profileBoxName = 'profile';
  static const String mediaBoxName = 'media';
  static const String remindersBoxName = 'reminders';
  static const String sessionsBoxName = 'sessions';
  static const String dailyCareBoxName = 'dailyCare';
  static const String alertsBoxName = 'alerts';
  static const String syncQueueBoxName = 'syncQueue';

  static late Box<PatientProfile> _profile;
  static late Box<MediaItem> _media;
  static late Box<Reminder> _reminders;
  static late Box<GameResult> _sessions;
  static late Box<DailyCare> _dailyCare;
  static late Box<Alert> _alerts;
  static late Box<dynamic> _syncQueue;

  static bool _initialized = false;

  /// Whether [init] has completed. Guards against double initialization when
  /// more than one entrypoint or a hot restart runs `init` again.
  static bool get isInitialized => _initialized;

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _registerAdapters();
    _profile = await Hive.openBox<PatientProfile>(profileBoxName);
    _media = await Hive.openBox<MediaItem>(mediaBoxName);
    _reminders = await Hive.openBox<Reminder>(remindersBoxName);
    _sessions = await Hive.openBox<GameResult>(sessionsBoxName);
    _dailyCare = await Hive.openBox<DailyCare>(dailyCareBoxName);
    _alerts = await Hive.openBox<Alert>(alertsBoxName);
    _syncQueue = await Hive.openBox<dynamic>(syncQueueBoxName);
    _initialized = true;
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PatientProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MediaItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReminderAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(GameResultAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(DailyCareAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(AlertAdapter());
    }
  }

  // Raw box accessors (for reactive UIs via `box.listenable()`).
  static Box<PatientProfile> get profileBox => _profile;
  static Box<MediaItem> get mediaBox => _media;
  static Box<Reminder> get remindersBox => _reminders;
  static Box<GameResult> get sessionsBox => _sessions;
  static Box<DailyCare> get dailyCareBox => _dailyCare;
  static Box<Alert> get alertsBox => _alerts;

  // ---- Profile ----------------------------------------------------------
  static Future<void> putProfile(PatientProfile p) => _profile.put(p.id, p);
  static PatientProfile? getProfile(String id) => _profile.get(id);
  static List<PatientProfile> allProfiles() => _profile.values.toList();
  static Future<void> deleteProfile(String id) => _profile.delete(id);

  // ---- Media ------------------------------------------------------------
  static Future<void> putMedia(MediaItem m) => _media.put(m.id, m);
  static MediaItem? getMedia(String id) => _media.get(id);
  static List<MediaItem> allMedia() => _media.values.toList();
  static List<MediaItem> mediaByType(String type) =>
      _media.values.where((m) => m.type == type).toList();
  static Future<void> deleteMedia(String id) => _media.delete(id);

  // ---- Reminders --------------------------------------------------------
  static Future<void> putReminder(Reminder r) => _reminders.put(r.id, r);
  static Reminder? getReminder(String id) => _reminders.get(id);
  static List<Reminder> allReminders() => _reminders.values.toList();
  static Future<void> deleteReminder(String id) => _reminders.delete(id);

  // ---- Sessions (game results) -----------------------------------------
  static Future<void> addSession(GameResult g) => _sessions.put(g.id, g);
  static GameResult? getSession(String id) => _sessions.get(id);
  static List<GameResult> allSessions() => _sessions.values.toList();
  static List<GameResult> sessionsForPatient(String patientId) =>
      _sessions.values.where((g) => g.patientId == patientId).toList();
  static Future<void> deleteSession(String id) => _sessions.delete(id);

  // ---- Daily care (keyed by date) --------------------------------------
  static Future<void> putDailyCare(DailyCare d) => _dailyCare.put(d.date, d);
  static DailyCare? getDailyCare(String date) => _dailyCare.get(date);
  static List<DailyCare> allDailyCare() => _dailyCare.values.toList();
  static Future<void> deleteDailyCare(String date) => _dailyCare.delete(date);

  // ---- Alerts -----------------------------------------------------------
  static Future<void> putAlert(Alert a) => _alerts.put(a.id, a);
  static Alert? getAlert(String id) => _alerts.get(id);
  static List<Alert> allAlerts() => _alerts.values.toList();
  static List<Alert> unseenAlerts() =>
      _alerts.values.where((a) => !a.seen).toList();
  static Future<void> deleteAlert(String id) => _alerts.delete(id);

  // ---- Sync queue -------------------------------------------------------
  /// Queues an entity change for the sync service to push to Firestore later.
  ///
  /// Keyed by `entityType:id` so the queue always holds the latest pending
  /// state for a given entity (re-queuing overwrites rather than piling up).
  static Future<void> addToSyncQueue(
    String entityType,
    String id,
    Map<String, dynamic> json,
  ) {
    final entry = <String, dynamic>{
      'entityType': entityType,
      'id': id,
      'json': json,
      'queuedAt': DateTime.now().toIso8601String(),
    };
    return _syncQueue.put('$entityType:$id', entry);
  }

  /// All pending sync entries (each a map with entityType / id / json / queuedAt).
  static List<Map<dynamic, dynamic>> syncQueueEntries() =>
      _syncQueue.values.whereType<Map<dynamic, dynamic>>().toList();

  static Future<void> removeFromSyncQueue(String entityType, String id) =>
      _syncQueue.delete('$entityType:$id');

  static Future<void> clearSyncQueue() => _syncQueue.clear();
}
