import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// One line on the trend chart: a session domain key, its label, and colour.
class DomainSeries {
  const DomainSeries(this.domainKey, this.label, this.color);
  final String domainKey;
  final String label;
  final Color color;
}

const List<DomainSeries> kDomainSeries = <DomainSeries>[
  DomainSeries('memory', 'Memory', AppColors.primary),
  DomainSeries('attention', 'Attention', AppColors.secondary),
  DomainSeries('auditory', 'Listening', AppColors.success),
];

/// Reusable per-domain accuracy trend chart (daily averages over [days]).
class DomainTrendChart extends StatelessWidget {
  const DomainTrendChart({
    super.key,
    required this.sessions,
    this.days = 30,
    this.series = kDomainSeries,
    this.height = 240,
  });

  final List<GameResult> sessions;
  final int days;
  final List<DomainSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool anyData =
        series.any((d) => _spots(d.domainKey).isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legend(),
        const SizedBox(height: 16),
        if (!anyData)
          Text('No game sessions in this period yet.',
              style: AppText.body(color: AppColors.textMuted)
                  .copyWith(fontSize: 15))
        else
          SizedBox(height: height, child: _chart()),
      ],
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final DomainSeries d in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(color: d.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(d.label,
                  style: AppText.body(color: AppColors.textMuted)
                      .copyWith(fontSize: 14)),
            ],
          ),
      ],
    );
  }

  Widget _chart() {
    final double maxX = (days - 1).toDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: 1,
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
              interval: 0.5,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text('${(v * 100).round()}%',
                  style: AppText.body(color: AppColors.textMuted)
                      .copyWith(fontSize: 12)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: days <= 7 ? 3 : 10,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final int daysAgo = (maxX - v).round();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(daysAgo == 0 ? 'today' : '${daysAgo}d',
                      style: AppText.body(color: AppColors.textMuted)
                          .copyWith(fontSize: 12)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          for (final DomainSeries d in series)
            LineChartBarData(
              spots: _spots(d.domainKey),
              isCurved: true,
              color: d.color,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }

  List<FlSpot> _spots(String domain) {
    final DateTime now = DateTime.now();
    final DateTime startDay = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final Map<int, List<double>> byDay = <int, List<double>>{};
    for (final GameResult s in sessions) {
      if (s.domain != domain || s.at.isBefore(startDay)) continue;
      final int di = s.at.difference(startDay).inDays;
      if (di < 0 || di >= days) continue;
      byDay.putIfAbsent(di, () => <double>[]).add(s.accuracy);
    }
    final List<MapEntry<int, List<double>>> entries = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      for (final MapEntry<int, List<double>> e in entries)
        FlSpot(e.key.toDouble(),
            e.value.reduce((a, b) => a + b) / e.value.length),
    ];
  }
}
