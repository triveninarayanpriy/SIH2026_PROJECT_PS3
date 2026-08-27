import '../../core/models/alert.dart';
import '../../core/models/daily_care.dart';
import '../../core/models/game_result.dart';
import '../../core/models/patient_profile.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/local_db.dart';

/// A single row in the doctor's patient list.
class DoctorPatientRow {
  const DoctorPatientRow({
    required this.id,
    required this.name,
    required this.stage,
    required this.hasAlert,
    this.lastActive,
  });

  final String id;
  final String name;
  final int stage;
  final DateTime? lastActive;
  final bool hasAlert;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'stage': stage,
        'lastActive': lastActive?.toIso8601String(),
        'hasAlert': hasAlert,
      };

  factory DoctorPatientRow.fromMap(Map<String, dynamic> m) => DoctorPatientRow(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        stage: (m['stage'] as num?)?.toInt() ?? 0,
        lastActive: (m['lastActive'] is String)
            ? DateTime.tryParse(m['lastActive'] as String)
            : null,
        hasAlert: (m['hasAlert'] as bool?) ?? false,
      );
}

/// Everything the patient-detail screen shows.
class DoctorPatientData {
  const DoctorPatientData({
    required this.profile,
    required this.sessions,
    required this.alerts,
    required this.dailyCare,
  });

  final PatientProfile? profile;
  final List<GameResult> sessions;
  final List<Alert> alerts;
  final List<DailyCare> dailyCare;
}

/// Read-only Firestore access for the doctor tier, with a LocalDb cache so the
/// dashboard loads instantly and still shows data when offline.
class DoctorRepository {
  DoctorRepository._();

  static final FirestoreService _fs = FirestoreService();

  static String _rowsKey(String uid) => 'doctorRows_$uid';
  static String _detailKey(String id) => 'doctorDetail_$id';

  // ---- Patient list rows ------------------------------------------------

  static List<DoctorPatientRow> cachedRows(String uid) {
    final Object? raw = LocalDb.getSetting(_rowsKey(uid));
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => DoctorPatientRow.fromMap(m.cast<String, dynamic>()))
          .toList();
    }
    return const <DoctorPatientRow>[];
  }

  static Future<List<DoctorPatientRow>> fetchRows(String uid) async {
    final List<String> ids =
        await _fs.patientIdsForRole(uid: uid, isDoctor: true);
    final List<DoctorPatientRow> rows = <DoctorPatientRow>[];
    for (final String id in ids) {
      final Map<String, dynamic>? doc = await _fs.fetchPatientDoc(id);
      final PatientProfile? profile =
          (doc != null && doc.isNotEmpty) ? PatientProfile.fromMap(doc) : null;
      final DateTime? lastActive = await _fs.fetchLatestSessionAt(id);
      final List<Map<String, dynamic>> alerts = await _fs.fetchAlerts(id);
      final bool hasAlert = alerts.any((a) =>
          (a['type'] as String?) == 'cognitive_drop' &&
          (a['seen'] as bool?) != true);
      rows.add(DoctorPatientRow(
        id: id,
        name: profile?.name ?? id,
        stage: profile?.stage ?? 0,
        lastActive: lastActive,
        hasAlert: hasAlert,
      ));
    }
    await LocalDb.putSetting(
        _rowsKey(uid), rows.map((r) => r.toMap()).toList());
    return rows;
  }

  // ---- Patient detail ---------------------------------------------------

  static DoctorPatientData? cachedDetail(String id) {
    final Object? raw = LocalDb.getSetting(_detailKey(id));
    if (raw is! Map) return null;
    final Map<String, dynamic> m = raw.cast<String, dynamic>();
    final Object? profile = m['profile'];
    return DoctorPatientData(
      profile: (profile is Map)
          ? PatientProfile.fromMap(profile.cast<String, dynamic>())
          : null,
      sessions: _mapList(m['sessions']).map(GameResult.fromMap).toList(),
      alerts: _mapList(m['alerts']).map(Alert.fromMap).toList(),
      dailyCare: _mapList(m['dailyCare']).map(DailyCare.fromMap).toList(),
    );
  }

  static Future<DoctorPatientData> fetchDetail(String id) async {
    final Map<String, dynamic>? doc = await _fs.fetchPatientDoc(id);
    final List<Map<String, dynamic>> sessions = await _fs.fetchSessions(id);
    final List<Map<String, dynamic>> alerts = await _fs.fetchAlerts(id);
    final List<Map<String, dynamic>> care = await _fs.fetchDailyCare(id);

    await LocalDb.putSetting(_detailKey(id), <String, dynamic>{
      'profile': doc,
      'sessions': sessions,
      'alerts': alerts,
      'dailyCare': care,
    });

    return DoctorPatientData(
      profile: (doc != null && doc.isNotEmpty)
          ? PatientProfile.fromMap(doc)
          : null,
      sessions: sessions.map(GameResult.fromMap).toList(),
      alerts: alerts.map(Alert.fromMap).toList(),
      dailyCare: care.map(DailyCare.fromMap).toList(),
    );
  }

  static List<Map<String, dynamic>> _mapList(Object? v) => (v is List)
      ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
      : const <Map<String, dynamic>>[];
}
