import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/game_result.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_card.dart';
import 'caregiver_alert_banner.dart';

/// One tracked cognitive domain: its session key, label, and line colour.
class _Domain {
  const _Domain(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;
}

const List<_Domain> _domains = <_Domain>[
  _Domain('memory', 'Memory', AppColors.primary),
  _Domain('attention', 'Attention', AppColors.secondary),
  _Domain('auditory', 'Listening', AppColors.success),
];

/// Caregiver progress dashboard: per-domain accuracy trends (7 / 30 days),
/// current difficulty per game, sessions this week, and the alert banner.
class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key, required this.patientId});

  final String patientId;

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  int _windowDays = 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ValueListenableBuilder<Box<GameResult>>(
            valueListenable: LocalDb.sessionsBox.listenable(),
            builder: (context, _, _) {
              final List<GameResult> sessions =
                  LocalDb.sessionsForPatient(widget.patientId);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CaregiverAlertBanner(patientId: widget.patientId),
                    _weekCard(sessions),
                    const SizedBox(height: 16),
                    _difficultyCard(),
                    const SizedBox(height: 16),
                    _trendCard(sessions),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _weekCard(List<GameResult> sessions) {
    final DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final int count = sessions.where((s) => s.at.isAfter(weekAgo)).length;
    return BigCard(
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 40, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: AppText.gameQuestion()),
                Text('games played this week',
                    style: AppText.body(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _difficultyCard() {
    Widget row(String label, String game) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.body()),
              Text('Level ${LocalDb.gameDifficulty(game)}',
                  style: AppText.body().copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        );
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current difficulty', style: AppText.title()),
          const SizedBox(height: 12),
          row('Pattern (attention)', 'pattern'),
          row('Faces (memory)', 'faces'),
          row('Voice (listening)', 'voice'),
        ],
      ),
    );
  }

  Widget _trendCard(List<GameResult> sessions) {
    final bool anyData = _domains.any((d) => _spots(sessions, d.key).isNotEmpty);
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Accuracy trend', style: AppText.title())),
              _windowToggle(),
            ],
          ),
          const SizedBox(height: 8),
          _legend(),
          const SizedBox(height: 16),
          if (!anyData)
            Text('No game sessions in this period yet.',
                style: AppText.body(color: AppColors.textMuted))
          else
            SizedBox(height: 240, child: _chart(sessions)),
        ],
      ),
    );
  }

  Widget _windowToggle() {
    Widget chip(int days, String label) {
      final bool active = _windowDays == days;
      return GestureDetector(
        onTap: () => setState(() => _windowDays = days),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Text(
            label,
            style: AppText.body(
              color: active ? Colors.white : AppColors.primary,
            ).copyWith(fontSize: 16),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(7, '7d'),
        const SizedBox(width: 8),
        chip(30, '30d'),
      ],
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final _Domain d in _domains)
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
                      .copyWith(fontSize: 15)),
            ],
          ),
      ],
    );
  }

  Widget _chart(List<GameResult> sessions) {
    final double maxX = (_windowDays - 1).toDouble();
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
              interval: _windowDays <= 7 ? 3 : 10,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final int daysAgo = (maxX - v).round();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    daysAgo == 0 ? 'today' : '${daysAgo}d',
                    style: AppText.body(color: AppColors.textMuted)
                        .copyWith(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          for (final _Domain d in _domains)
            LineChartBarData(
              spots: _spots(sessions, d.key),
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

  /// Daily average accuracy spots for [domain] over the current window.
  List<FlSpot> _spots(List<GameResult> sessions, String domain) {
    final DateTime now = DateTime.now();
    final DateTime startDay = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _windowDays - 1));
    final Map<int, List<double>> byDay = <int, List<double>>{};
    for (final GameResult s in sessions) {
      if (s.domain != domain || s.at.isBefore(startDay)) continue;
      final int di = s.at.difference(startDay).inDays;
      if (di < 0 || di >= _windowDays) continue;
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
