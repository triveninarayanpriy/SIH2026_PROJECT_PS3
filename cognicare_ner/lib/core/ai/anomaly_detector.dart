import 'package:uuid/uuid.dart';

import '../models/alert.dart';
import '../models/game_result.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// The outcome of the drop rule for one domain.
class DropResult {
  const DropResult({
    required this.deltaPct,
    required this.baseline,
    required this.recent,
  });

  /// Relative drop as a percentage, e.g. 24.0 for a 24% decline.
  final double deltaPct;
  final double baseline;
  final double recent;
}

/// Explainable, per-domain cognitive-drop detector.
///
/// Rule: over a domain's chronological accuracy list, once there are at least
/// [minSamples] results, compare the mean of all-but-the-last-[recentWindow]
/// (baseline) with the mean of the last [recentWindow] (recent). If the
/// relative drop exceeds [dropThreshold], it's a cognitive_drop. Debounced to at
/// most one alert per domain per [debounce].
class AnomalyDetector {
  AnomalyDetector._();

  static final AnomalyDetector instance = AnomalyDetector._();

  static const int minSamples = 8;
  static const int recentWindow = 3;
  static const double dropThreshold = 0.22;
  static const Duration debounce = Duration(days: 7);

  final Uuid _uuid = const Uuid();

  static double _mean(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  /// Pure rule (no I/O): returns a [DropResult] when a drop is detected, else
  /// null. [accuracies] must be in chronological order (oldest first).
  static DropResult? detectDrop(List<double> accuracies) {
    if (accuracies.length < minSamples) return null;
    final int split = accuracies.length - recentWindow;
    final double baseline = _mean(accuracies.sublist(0, split));
    final double recent = _mean(accuracies.sublist(split));
    if (baseline <= 0) return null;
    final double ratio = (baseline - recent) / baseline;
    if (ratio > dropThreshold) {
      return DropResult(deltaPct: ratio * 100, baseline: baseline, recent: recent);
    }
    return null;
  }

  /// Runs detection across every domain in the patient's history, writing (and
  /// returning) any new alerts to LocalDb + the sync queue. Debounced per domain.
  Future<List<Alert>> runForPatient(String patientId, {DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final List<GameResult> sessions = LocalDb.sessionsForPatient(patientId);
    final Set<String> domains = sessions.map((s) => s.domain).toSet();

    final List<Alert> raised = <Alert>[];
    for (final String domain in domains) {
      final List<GameResult> chrono = sessions
          .where((s) => s.domain == domain)
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      final List<double> acc = chrono.map((s) => s.accuracy).toList();

      final DropResult? drop = detectDrop(acc);
      if (drop == null) continue;
      if (_debounced(patientId, domain, at)) continue;

      final Alert alert = Alert(
        id: _uuid.v4(),
        patientId: patientId,
        type: 'cognitive_drop',
        domain: domain,
        deltaPct: drop.deltaPct,
        at: at,
        seen: false,
      );
      await SyncService.instance.saveAlert(alert);
      raised.add(alert);
    }
    return raised;
  }

  bool _debounced(String patientId, String domain, DateTime at) {
    for (final Alert a in LocalDb.allAlerts()) {
      if (a.patientId == patientId &&
          a.domain == domain &&
          a.type == 'cognitive_drop' &&
          at.difference(a.at).abs() < debounce) {
        return true;
      }
    }
    return false;
  }
}
