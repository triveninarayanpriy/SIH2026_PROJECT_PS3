import 'package:flutter/material.dart' hide Alert;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/alert.dart';
import '../../core/models/daily_care.dart';
import '../../core/models/game_result.dart';
import '../../core/services/local_db.dart';
import '../../features/doctor/doctor_repository.dart';

/// Clinical weekly PDF — NAWAL branded, generated from the SAME data the doctor
/// dashboard shows (all cognitive domains, composite score, adherence, alerts).
class PdfReportService {
  static const PdfColor _ink = PdfColor.fromInt(0xFF1A3C5A);
  static const PdfColor _teal = PdfColor.fromInt(0xFF0D5C75);

  // Domain key -> (clinical label). Mirrors the dashboard.
  static const Map<String, String> _domains = <String, String>{
    'memory': 'Memory (Episodic)',
    'attention': 'Attention',
    'auditory': 'Auditory Processing',
    'language': 'Language',
    'executive': 'Executive Function',
  };

  static const Map<String, String> _gameLabels = <String, String>{
    'pattern': 'Pattern Sequencing',
    'faces': 'Face Recognition',
    'voice': 'Voice Recognition',
    'name_completion': 'Name Completion',
    'milestone': 'Episodic Recall',
    'routine': 'Routine Sequencing',
    'objects': 'Object Naming',
  };

