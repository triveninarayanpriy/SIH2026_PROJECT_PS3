import 'package:cloud_firestore/cloud_firestore.dart';

/// Central access point for CogniCare NER's Firestore data.
///
/// Collections mirror the platform architecture (§4.1 "Suggested data model"):
///
/// ```text
/// patients/{patientId}
///   ├─ profile   { name, age, stage, languages[], region }   (doc field)
///   ├─ media     { photos[], music[], familyFaces[] }         (doc field)
///   ├─ reminders { type, time, audioClipUrl, repeat }         (doc field)
///   ├─ sessions/{sessionId}  { game, startTime, durationMs,
///   │                          accuracy, correct, total,
///   │                          domain, difficulty }
///   ├─ dailyCare/{date}      { medsTaken[], hydrationCount, mealsLogged }
///   └─ alerts/{alertId}      { type:'cognitive_drop', domain, delta,
///                              date, seen }
///
/// caregivers/{uid} { patientIds[] }
/// doctors/{uid}    { patientIds[] }
/// ```
///
/// The typed collection/document accessors below are implemented; the
/// higher-level read/write helpers are intentionally stubbed with TODOs and
/// will take strongly-typed models (GameResult, PatientProfile, …) once the
/// `core/models` layer is defined.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ---------------------------------------------------------------------------
  // Typed collection / document references
  // ---------------------------------------------------------------------------

  /// Root `patients` collection.
  CollectionReference<Map<String, dynamic>> get patients =>
      _db.collection('patients');

  /// Root `caregivers` collection (`{ patientIds[] }` per caregiver uid).
  CollectionReference<Map<String, dynamic>> get caregivers =>
      _db.collection('caregivers');

  /// Root `doctors` collection (`{ patientIds[] }` per doctor uid).
  CollectionReference<Map<String, dynamic>> get doctors =>
      _db.collection('doctors');

  /// A single patient document.
  DocumentReference<Map<String, dynamic>> patientDoc(String patientId) =>
      patients.doc(patientId);

  /// `patients/{patientId}/sessions` — one game result per document.
  CollectionReference<Map<String, dynamic>> sessions(String patientId) =>
      patientDoc(patientId).collection('sessions');

  /// `patients/{patientId}/dailyCare` — one document per calendar date.
  CollectionReference<Map<String, dynamic>> dailyCare(String patientId) =>
      patientDoc(patientId).collection('dailyCare');

  /// `patients/{patientId}/alerts` — anomaly / cognitive-drop alerts.
  CollectionReference<Map<String, dynamic>> alerts(String patientId) =>
      patientDoc(patientId).collection('alerts');

  /// `patients/{patientId}/media` — one document per MediaItem.
  ///
  /// Media (and reminders) are modelled as per-item subcollections rather than
  /// array fields so the offline sync engine can push each item as its own
  /// document (its own [DocumentReference] / docPath), avoiding array
  /// read-modify-write conflicts when several edits are queued offline.
  CollectionReference<Map<String, dynamic>> media(String patientId) =>
      patientDoc(patientId).collection('media');

  /// `patients/{patientId}/reminders` — one document per Reminder.
  CollectionReference<Map<String, dynamic>> reminders(String patientId) =>
      patientDoc(patientId).collection('reminders');

  // ---------------------------------------------------------------------------
  // Patient profile / media / reminders  (fields on the patient doc)
  // ---------------------------------------------------------------------------

  /// Creates or updates a patient's `profile` block.
  Future<void> upsertProfile(String patientId, Map<String, dynamic> profile) {
    // TODO: accept a typed PatientProfile model and merge-write to
    // patients/{patientId} with { 'profile': profile }.
    throw UnimplementedError('TODO: implement upsertProfile');
  }

  /// Streams a patient's full document (profile + media + reminders).
  Stream<Map<String, dynamic>?> watchPatient(String patientId) {
    // TODO: map DocumentSnapshot -> typed Patient model.
    throw UnimplementedError('TODO: implement watchPatient');
  }

  /// Updates the `media` block (photos / music / family faces).
  Future<void> setMedia(String patientId, Map<String, dynamic> media) {
    // TODO: accept a typed Media model.
    throw UnimplementedError('TODO: implement setMedia');
  }

  /// Updates the `reminders` block (meds / hydration / meals / appointments).
  Future<void> setReminders(String patientId, Map<String, dynamic> reminders) {
    // TODO: accept a typed Reminders model.
    throw UnimplementedError('TODO: implement setReminders');
  }

  // ---------------------------------------------------------------------------
  // Sessions  (game results — the uniform GameResult object)
  // ---------------------------------------------------------------------------

  /// Appends one game session (score / accuracy / domain / difficulty …).
  Future<void> addSession(String patientId, Map<String, dynamic> session) {
    // TODO: accept a typed GameResult and write to sessions(patientId).
    throw UnimplementedError('TODO: implement addSession');
  }

  /// Streams recent sessions for a patient (newest first), optionally by domain.
  Stream<List<Map<String, dynamic>>> watchSessions(
    String patientId, {
    String? domain,
    int limit = 50,
  }) {
    // TODO: query sessions(patientId).orderBy('startTime', descending: true),
    // filter by domain when provided, and map to typed GameResult list.
    throw UnimplementedError('TODO: implement watchSessions');
  }

  // ---------------------------------------------------------------------------
  // Daily care log  (requirement f)
  // ---------------------------------------------------------------------------

  /// Writes the daily-care log for a given date (meds / hydration / meals).
  Future<void> setDailyCare(
    String patientId,
    String date,
    Map<String, dynamic> care,
  ) {
    // TODO: accept a typed DailyCare model keyed by yyyy-MM-dd.
    throw UnimplementedError('TODO: implement setDailyCare');
  }

  // ---------------------------------------------------------------------------
  // Alerts  (anomaly / cognitive-drop early warning)
  // ---------------------------------------------------------------------------

  /// Raises a new alert (e.g. `cognitive_drop`) for a patient.
  Future<void> addAlert(String patientId, Map<String, dynamic> alert) {
    // TODO: accept a typed Alert model.
    throw UnimplementedError('TODO: implement addAlert');
  }

  /// Streams unseen alerts for a patient (for caregiver + doctor surfaces).
  Stream<List<Map<String, dynamic>>> watchAlerts(String patientId) {
    // TODO: query alerts(patientId).where('seen', isEqualTo: false).
    throw UnimplementedError('TODO: implement watchAlerts');
  }

  // ---------------------------------------------------------------------------
  // Role <-> patient links  (caregivers / doctors)
  // ---------------------------------------------------------------------------

  /// Links a patient to a caregiver / doctor account (`patientIds[]`).
  Future<void> linkPatientToRole({
    required String uid,
    required String patientId,
    required bool isDoctor,
  }) {
    // TODO: arrayUnion patientId into caregivers/{uid} or doctors/{uid}.
    throw UnimplementedError('TODO: implement linkPatientToRole');
  }

  /// Lists the patient ids a caregiver / doctor can access.
  Future<List<String>> patientIdsForRole({
    required String uid,
    required bool isDoctor,
  }) {
    // TODO: read patientIds[] from caregivers/{uid} or doctors/{uid}.
    throw UnimplementedError('TODO: implement patientIdsForRole');
  }

  // ---------------------------------------------------------------------------
  // Generic document access used by the offline sync engine
  // ---------------------------------------------------------------------------

  /// Writes [data] to the document at [path], merging with any existing doc so
  /// an offline-created document is created on first sync and merged after.
  Future<void> setDoc(String path, Map<String, dynamic> data) =>
      _db.doc(path).set(data, SetOptions(merge: true));

  /// Applies a partial update to the document at [path]. Falls back to a
  /// merge-set when the document does not exist yet (e.g. it was created
  /// offline and its parent has not synced), so a queued update never wedges.
  Future<void> updateDoc(String path, Map<String, dynamic> data) async {
    final DocumentReference<Map<String, dynamic>> ref = _db.doc(path);
    try {
      await ref.update(data);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await ref.set(data, SetOptions(merge: true));
      } else {
        rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Typed reads for the initial cloud -> local pull
  // ---------------------------------------------------------------------------

  /// The patient document (holds the profile fields), or null if absent.
  Future<Map<String, dynamic>?> fetchPatientDoc(String patientId) async {
    final snap = await patientDoc(patientId).get();
    return snap.data();
  }

  Future<List<Map<String, dynamic>>> _fetchAll(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await ref.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMedia(String patientId) =>
      _fetchAll(media(patientId));

  Future<List<Map<String, dynamic>>> fetchReminders(String patientId) =>
      _fetchAll(reminders(patientId));

  Future<List<Map<String, dynamic>>> fetchSessions(String patientId) =>
      _fetchAll(sessions(patientId));

  Future<List<Map<String, dynamic>>> fetchDailyCare(String patientId) =>
      _fetchAll(dailyCare(patientId));

  Future<List<Map<String, dynamic>>> fetchAlerts(String patientId) =>
      _fetchAll(alerts(patientId));
}
