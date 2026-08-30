import 'package:flutter/material.dart' hide Alert;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/game_result.dart';
import '../../core/models/alert.dart';
import '../../core/services/local_db.dart';
import '../../features/doctor/doctor_repository.dart';

class PdfReportService {
  static Future<void> generateAndPrintReport(
      BuildContext context, String patientId, DoctorPatientData? doctorData) async {
    // 1. Gather data
    final sessions = doctorData?.sessions ?? LocalDb.sessionsForPatient(patientId);
    final alerts = doctorData?.alerts ?? <Alert>[];
    final profile = doctorData?.profile;

    // Calculate basics
    final int totalGames = sessions.length;
    double avgAccuracy = 0.0;
    if (totalGames > 0) {
      avgAccuracy = sessions.fold(0.0, (sum, s) => sum + s.accuracy) / totalGames;
    }

    final patternGames = sessions.where((s) => s.game == 'pattern').toList();
    final facesGames = sessions.where((s) => s.game == 'faces').toList();
    final voiceGames = sessions.where((s) => s.game == 'voice').toList();

    double getAvg(List<GameResult> list) =>
        list.isEmpty ? 0 : list.fold(0.0, (s, g) => s + g.accuracy) / list.length;

    final pAvg = getAvg(patternGames);
    final fAvg = getAvg(facesGames);
    final vAvg = getAvg(voiceGames);

    // Observations
    String observation = "Patient exhibits stable cognitive patterns.";
    if (avgAccuracy < 0.5 && totalGames > 5) {
      observation =
          "Patient shows significant difficulty across cognitive tasks. Consider adjusting difficulty or reviewing care plan.";
    } else if (avgAccuracy > 0.8) {
      observation = "Patient maintains high accuracy levels. Good cognitive engagement observed.";
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 24),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Cognitive Assessment Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          );
        },
        build: (context) => [
          // Patient Info
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Patient Name: ${profile?.name ?? "Unknown"}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Patient ID: $patientId'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Age: ${profile?.age ?? "N/A"}'),
                    pw.Text('Stage: ${profile?.stage ?? "N/A"}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Summary Block
          pw.Text('Summary',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox('Total Games', '$totalGames'),
              _buildStatBox('Overall Accuracy', '${(avgAccuracy * 100).toStringAsFixed(1)}%'),
              _buildStatBox('Recent Alerts', '${alerts.length}'),
            ],
          ),
          pw.SizedBox(height: 24),

          // Domain Accuracies
          pw.Text('Domain Breakdown',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Domain / Game', 'Sessions', 'Avg Accuracy'],
            data: [
              ['Pattern (Attention)', '${patternGames.length}', '${(pAvg * 100).toStringAsFixed(1)}%'],
              ['Faces (Memory)', '${facesGames.length}', '${(fAvg * 100).toStringAsFixed(1)}%'],
              ['Voice (Auditory)', '${voiceGames.length}', '${(vAvg * 100).toStringAsFixed(1)}%'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue600),
            rowDecoration:
                const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(8),
          ),
          pw.SizedBox(height: 24),

          // Difficulty Progression
          pw.Text('Difficulty Progression',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• Pattern Game Level: ${LocalDb.gameDifficulty('pattern')}'),
                pw.Text('• Faces Game Level: ${LocalDb.gameDifficulty('faces')}'),
                pw.Text('• Voice Game Level: ${LocalDb.gameDifficulty('voice')}'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Alerts/Anomalies
          if (alerts.isNotEmpty) ...[
            pw.Text('Recent Anomalies / Alerts',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
            pw.SizedBox(height: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: alerts.take(5).map((a) {
                final dateStr = DateFormat('MMM dd, hh:mm a').format(a.at);
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red200),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(dateStr,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                          child: pw.Text('${a.domain.toUpperCase()} domain dropped by ${(a.deltaPct * 100).toStringAsFixed(0)}%',
                              style: const pw.TextStyle(color: PdfColors.black))),
                    ],
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 24),
          ],

          // Clinical Observations
          pw.Text('Clinical Observations',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(observation,
                style: const pw.TextStyle(fontSize: 14, lineSpacing: 1.5)),
          ),
        ],
      ),
    );

    // Print or share the document
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Cognitive_Report_$patientId.pdf',
    );
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.blue800),
              textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }
}
