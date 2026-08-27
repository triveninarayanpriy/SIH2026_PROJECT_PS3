import 'package:intl/intl.dart';

import '../../core/models/alert.dart';
import '../../core/models/daily_care.dart';
import '../../core/models/game_result.dart';
import 'doctor_repository.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _domainLabel(String d) {
  switch (d) {
    case 'memory':
      return 'Memory';
    case 'attention':
      return 'Attention';
    case 'auditory':
      return 'Listening';
    default:
      return d;
  }
}

/// Builds a simple, printable one-page HTML summary a family could carry to a
/// distant clinic. Auto-opens the browser print dialog when shown.
String buildWeeklyReportHtml(DoctorPatientData data) {
  final DateTime now = DateTime.now();
  final DateTime weekAgo = now.subtract(const Duration(days: 7));
  final DateFormat dateFmt = DateFormat('MMM d, y');
  final DateFormat dateTimeFmt = DateFormat('MMM d, h:mm a');

  final List<GameResult> week =
      data.sessions.where((s) => s.at.isAfter(weekAgo)).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  // Per-domain average accuracy this week.
  final Map<String, List<double>> byDomain = <String, List<double>>{};
  for (final GameResult s in week) {
    byDomain.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
  }
  final StringBuffer domainRows = StringBuffer();
  for (final String d in <String>['memory', 'attention', 'auditory']) {
    final List<double>? v = byDomain[d];
    final String pct = (v == null || v.isEmpty)
        ? '—'
        : '${(v.reduce((a, b) => a + b) / v.length * 100).round()}%';
    domainRows.write(
        '<tr><td>${_domainLabel(d)}</td><td class="num">$pct</td>'
        '<td class="num">${v?.length ?? 0}</td></tr>');
  }

  // Recent sessions table (latest 12).
  final StringBuffer sessionRows = StringBuffer();
  for (final GameResult s in week.take(12)) {
    sessionRows.write(
        '<tr><td>${_esc(s.game)}</td><td>${_domainLabel(s.domain)}</td>'
        '<td class="num">${(s.accuracy * 100).round()}%</td>'
        '<td class="num">${s.difficulty}</td>'
        '<td>${dateTimeFmt.format(s.at)}</td></tr>');
  }
  if (week.isEmpty) {
    sessionRows.write('<tr><td colspan="5">No sessions this week.</td></tr>');
  }

  // Alerts.
  final List<Alert> drops = data.alerts
      .where((a) => a.type == 'cognitive_drop')
      .toList()
    ..sort((a, b) => b.at.compareTo(a.at));
  final StringBuffer alertRows = StringBuffer();
  for (final Alert a in drops.take(6)) {
    alertRows.write(
        '<li><b>${_domainLabel(a.domain)}</b>: ${a.deltaPct.toStringAsFixed(0)}% '
        'decline &middot; ${dateFmt.format(a.at)} &mdash; possible progression, '
        'clinical review suggested.</li>');
  }
  final String alertsHtml = drops.isEmpty
      ? '<p class="muted">No cognitive-drop alerts.</p>'
      : '<ul>$alertRows</ul>';

  // Daily care (latest 5).
  final List<DailyCare> care = List<DailyCare>.of(data.dailyCare)
    ..sort((a, b) => b.date.compareTo(a.date));
  final StringBuffer careRows = StringBuffer();
  for (final DailyCare c in care.take(5)) {
    careRows.write(
        '<tr><td>${_esc(c.date)}</td><td class="num">${c.medsTaken.length}</td>'
        '<td class="num">${c.hydrationCount}</td>'
        '<td class="num">${c.mealsLogged.length}</td></tr>');
  }
  if (care.isEmpty) {
    careRows.write('<tr><td colspan="4">No care logs.</td></tr>');
  }

  final String name = _esc(data.profile?.name ?? 'Patient');
  final int stage = data.profile?.stage ?? 0;
  final int age = data.profile?.age ?? 0;
  final String region = _esc(data.profile?.region ?? '');

  return '''
<!doctype html>
<html><head><meta charset="utf-8"><title>Weekly Report — $name</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: Inter, Arial, sans-serif; color: #1E2430; margin: 32px; }
  h1 { font-size: 22px; margin: 0 0 2px; }
  h2 { font-size: 15px; margin: 24px 0 8px; color: #2E5AAC; }
  .muted { color: #55607A; }
  .sub { color: #55607A; margin: 0 0 16px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid #D5DEEC; }
  th { color: #55607A; font-weight: 600; }
  td.num, th.num { text-align: right; }
  ul { margin: 6px 0; padding-left: 20px; font-size: 13px; }
  .foot { margin-top: 28px; font-size: 12px; color: #55607A;
          border-top: 1px solid #D5DEEC; padding-top: 10px; }
  @media print { body { margin: 12mm; } }
</style>
<script>window.onload=function(){setTimeout(function(){window.print();},350);};</script>
</head><body>
  <h1>CogniCare NER — Weekly Report</h1>
  <p class="sub">$name &middot; Stage $stage &middot; Age $age${region.isEmpty ? '' : ' &middot; $region'}<br>
     Week of ${dateFmt.format(weekAgo)} – ${dateFmt.format(now)}</p>

  <h2>This week at a glance</h2>
  <table><tr><th>Domain</th><th class="num">Avg accuracy</th><th class="num">Sessions</th></tr>
  $domainRows</table>

  <h2>Alerts</h2>
  $alertsHtml

  <h2>Recent sessions</h2>
  <table><tr><th>Game</th><th>Domain</th><th class="num">Accuracy</th>
    <th class="num">Level</th><th>When</th></tr>
  $sessionRows</table>

  <h2>Daily care</h2>
  <table><tr><th>Date</th><th class="num">Meds</th><th class="num">Hydration</th>
    <th class="num">Meals</th></tr>
  $careRows</table>

  <p class="foot">Generated ${dateTimeFmt.format(now)} by CogniCare NER.
     This summary is for information only and does not replace a clinical
     assessment. Please bring it to your appointment.</p>
</body></html>
''';
}
