import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/anomaly_detector.dart';
import '../../core/models/daily_care.dart';
import '../../core/models/game_result.dart';
import '../../core/models/patient_profile.dart';
import '../../core/services/caregiver_note_service.dart';
import '../../core/services/local_db.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/care_note_card.dart';
import '../../core/widgets/clinical_charts.dart';
import 'caregiver_alert_banner.dart';

class _WarmCard extends StatelessWidget {
  const _WarmCard({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: child,
    );
  }
}

/// Warm, reassuring caregiver dashboard: a friendly status headline, this week
/// at a glance, the AI weekly note, an engagement trend, and an interactive
/// daily-care checklist with a weekly completion ring.
class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key, required this.patientId});

  final String patientId;

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
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
    final games = <String>['pattern', 'faces', 'voice'];
    final domains = <String>['attention', 'memory', 'auditory'];

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
    AnomalyDetector.instance.runForPatient(widget.patientId);
  }

  String get _todayKey {
    final DateTime d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.skyBg,
      appBar: AppBar(
        title: const Text('How things are going'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ValueListenableBuilder<Box<GameResult>>(
            valueListenable: LocalDb.sessionsBox.listenable(),
            builder: (context, _, __) {
              return ValueListenableBuilder<Box<DailyCare>>(
                valueListenable: LocalDb.dailyCareBox.listenable(),
                builder: (context, ___, ____) {
                  final List<GameResult> sessions =
                      LocalDb.sessionsForPatient(widget.patientId);
                  final WeeklyStats stats =
                      WeeklyStats.compute(widget.patientId);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _headline(stats),
                        const SizedBox(height: 16),
                        CaregiverAlertBanner(patientId: widget.patientId),
                        const SizedBox(height: 4),
                        CareNoteCard(patientId: widget.patientId),
                        const SizedBox(height: 16),
                        _glance(stats),
                        const SizedBox(height: 16),
                        _engagementCard(sessions),
                        const SizedBox(height: 16),
                        _dailyCareCard(),
                        const SizedBox(height: 16),
                        _printReportButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- Friendly headline -------------------------------------------------
  Widget _headline(WeeklyStats stats) {
    final PatientProfile? profile = LocalDb.getProfile(widget.patientId);
    final String name = profile?.name.split(' ').first ?? 'Your loved one';
    final double score = stats.overallThisWeek ?? 0;

    String message;
    IconData icon;
    List<Color> colors;
    if (stats.sessionsThisWeek == 0) {
      message = 'Let’s start a gentle activity with $name today.';
      icon = Icons.favorite_rounded;
      colors = AppColors.primaryGradient;
    } else if (stats.hasAlert) {
      message = '$name could use a little extra care this week. You’re doing wonderfully. 💛';
      icon = Icons.volunteer_activism_rounded;
      colors = <Color>[AppColors.gentleWarning, const Color(0xFFF3A73B)];
    } else if (score >= 0.75) {
      message = '$name is having a lovely week! 🌟';
      icon = Icons.emoji_emotions_rounded;
      colors = AppColors.successGradient;
    } else if (stats.decliningDomains.isNotEmpty) {
      message = '$name is doing okay — a few gentle days. 💛';
      icon = Icons.spa_rounded;
      colors = AppColors.secondaryGradient;
    } else {
      message = '$name is having a steady week. 💛';
      icon = Icons.favorite_rounded;
      colors = AppColors.primaryGradient;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 48, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: AppText.title().copyWith(color: Colors.white, fontSize: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ---- This week at a glance --------------------------------------------
  Widget _glance(WeeklyStats stats) {
    final String bestArea = stats.perDomain.isEmpty
        ? '—'
        : (kDomainLabels[(stats.perDomain.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .first
                .key] ??
            '—');
    final String concern = stats.decliningDomains.isEmpty
        ? 'Nothing to worry about'
        : (kDomainLabels[stats.decliningDomains.first] ?? '');

    return Row(
      children: <Widget>[
        Expanded(
          child: _glanceCard(
            Icons.videogame_asset_rounded,
            '${stats.sessionsThisWeek}',
            'games this week',
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glanceCard(
            Icons.star_rounded,
            bestArea,
            'best area',
            AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glanceCard(
            Icons.spa_rounded,
            concern == 'Nothing to worry about' ? '👍' : concern,
            concern == 'Nothing to worry about' ? 'all good' : 'gentle focus',
            AppColors.gentleWarning,
          ),
        ),
      ],
    );
  }

  Widget _glanceCard(IconData icon, String value, String label, Color color) {
    return _WarmCard(
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(value,
                style: AppText.title().copyWith(fontSize: 22, color: color)),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  // ---- Engagement trend --------------------------------------------------
  Widget _engagementCard(List<GameResult> sessions) {
    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('This week’s progress', style: AppText.title().copyWith(fontSize: 20)),
          const SizedBox(height: 6),
          Text('How well the activities are going, day by day.',
              style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 13)),
          const SizedBox(height: 16),
          CompositeTrendChart(sessions: sessions, days: 14, height: 200),
        ],
      ),
    );
  }

  // ---- Daily-care checklist + weekly ring -------------------------------
  static const List<(String, String, String)> _careItems = <(String, String, String)>[
    ('meds:morning', 'Morning medicine', 'meds'),
    ('meds:evening', 'Evening medicine', 'meds'),
    ('meal:breakfast', 'Breakfast', 'meal'),
    ('meal:lunch', 'Lunch', 'meal'),
    ('meal:dinner', 'Dinner', 'meal'),
    ('water', 'Drank water', 'water'),
  ];

  DailyCare _today() =>
      LocalDb.getDailyCare(_todayKey) ??
      DailyCare(date: _todayKey, medsTaken: const <String>[], hydrationCount: 0, mealsLogged: const <String>[]);

  bool _isDone(DailyCare c, String key) {
    if (key.startsWith('meds:')) return c.medsTaken.contains(key.split(':')[1]);
    if (key.startsWith('meal:')) return c.mealsLogged.contains(key.split(':')[1]);
    if (key == 'water') return c.hydrationCount >= 6;
    return false;
  }

  Future<void> _toggle(String key) async {
    final DailyCare c = _today();
    List<String> meds = List<String>.of(c.medsTaken);
    List<String> meals = List<String>.of(c.mealsLogged);
    int water = c.hydrationCount;
    if (key.startsWith('meds:')) {
      final String v = key.split(':')[1];
      meds.contains(v) ? meds.remove(v) : meds.add(v);
    } else if (key.startsWith('meal:')) {
      final String v = key.split(':')[1];
      meals.contains(v) ? meals.remove(v) : meals.add(v);
    } else if (key == 'water') {
      water = water >= 6 ? 0 : 6;
    }
    await SyncService.instance.saveDailyCare(
      widget.patientId,
      DailyCare(date: _todayKey, medsTaken: meds, hydrationCount: water, mealsLogged: meals),
    );
    if (mounted) setState(() {});
  }

  double _weeklyCompletion() {
    final DateTime now = DateTime.now();
    int done = 0;
    for (int i = 0; i < 7; i++) {
      final DateTime day = now.subtract(Duration(days: i));
      final String key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final DailyCare? c = LocalDb.getDailyCare(key);
      if (c == null) continue;
      final int score = _careItems.where((e) => _isDone(c, e.$1)).length;
      done += score;
    }
    final int total = 7 * _careItems.length;
    return total == 0 ? 0 : done / total;
  }

  Widget _dailyCareCard() {
    final DailyCare today = _today();
    final int doneToday = _careItems.where((e) => _isDone(today, e.$1)).length;
    final double weekly = _weeklyCompletion();
    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Today’s care', style: AppText.title().copyWith(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text('$doneToday of ${_careItems.length} done today',
                        style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 13)),
                  ],
                ),
              ),
              _ring(weekly),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final (String, String, String) item in _careItems)
                _careChip(item.$1, item.$2, _isDone(today, item.$1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _careChip(String key, String label, bool done) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _toggle(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: done ? AppColors.success.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: done ? AppColors.success : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20, color: done ? AppColors.success : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(label,
                style: AppText.body().copyWith(
                    fontSize: 15,
                    color: done ? AppColors.success : AppColors.text,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _ring(double value) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 7,
              backgroundColor: AppColors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                value >= 0.7 ? AppColors.success : AppColors.gentleWarning,
              ),
            ),
          ),
          Text('${(value * 100).round()}%',
              style: AppText.body().copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ---- Clinical report (kept) -------------------------------------------
  Future<void> _generatePdf(BuildContext context) async {
    await PdfReportService.generateAndPrintReport(context, widget.patientId, null);
  }

  Widget _printReportButton() {
    return _WarmCard(
      child: Row(
        children: <Widget>[
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
              children: <Widget>[
                Text('Report for the doctor', style: AppText.title().copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text('Download a clear PDF summary to share.',
                    style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 14)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _generatePdf(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Print', style: AppText.button().copyWith(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
