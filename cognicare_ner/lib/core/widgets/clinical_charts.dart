import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/daily_care.dart';
import '../models/game_result.dart';
import '../services/caregiver_note_service.dart' show kDomainLabels;
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The domains shown on the radar / composite, in a stable order.
const List<String> kAllDomains = <String>[
  'memory',
  'attention',
  'auditory',
  'language',
  'executive',
];

/// Average accuracy (0..1) per domain over the last [days]. Domains with no
/// sessions are omitted from the returned map.
Map<String, double> domainAverages(List<GameResult> sessions, {int days = 30}) {
  final DateTime start = DateTime.now().subtract(Duration(days: days));
  final Map<String, List<double>> byDomain = <String, List<double>>{};
  for (final GameResult s in sessions) {
    if (s.at.isBefore(start)) continue;
    byDomain.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
  }
  return <String, double>{
    for (final MapEntry<String, List<double>> e in byDomain.entries)
      e.key: e.value.reduce((a, b) => a + b) / e.value.length,
  };
}

/// A composite cognitive score (0..1) = mean of per-domain averages.
double? compositeScore(List<GameResult> sessions, {int days = 30}) {
  final Map<String, double> avgs = domainAverages(sessions, days: days);
  if (avgs.isEmpty) return null;
  return avgs.values.reduce((a, b) => a + b) / avgs.length;
}

/// Triage severity from recent performance + active alerts.
enum Triage { green, amber, red }

extension TriageStyle on Triage {
  Color get color => switch (this) {
        Triage.green => AppColors.success,
        Triage.amber => AppColors.gentleWarning,
        Triage.red => const Color(0xFFD64545),
      };
  String get label => switch (this) {
        Triage.green => 'Stable',
        Triage.amber => 'Watch',
        Triage.red => 'Review',
      };
}

/// Compute triage: red if an unseen drop alert or composite < 55%; amber if a
/// domain is declining or composite < 70%; else green.
Triage triageFor(List<GameResult> sessions, {bool hasAlert = false}) {
  if (hasAlert) return Triage.red;
  final double? c = compositeScore(sessions);
  if (c == null) return Triage.green;
  if (c < 0.55) return Triage.red;
  if (c < 0.70) return Triage.amber;
  return Triage.green;
}

/// Single composite cognitive-score trend line, with the anomaly change-point
/// (latest cognitive-drop alert) marked as a dashed vertical line.
class CompositeTrendChart extends StatelessWidget {
  const CompositeTrendChart({
    super.key,
    required this.sessions,
    this.alerts = const <Alert>[],
    this.days = 30,
    this.height = 220,
  });

  final List<GameResult> sessions;
  final List<Alert> alerts;
  final int days;
  final double height;

  List<FlSpot> _spots() {
    final DateTime now = DateTime.now();
    final DateTime startDay =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final Map<int, List<double>> byDay = <int, List<double>>{};
    for (final GameResult s in sessions) {
      if (s.at.isBefore(startDay)) continue;
      final int di = s.at.difference(startDay).inDays;
      if (di < 0 || di >= days) continue;
      byDay.putIfAbsent(di, () => <double>[]).add(s.accuracy);
    }
    final List<MapEntry<int, List<double>>> entries = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <FlSpot>[
      for (final MapEntry<int, List<double>> e in entries)
        FlSpot(e.key.toDouble(), e.value.reduce((a, b) => a + b) / e.value.length),
    ];
  }