  static Future<void> generateAndPrintReport(
      BuildContext context, String patientId, DoctorPatientData? doctorData) async {
    final List<GameResult> allSessions =
        doctorData?.sessions ?? LocalDb.sessionsForPatient(patientId);
    final List<Alert> alerts = doctorData?.alerts ??
        LocalDb.allAlerts().where((a) => a.patientId == patientId).toList();
    final List<DailyCare> care = doctorData?.dailyCare ?? LocalDb.allDailyCare();
    final profile = doctorData?.profile ?? LocalDb.getProfile(patientId);

    final DateTime now = DateTime.now();
    final DateTime monthAgo = now.subtract(const Duration(days: 30));
    final List<GameResult> sessions =
        allSessions.where((s) => s.at.isAfter(monthAgo)).toList();

    // Per-domain averages + counts (last 30 days).
    final Map<String, List<double>> byDomain = <String, List<double>>{};
    for (final GameResult s in sessions) {
      byDomain.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
    }
    double? domainAvg(String d) {
      final List<double>? xs = byDomain[d];
      if (xs == null || xs.isEmpty) return null;
      return xs.reduce((a, b) => a + b) / xs.length;
    }

    final List<double> presentAvgs = <double>[
      for (final String d in _domains.keys)
        if (domainAvg(d) != null) domainAvg(d)!,
    ];
    final double? composite = presentAvgs.isEmpty
        ? null
        : presentAvgs.reduce((a, b) => a + b) / presentAvgs.length;

    // Declining domains: this-week vs prior-week.
    final List<String> declining = _decliningDomains(allSessions);

    // Adherence over the last 7 days.
    final ({double meds, double water, double meals}) adh = _adherence(care);

    final List<Alert> drops =
        alerts.where((a) => a.type == 'cognitive_drop').toList()
          ..sort((a, b) => b.at.compareTo(a.at));

    final String observation = _observation(composite, declining, drops.isNotEmpty);

    final pw.Document pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 20),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: <pw.Widget>[
                pw.Text('NAWAL',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink)),
                pw.Text('Weekly Cognitive Assessment Report',
                    style: const pw.TextStyle(fontSize: 12, color: _teal)),
              ]),
              pw.Text(DateFormat('MMM d, yyyy').format(now),
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 14),
          child: pw.Text(
            'NAWAL clinical report · Page ${ctx.pageNumber}/${ctx.pagesCount} · For information only; not a substitute for clinical assessment.',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9),
          ),
        ),
        build: (ctx) => <pw.Widget>[
          // Patient info
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: <pw.Widget>[
                  pw.Text(profile?.name ?? 'Patient',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('ID: $patientId', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: <pw.Widget>[
                  pw.Text('Age: ${profile?.age ?? "—"}   Stage: ${profile?.stage ?? "—"}'),
                  pw.Text('${profile?.region ?? ""}',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Summary stat boxes
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              _stat('Composite Score',
                  composite == null ? '—' : '${(composite * 100).round()}/100'),
              _stat('Sessions (30d)', '${sessions.length}'),
              _stat('Active Alerts', '${drops.length}'),
            ],
          ),
          pw.SizedBox(height: 22),

          // Per-domain breakdown
          _sectionTitle('Cognitive Domain Breakdown (last 30 days)'),
          pw.TableHelper.fromTextArray(
            headers: <String>['Domain', 'Sessions', 'Avg Accuracy', 'Status'],
            data: <List<String>>[
              for (final MapEntry<String, String> e in _domains.entries)
                <String>[
                  e.value,
                  '${byDomain[e.key]?.length ?? 0}',
                  domainAvg(e.key) == null ? '—' : '${(domainAvg(e.key)! * 100).round()}%',
                  domainAvg(e.key) == null
                      ? 'No data'
                      : (declining.contains(e.key)
                          ? 'Declining'
                          : (domainAvg(e.key)! < 0.6 ? 'Low' : 'Stable')),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: _teal),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: <int, pw.Alignment>{
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
            rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            cellPadding: const pw.EdgeInsets.all(7),
          ),
          pw.SizedBox(height: 22),

          // Adherence
          _sectionTitle('Weekly Routine Adherence (last 7 days)'),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              _adherenceBox('Medication', adh.meds),
              _adherenceBox('Hydration', adh.water),
              _adherenceBox('Meals', adh.meals),
            ],
          ),
          pw.SizedBox(height: 22),

          // Difficulty
          _sectionTitle('Current Difficulty Levels'),
          pw.Wrap(
            spacing: 16,
            runSpacing: 6,
            children: <pw.Widget>[
              for (final MapEntry<String, String> g in _gameLabels.entries)
                if (allSessions.any((s) => s.game == g.key))
                  pw.Text('• ${g.value}: Level ${LocalDb.gameDifficulty(g.key)}',
                      style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 22),

          // Alerts
          if (drops.isNotEmpty) ...<pw.Widget>[
            _sectionTitle('Anomaly Alerts', color: PdfColors.red800),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: drops.take(6).map((Alert a) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red200),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(children: <pw.Widget>[
                    pw.Text(DateFormat('MMM d').format(a.at),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        '${(_domains[a.domain] ?? a.domain)} — ${a.deltaPct.toStringAsFixed(0)}% decline over ~2 weeks; clinical review suggested.',
                        style: const pw.TextStyle(color: PdfColors.black, fontSize: 10),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 22),
          ],

          // Observation
          _sectionTitle('Clinical Observation'),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(observation, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'NAWAL_Report_${profile?.name.replaceAll(' ', '_') ?? patientId}.pdf',
    );
  }

  static List<String> _decliningDomains(List<GameResult> all) {
    final DateTime now = DateTime.now();
    final DateTime weekAgo = now.subtract(const Duration(days: 7));
    final DateTime twoWeeks = now.subtract(const Duration(days: 14));
    final Map<String, List<double>> thisW = <String, List<double>>{};
    final Map<String, List<double>> priorW = <String, List<double>>{};
    for (final GameResult s in all) {
      if (s.at.isAfter(weekAgo)) {
        thisW.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
      } else if (s.at.isAfter(twoWeeks)) {
        priorW.putIfAbsent(s.domain, () => <double>[]).add(s.accuracy);
      }
    }
    final List<String> out = <String>[];
    thisW.forEach((String d, List<double> xs) {
      final List<double>? p = priorW[d];
      if (p != null && p.isNotEmpty) {
        final double a = xs.reduce((x, y) => x + y) / xs.length;
        final double b = p.reduce((x, y) => x + y) / p.length;
        if (a < b - 0.15) out.add(d);
      }
    });
    return out;
  }

  static ({double meds, double water, double meals}) _adherence(List<DailyCare> care) {
    final DateTime start = DateTime.now().subtract(const Duration(days: 7));
    final List<DailyCare> recent = care
        .where((c) => (DateTime.tryParse(c.date) ?? DateTime(2000)).isAfter(start))
        .toList();
    if (recent.isEmpty) return (meds: 0, water: 0, meals: 0);
    double m = 0, w = 0, f = 0;
    for (final DailyCare c in recent) {
      m += (c.medsTaken.length / 2).clamp(0, 1);
      w += (c.hydrationCount / 6).clamp(0, 1);
      f += (c.mealsLogged.length / 3).clamp(0, 1);
    }
    return (meds: m / recent.length, water: w / recent.length, meals: f / recent.length);
  }

  static String _observation(double? composite, List<String> declining, bool hasAlert) {
    if (composite == null) {
      return 'No game sessions recorded in the last 30 days; unable to assess a trend.';
    }
    final StringBuffer b = StringBuffer();
    final int pct = (composite * 100).round();
    if (pct >= 80) {
      b.write('Composite cognitive performance is strong ($pct/100) with good engagement. ');
    } else if (pct >= 60) {
      b.write('Composite cognitive performance is moderate ($pct/100). ');
    } else {
      b.write('Composite cognitive performance is low ($pct/100), suggesting increased support. ');
    }
    if (declining.isNotEmpty) {
      final String d = declining.map((e) => _domains[e] ?? e).join(', ');
      b.write('A decline is noted in: $d. ');
    }
    if (hasAlert) {
      b.write('An automated cognitive-drop alert is active and warrants clinical review. ');
    } else {
      b.write('No active anomaly alerts. ');
    }
    return b.toString().trim();
  }

  static pw.Widget _sectionTitle(String text, {PdfColor color = _ink}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: color)),
      );

  static pw.Widget _stat(String label, String value) => pw.Container(
        width: 150,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFEAF6FC),
          border: pw.Border.all(color: _teal, width: 1.2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(children: <pw.Widget>[
          pw.Text(value,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 4),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 10, color: _teal), textAlign: pw.TextAlign.center),
        ]),
      );

  static pw.Widget _adherenceBox(String label, double v) {
    final int pct = (v * 100).round();
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: <pw.Widget>[
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: <pw.Widget>[
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text('$pct%', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _teal)),
        ]),
        pw.SizedBox(height: 5),
        pw.Stack(children: <pw.Widget>[
          pw.Container(height: 7, decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)))),
          pw.Container(
            height: 7,
            width: 130 * v.clamp(0.0, 1.0),
            decoration: const pw.BoxDecoration(
                color: _teal, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
          ),
        ]),
      ]),
    );
  }
}
