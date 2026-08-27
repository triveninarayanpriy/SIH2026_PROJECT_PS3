import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/alert.dart';
import '../models/daily_care.dart';
import '../models/game_result.dart';
import '../models/media_item.dart';
import '../models/patient_profile.dart';
import '../models/reminder.dart';
import 'firestore_service.dart';
import 'local_db.dart';

/// Offline-first sync engine.
///
/// Every app write goes to [LocalDb] first (instant, offline) and is also
/// enqueued in the local sync queue. When a connection is available the queue
/// is drained to Firestore and the patient's cloud documents are pulled back
/// into [LocalDb]. All of this runs in the background — the UI is never
/// blocked and reads only ever hit the local store.
///
/// Firestore layout (see [FirestoreService]):
/// ```text
/// patients/{patientId}                         <- profile fields
/// patients/{patientId}/media/{mediaId}
/// patients/{patientId}/reminders/{reminderId}
/// patients/{patientId}/sessions/{sessionId}
/// patients/{patientId}/dailyCare/{date}
/// patients/{patientId}/alerts/{alertId}
/// caregivers/{uid} { patientIds[] }
/// doctors/{uid}    { patientIds[] }
/// ```
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final FirestoreService _fs = FirestoreService();
  final Connectivity _connectivity = Connectivity();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  static const String statusOffline = 'offline';
  static const String statusSyncing = 'syncing';
  static const String statusSynced = 'synced';

  String _status = statusOffline;
  String? _patientId;
  bool _draining = false;
  bool _initialized = false;

  /// Current status: `'offline'` | `'syncing'` | `'synced'`.
  String get currentStatus => _status;

  /// Status stream for a small sync chip in the UI.
  Stream<String> get status => _statusController.stream;

  /// Sets up the connectivity listener and, if online, runs an initial drain
  /// then a cloud pull. Safe to call from every entrypoint; only the first
  /// call wires the listener. Never blocks the caller for real work.
  Future<void> init({String? patientId}) async {
    if (patientId != null) _patientId = patientId;
    if (!_initialized) {
      _initialized = true;
      _connSub =
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    }
    if (await _isOnline()) {
      await _syncNow();
    } else {
      _setStatus(statusOffline);
    }
  }

  /// Points the engine at a patient and kicks a background sync (used once a
  /// patient is selected / created).
  void setPatient(String patientId) {
    _patientId = patientId;
    unawaited(_syncNow());
  }

  // ---------------------------------------------------------------------------
  // Write-through helpers: persist locally + enqueue for cloud sync.
  // Callers await only the fast local write; the cloud flush is background.
  // ---------------------------------------------------------------------------

  Future<void> saveProfile(PatientProfile p) async {
    await LocalDb.putProfile(p);
    await _enqueue('profile', 'patients/${p.id}', p.toMap());
  }

  Future<void> saveMedia(String patientId, MediaItem m) async {
    await LocalDb.putMedia(m);
    await _enqueue('media', 'patients/$patientId/media/${m.id}', m.toMap());
  }

  Future<void> saveReminder(String patientId, Reminder r) async {
    await LocalDb.putReminder(r);
    await _enqueue(
      'reminder',
      'patients/$patientId/reminders/${r.id}',
      r.toMap(),
    );
  }

  Future<void> saveGameResult(GameResult g) async {
    await LocalDb.addSession(g);
    await _enqueue(
      'session',
      'patients/${g.patientId}/sessions/${g.id}',
      g.toMap(),
    );
  }

  Future<void> saveDailyCare(String patientId, DailyCare d) async {
    await LocalDb.putDailyCare(d);
    await _enqueue(
      'dailyCare',
      'patients/$patientId/dailyCare/${d.date}',
      d.toMap(),
    );
  }

  Future<void> saveAlert(Alert a) async {
    await LocalDb.putAlert(a);
    await _enqueue(
      'alert',
      'patients/${a.patientId}/alerts/${a.id}',
      a.toMap(),
    );
  }

  Future<void> _enqueue(
    String entityType,
    String docPath,
    Map<String, dynamic> json, {
    String op = 'set',
  }) async {
    await LocalDb.addToSyncQueue(entityType, docPath, json, op: op);
    // Try to flush immediately if online, but never block the caller/UI.
    unawaited(_syncNow());
  }

  /// Public trigger for a background sync (e.g. a manual "sync now" / demo).
  Future<void> syncNow() => _syncNow();

  // ---------------------------------------------------------------------------
  // Core sync loop
  // ---------------------------------------------------------------------------

  Future<void> _syncNow() async {
    if (_draining) return;
    if (!await _isOnline()) {
      _setStatus(statusOffline);
      return;
    }
    _draining = true;
    _setStatus(statusSyncing);
    try {
      await _drainQueue();
      final String? pid = _patientId;
      if (pid != null) await _pullPatient(pid);
      _setStatus(statusSynced);
    } catch (_) {
      // Lost connectivity or a transient error mid-sync: reflect real state
      // and leave any un-drained entries queued for the next attempt.
      _setStatus(await _isOnline() ? statusSynced : statusOffline);
    } finally {
      _draining = false;
    }
  }

  Future<void> _drainQueue() async {
    for (final entry in LocalDb.syncQueueEntries()) {
      final String? docPath = entry['docPath'] as String?;
      final Map<String, dynamic>? json =
          (entry['json'] as Map?)?.cast<String, dynamic>();
      final String op = (entry['op'] as String?) ?? 'set';
      if (docPath == null || json == null) {
        // Malformed entry — drop it so it can't wedge the queue.
        if (docPath != null) await LocalDb.removeFromSyncQueue(docPath);
        continue;
      }
      // Guard against an indefinite hang if the connection drops mid-write.
      final Future<void> write = op == 'update'
          ? _fs.updateDoc(docPath, json)
          : _fs.setDoc(docPath, json);
      await write.timeout(const Duration(seconds: 15));
      await LocalDb.removeFromSyncQueue(docPath);
    }
  }

  /// Pulls the patient's cloud documents into [LocalDb].
  ///
  /// Conflict policy: cloud wins for profile / media / reminders / dailyCare /
  /// alerts; local wins for sessions (append-only — only cloud sessions missing
  /// locally are added, existing local ones are never overwritten). Locally
  /// cached file paths are preserved when the cloud copy has none.
  Future<void> _pullPatient(String patientId) async {
    final Map<String, dynamic>? profileMap =
        await _fs.fetchPatientDoc(patientId);
    if (profileMap != null && profileMap.isNotEmpty) {
      await LocalDb.putProfile(PatientProfile.fromMap(profileMap));
    }

    for (final map in await _fs.fetchMedia(patientId)) {
      final MediaItem cloud = MediaItem.fromMap(map);
      final MediaItem? local = LocalDb.getMedia(cloud.id);
      final MediaItem merged =
          (cloud.localPath == null && local?.localPath != null)
              ? MediaItem(
                  id: cloud.id,
                  type: cloud.type,
                  url: cloud.url,
                  localPath: local!.localPath,
                  label: cloud.label,
                )
              : cloud;
      await LocalDb.putMedia(merged);
    }

    for (final map in await _fs.fetchReminders(patientId)) {
      final Reminder cloud = Reminder.fromMap(map);
      final Reminder? local = LocalDb.getReminder(cloud.id);
      final Reminder merged =
          (cloud.audioLocalPath == null && local?.audioLocalPath != null)
              ? Reminder(
                  id: cloud.id,
                  type: cloud.type,
                  title: cloud.title,
                  time: cloud.time,
                  audioClipUrl: cloud.audioClipUrl,
                  audioLocalPath: local!.audioLocalPath,
                  repeatDaily: cloud.repeatDaily,
                )
              : cloud;
      await LocalDb.putReminder(merged);
    }

    // Sessions: local-wins — only add cloud sessions we don't already have.
    for (final map in await _fs.fetchSessions(patientId)) {
      final GameResult cloud = GameResult.fromMap(map);
      if (LocalDb.getSession(cloud.id) == null) {
        await LocalDb.addSession(cloud);
      }
    }

    for (final map in await _fs.fetchDailyCare(patientId)) {
      await LocalDb.putDailyCare(DailyCare.fromMap(map));
    }

    for (final map in await _fs.fetchAlerts(patientId)) {
      await LocalDb.putAlert(Alert.fromMap(map));
    }
  }

  Future<bool> _isOnline() async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final bool online = results.any((r) => r != ConnectivityResult.none);
    if (online) {
      unawaited(_syncNow());
    } else {
      _setStatus(statusOffline);
    }
  }

  void _setStatus(String value) {
    _status = value;
    if (!_statusController.isClosed) _statusController.add(value);
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    await _statusController.close();
    _initialized = false;
  }
}
