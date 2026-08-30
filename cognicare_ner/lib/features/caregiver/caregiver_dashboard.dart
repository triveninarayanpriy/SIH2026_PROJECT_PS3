import 'dart:io';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/anomaly_detector.dart';
import '../../core/models/game_result.dart';
import '../../core/services/local_db.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import 'caregiver_alert_banner.dart';

class _MedicalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _MedicalCard({required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: child,
    );
  }
}

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
  void initState() {
    super.initState();
    _seedDummyData();
  }

  void _seedDummyData() {
    final existing = LocalDb.sessionsForPatient(widget.patientId);
    if (existing.isNotEmpty) return;
    
    final rng = Random();
    final uuid = const Uuid();
    final now = DateTime.now();
    
    final games = ['pattern', 'faces', 'voice'];
    final domains = ['attention', 'memory', 'auditory'];
    
    for (int day = 0; day < 14; day++) {
      for (int g = 0; g < 3; g++) {
        final baseAccuracy = 0.5 + (day * 0.03) + (rng.nextDouble() * 0.2);
        final correct = (baseAccuracy * 5).round().clamp(1, 5);
        final result = GameResult(
          id: uuid.v4(),
          patientId: widget.patientId,
          game: games[g],
          domain: domains[g],
          correct: correct,
          total: 5,
          durationMs: 30000 + rng.nextInt(60000),
          difficulty: 2 + (day ~/ 5),
          at: now.subtract(Duration(days: day, hours: rng.nextInt(12))),
        );
        LocalDb.sessionsBox.put(result.id, result);
      }
    }
    
    // Generate anomalies for the seeded data
    AnomalyDetector.instance.runForPatient(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Professional clinical background
      appBar: AppBar(
        title: const Text('Progress'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
      ),
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
                    const SizedBox(height: 16),
                    _printReportButton(),
                    const SizedBox(height: 16),
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

  Future<void> _generatePdf(BuildContext context) async {
    await PdfReportService.generateAndPrintReport(context, widget.patientId, null);
  }

  Widget _printReportButton() {
    return _MedicalCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.print_rounded, size: 28, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generate Clinical Report', style: AppText.title().copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                Text('Download a detailed PDF report for doctors.',
                    style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 15)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _generatePdf(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Print', style: AppText.button().copyWith(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _weekCard(List<GameResult> sessions) {
    final DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final int count = sessions.where((s) => s.at.isAfter(weekAgo)).length;
    return _MedicalCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: AppText.gameQuestion().copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.body().copyWith(fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Level ${LocalDb.gameDifficulty(game)}',
                    style: AppText.body().copyWith(fontWeight: FontWeight.w600, color: AppColors.secondary)),
              ),
            ],
          ),
        );
    return _MedicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current difficulty', style: AppText.title()),
          const SizedBox(height: 16),
          row('Pattern (attention)', 'pattern'),
          const Divider(height: 16, color: Color(0xFFEEEEEE)),
          row('Faces (memory)', 'faces'),
          const Divider(height: 16, color: Color(0xFFEEEEEE)),
          row('Voice (listening)', 'voice'),
        ],
      ),
    );
  }

  Widget _trendCard(List<GameResult> sessions) {
    final bool anyData = _domains.any((d) => _spots(sessions, d.key).isNotEmpty);
    return _MedicalCard(
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
          const SizedBox(height: 12),
          _legend(),
          const SizedBox(height: 24),
          if (!anyData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('No game sessions in this period yet.',
                  style: AppText.body(color: AppColors.textMuted)),
            )
          else
            SizedBox(height: 260, child: _chart(sessions)),
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



