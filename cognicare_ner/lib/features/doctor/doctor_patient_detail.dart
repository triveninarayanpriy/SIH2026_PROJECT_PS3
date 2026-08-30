import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/alert.dart';
import '../../core/models/daily_care.dart';
import '../../core/models/game_result.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/domain_trend_chart.dart';
import '../../core/services/pdf_report_service.dart';
import 'doctor_repository.dart';

const Color _clinicalRed = Color(0xFFD64545);

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

/// Read-only doctor view of one patient: 30-day per-domain trends, a recent
/// sessions table, daily-care summary, and alert history. Cached for offline.
class DoctorPatientDetail extends StatefulWidget {
  const DoctorPatientDetail({super.key, required this.patientId});

  final String patientId;

  @override
  State<DoctorPatientDetail> createState() => _DoctorPatientDetailState();
}

class _DoctorPatientDetailState extends State<DoctorPatientDetail> {
  DoctorPatientData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = DoctorRepository.cachedDetail(widget.patientId);
    _loading = _data == null;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      DoctorPatientData d =
          await DoctorRepository.fetchDetail(widget.patientId);
          
      // Demo fallback: if firebase fetch returns 0 sessions, try local
      if (d.sessions.isEmpty) {
        final localSessions = LocalDb.sessionsForPatient(widget.patientId);
        final localAlerts = LocalDb.allAlerts().where((a) => a.patientId == widget.patientId).toList();
        final localDailyCare = LocalDb.allDailyCare().where((dc) => true).toList(); // Simplified for demo
        if (localSessions.isNotEmpty) {
           d = DoctorPatientData(
             profile: d.profile,
             sessions: localSessions,
             alerts: localAlerts.isNotEmpty ? localAlerts : d.alerts,
             dailyCare: localDailyCare.isNotEmpty ? localDailyCare : d.dailyCare,
           );
        }
      }

      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      DoctorPatientData? localD;
      final localSessions = LocalDb.sessionsForPatient(widget.patientId);
      if (_data == null && localSessions.isNotEmpty) {
        localD = DoctorPatientData(
          profile: null,
          sessions: localSessions,
          alerts: const [],
          dailyCare: const [],
        );
      }
      setState(() {
        if (localD != null) _data = localD;
        _error = 'Offline — showing cached data.';
        _loading = false;
      });
    }
  }

  void _download() {
    final DoctorPatientData? d = _data;
    if (d == null) return;
    PdfReportService.generateAndPrintReport(context, widget.patientId, d);
  }

  @override
  Widget build(BuildContext context) {
    final DoctorPatientData? d = _data;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Professional clinical background
      appBar: AppBar(
        title: Text(d?.profile?.name ?? 'Patient'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: (_loading && d == null)
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Row(children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Text(_error!,
                              style: _t(14, color: AppColors.textMuted)),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      _header(d),
                      const SizedBox(height: 16),
                      _trendCard(d),
                      const SizedBox(height: 16),
                      _alertsCard(d),
                      const SizedBox(height: 16),
                      _sessionsCard(d),
                      const SizedBox(height: 16),
                      _careCard(d),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _header(DoctorPatientData? d) {
    final String name = d?.profile?.name ?? widget.patientId;
    final String sub = d?.profile == null
        ? 'Code ${widget.patientId}'
        : 'Age ${d!.profile!.age}  ·  Stage ${d.profile!.stage}  ·  '
            '${d.profile!.region}  ·  ${d.profile!.id}';
    return _MedicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: _t(28, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(sub, style: _t(16, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.print_rounded, size: 24, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generate Clinical Report', style: _t(18, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Download PDF summary.',
                        style: _t(14, color: AppColors.textMuted)),
                  ],
                ),
              ),
              FilledButton(
                onPressed: (d == null) ? null : _download,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Print', style: _t(16, color: Colors.white, weight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendCard(DoctorPatientData? d) {
    return _MedicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accuracy trend — last 30 days',
              style: _t(20, weight: FontWeight.w600)),
          const SizedBox(height: 20),
          DomainTrendChart(sessions: d?.sessions ?? const <GameResult>[]),
        ],
      ),
    );
  }

  Widget _alertsCard(DoctorPatientData? d) {
    final List<Alert> drops = (d?.alerts ?? const <Alert>[])
        .where((a) => a.type == 'cognitive_drop')
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return _MedicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alert history', style: _t(20, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (drops.isEmpty)
            Text('No cognitive-drop alerts.',
                style: _t(15, color: AppColors.textMuted))
          else
            for (final Alert a in drops.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _clinicalRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          size: 24, color: _clinicalRed),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_domainLabel(a.domain)}: '
                            '${a.deltaPct.toStringAsFixed(0)}% decline',
                            style: _t(16, weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('MMM d, y').format(a.at)}  ·  Possible progression — clinical review suggested.',
                            style: _t(14, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _sessionsCard(DoctorPatientData? d) {
    final List<GameResult> sessions =
        List<GameResult>.of(d?.sessions ?? const <GameResult>[])
          ..sort((a, b) => b.at.compareTo(a.at));
    return _MedicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent sessions', style: _t(20, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (sessions.isEmpty)
            Text('No sessions recorded yet.',
                style: _t(15, color: AppColors.textMuted))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle:
                    _t(14, color: AppColors.textMuted, weight: FontWeight.w600),
                dataTextStyle: _t(15),
                columnSpacing: 32,
                columns: const [
                  DataColumn(label: Text('Game')),
                  DataColumn(label: Text('Domain')),
                  DataColumn(label: Text('Accuracy'), numeric: true),
                  DataColumn(label: Text('Level'), numeric: true),
                  DataColumn(label: Text('When')),
                ],
                rows: [
                  for (final GameResult s in sessions.take(15))
                    DataRow(cells: [
                      DataCell(Text(s.game)),
                      DataCell(Text(_domainLabel(s.domain))),
                      DataCell(Text('${(s.accuracy * 100).round()}%', style: _t(15, weight: FontWeight.w600))),
                      DataCell(Text('${s.difficulty}')),
                      DataCell(
                          Text(DateFormat('MMM d, h:mm a').format(s.at))),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _careCard(DoctorPatientData? d) {
    final List<DailyCare> care =
        List<DailyCare>.of(d?.dailyCare ?? const <DailyCare>[])
          ..sort((a, b) => b.date.compareTo(a.date));
    return _MedicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily care', style: _t(20, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (care.isEmpty)
            Text('No care logs yet.',
                style: _t(15, color: AppColors.textMuted))
          else
            for (final DailyCare c in care.take(7))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.date, style: _t(16, weight: FontWeight.w500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Meds ${c.medsTaken.length} · Water ${c.hydrationCount} · '
                        'Meals ${c.mealsLogged.length}',
                        style: _t(14, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

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

  TextStyle _t(double size, {Color? color, FontWeight? weight}) =>
      AppText.body(color: color)
          .copyWith(fontSize: size, fontWeight: weight ?? FontWeight.w400);
}