  double? _changePointX() {
    final List<Alert> drops =
        alerts.where((a) => a.type == 'cognitive_drop').toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    if (drops.isEmpty) return null;
    final DateTime now = DateTime.now();
    final DateTime startDay =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final int di = drops.first.at.difference(startDay).inDays;
    if (di < 0 || di >= days) return null;
    return di.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = _spots();
    if (spots.isEmpty) {
      return Text('No sessions in this period yet.',
          style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 14));
    }
    final double maxX = (days - 1).toDouble();
    final double? cp = _changePointX();
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: 1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppColors.border.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: <int>[4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 0.5,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text('${(v * 100).round()}%',
                    style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 12)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (days / 4).round().toDouble(),
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final int daysAgo = (maxX - v).round();
                  if (daysAgo < 0 || daysAgo >= days) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(daysAgo == 0 ? 'Today' : '${daysAgo}d',
                        style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 12)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: cp == null
              ? const ExtraLinesData()
              : ExtraLinesData(verticalLines: <VerticalLine>[
                  VerticalLine(
                    x: cp,
                    color: const Color(0xFFD64545),
                    strokeWidth: 2,
                    dashArray: <int>[6, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topCenter,
                      style: AppText.body(color: const Color(0xFFD64545))
                          .copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                      labelResolver: (_) => 'alert',
                    ),
                  ),
                ]),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-domain radar/spider chart of average accuracy over the period.
class DomainRadarChart extends StatelessWidget {
  const DomainRadarChart({
    super.key,
    required this.sessions,
    this.days = 30,
    this.size = 260,
    this.color = AppColors.primary,
  });

  final List<GameResult> sessions;
  final int days;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> avgs = domainAverages(sessions, days: days);
    // Radar needs at least 3 axes; always render the full domain set.
    final List<double> values =
        kAllDomains.map((d) => (avgs[d] ?? 0) * 100).toList();
    if (avgs.isEmpty) {
      return Text('Not enough data for a domain profile yet.',
          style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 14));
    }
    return SizedBox(
      height: size,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
          radarBorderData: BorderSide(color: AppColors.border, width: 1),
          gridBorderData: BorderSide(color: AppColors.border.withValues(alpha: 0.6), width: 1),
          tickBorderData: BorderSide(color: AppColors.border.withValues(alpha: 0.4), width: 1),
          titlePositionPercentageOffset: 0.12,
          getTitle: (index, angle) => RadarChartTitle(
            text: kDomainLabels[kAllDomains[index]] ?? kAllDomains[index],
          ),
          titleTextStyle: AppText.body(color: AppColors.text).copyWith(fontSize: 12),
          dataSets: <RadarDataSet>[
            RadarDataSet(
              fillColor: color.withValues(alpha: 0.18),
              borderColor: color,
              borderWidth: 2,
              entryRadius: 3,
              dataEntries: <RadarEntry>[
                for (final double v in values) RadarEntry(value: v),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 7-day medication/hydration/meal adherence strip.
class AdherenceStrip extends StatelessWidget {
  const AdherenceStrip({super.key, required this.care, this.days = 7});

  final List<DailyCare> care;
  final int days;

  @override
  Widget build(BuildContext context) {
    final Map<String, DailyCare> byDate = <String, DailyCare>{
      for (final DailyCare c in care) c.date: c,
    };
    final DateTime now = DateTime.now();
    final List<Widget> cols = <Widget>[];
    for (int i = days - 1; i >= 0; i--) {
      final DateTime day = now.subtract(Duration(days: i));
      final String key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final DailyCare? c = byDate[key];
      // Simple completion score: meds present, hydration>=4, meals>=2.
      final bool meds = (c?.medsTaken.isNotEmpty ?? false);
      final bool water = (c?.hydrationCount ?? 0) >= 4;
      final bool meals = (c?.mealsLogged.length ?? 0) >= 2;
      final int score = (meds ? 1 : 0) + (water ? 1 : 0) + (meals ? 1 : 0);
      final Color col = c == null
          ? AppColors.border
          : (score >= 3
              ? AppColors.success
              : (score >= 1 ? AppColors.gentleWarning : const Color(0xFFD64545)));
      cols.add(Expanded(
        child: Column(
          children: <Widget>[
            Container(
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: col.withValues(alpha: c == null ? 0.25 : 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 4),
            Text(_dow(day.weekday),
                style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 11)),
          ],
        ),
      ));
    }
    return Row(children: cols);
  }

  String _dow(int weekday) =>
      const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'][(weekday - 1) % 7];
}
