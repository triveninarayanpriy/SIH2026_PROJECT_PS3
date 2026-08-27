import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/alert.dart';
import '../../core/models/game_result.dart';
import '../../core/models/patient_profile.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/big_card.dart';

/// Read-only doctor view of one patient: profile, per-domain performance,
/// recent sessions, and alerts. Sized for the web dashboard (compact text,
/// centered max-width content).
class DoctorPatientDetail extends StatefulWidget {
  const DoctorPatientDetail({super.key, required this.patientId});

  final String patientId;

  @override
  State<DoctorPatientDetail> createState() => _DoctorPatientDetailState();
}

class _DoctorPatientDetailState extends State<DoctorPatientDetail> {
  final FirestoreService _fs = FirestoreService();

  PatientProfile? _profile;
  List<GameResult> _sessions = <GameResult>[];
  List<Alert> _alerts = <Alert>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic>? p = await _fs.fetchPatientDoc(widget.patientId);
      final List<Map<String, dynamic>> s =
          await _fs.fetchSessions(widget.patientId);
      final List<Map<String, dynamic>> a =
          await _fs.fetchAlerts(widget.patientId);
      if (!mounted) return;
      setState(() {
        _profile = (p != null && p.isNotEmpty) ? PatientProfile.fromMap(p) : null;
        _sessions = s.map(GameResult.fromMap).toList()
          ..sort((x, y) => y.at.compareTo(x.at));
        _alerts = a.map(Alert.fromMap).toList()
          ..sort((x, y) => y.at.compareTo(x.at));
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this patient. Check your connection.';
        _loading = false;
      });
    }
  }

  Map<String, double> _accuracyByDomain() {
    final Map<String, List<double>> byDomain = <String, List<double>>{};
    for (final GameResult s in _sessions) {
      byDomain.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
    }
    return byDomain.map((k, v) =>
        MapEntry(k, v.reduce((a, b) => a + b) / v.length));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.name ?? 'Patient'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(_error!,
                            style: _t(15, color: AppColors.gentleWarning)),
                        const SizedBox(height: 16),
                      ],
                      _profileCard(),
                      const SizedBox(height: 16),
                      _performanceCard(),
                      const SizedBox(height: 16),
                      _alertsCard(),
                      const SizedBox(height: 16),
                      _sessionsCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _profileCard() {
    final PatientProfile? p = _profile;
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p?.name ?? widget.patientId, style: _t(24, weight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            p == null
                ? 'Code ${widget.patientId}'
                : 'Age ${p.age}  ·  Stage ${p.stage}  ·  ${p.region}  ·  ${p.id}',
            style: _t(15, color: AppColors.textMuted),
          ),
          if (p != null && p.languages.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Languages: ${p.languages.join(', ')}',
                style: _t(14, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _performanceCard() {
    final Map<String, double> byDomain = _accuracyByDomain();
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance by domain', style: _t(18, weight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Average accuracy across all sessions',
              style: _t(13, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          if (byDomain.isEmpty)
            Text('No game sessions yet.',
                style: _t(15, color: AppColors.textMuted))
          else
            SizedBox(height: 220, child: _domainChart(byDomain)),
        ],
      ),
    );
  }

  Widget _domainChart(Map<String, double> byDomain) {
    final List<String> domains = byDomain.keys.toList();
    return BarChart(
      BarChartData(
        maxY: 1,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: const BarTouchData(enabled: false),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.25,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 0.25,
              reservedSize: 44,
              getTitlesWidget: (value, _) => Text(
                '${(value * 100).round()}%',
                style: _t(12, color: AppColors.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, _) {
                final int i = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    (i >= 0 && i < domains.length) ? domains[i] : '',
                    style: _t(13),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < domains.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: byDomain[domains[i]]!,
                  width: 28,
                  color: _domainColor(i),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _domainColor(int i) {
    const List<Color> palette = <Color>[
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.gentleWarning,
    ];
    return palette[i % palette.length];
  }

  Widget _alertsCard() {
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alerts', style: _t(18, weight: FontWeight.w500)),
          const SizedBox(height: 12),
          if (_alerts.isEmpty)
            Text('No alerts.', style: _t(15, color: AppColors.textMuted))
          else
            ..._alerts.take(10).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.gentleWarning, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${a.domain}: ${a.deltaPct.toStringAsFixed(0)}% drop  '
                          '·  ${DateFormat('MMM d, y').format(a.at)}',
                          style: _t(15),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _sessionsCard() {
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent sessions', style: _t(18, weight: FontWeight.w500)),
          const SizedBox(height: 12),
          if (_sessions.isEmpty)
            Text('No sessions recorded yet.',
                style: _t(15, color: AppColors.textMuted))
          else
            ..._sessions.take(12).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text('${s.game} · ${s.domain}', style: _t(15)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${(s.accuracy * 100).round()}%',
                          style: _t(15, weight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat('MMM d, h:mm a').format(s.at),
                          textAlign: TextAlign.right,
                          style: _t(13, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // Compact text helper for the (non-elderly) doctor web surface.
  TextStyle _t(double size, {Color? color, FontWeight? weight}) =>
      AppText.body(color: color).copyWith(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
      );
}
