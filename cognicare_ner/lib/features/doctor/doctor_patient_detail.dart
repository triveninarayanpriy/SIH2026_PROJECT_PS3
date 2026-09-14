import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/alert.dart';
import '../../core/models/daily_care.dart';
import '../../core/models/game_result.dart';
import '../../core/services/local_db.dart';
import '../../core/services/caregiver_note_service.dart' show kDomainLabels;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/care_note_card.dart';
import '../../core/widgets/clinical_charts.dart';
import '../../core/services/pdf_report_service.dart';
import 'doctor_repository.dart';

const Color kClinicalTeal = Color(0xFF0D5C75);
const Color kClinicalRed = Color(0xFFD64545);
const Color kClinicalBg = AppColors.skyBg;

/// Read-only clinical view of one patient — teal medical theme with a triage
/// header, AI clinical note, anomaly alerts, composite score trend, domain
/// radar, adherence bars, and a sessions table. Cached for offline use.
class DoctorPatientDetail extends StatefulWidget {
  const DoctorPatientDetail({super.key, required this.patientId, this.embedded = false});

  final String patientId;

  /// When embedded in the wide two-pane list, drop the Scaffold/AppBar.
  final bool embedded;

  @override
  State<DoctorPatientDetail> createState() => _DoctorPatientDetailState();
}

class _DoctorPatientDetailState extends State<DoctorPatientDetail> {
  DoctorPatientData? _data;
  bool _loading = true;
  String? _error;
  String _sortColumn = 'date';
  bool _sortAsc = false;

  @override
  void didUpdateWidget(covariant DoctorPatientDetail old) {
    super.didUpdateWidget(old);
    if (old.patientId != widget.patientId) {
      _data = DoctorRepository.cachedDetail(widget.patientId);
      _loading = _data == null;
      _refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    _data = DoctorRepository.cachedDetail(widget.patientId);
    _loading = _data == null;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      DoctorPatientData d = await DoctorRepository.fetchDetail(widget.patientId);
      if (d.sessions.isEmpty) {
        // Fall back to local sessions (same-device demo)…
        final local = LocalDb.sessionsForPatient(widget.patientId);
        if (local.isNotEmpty) {
          d = DoctorPatientData(
            profile: d.profile ?? LocalDb.getProfile(widget.patientId),
            sessions: local,
            alerts: LocalDb.allAlerts().where((a) => a.patientId == widget.patientId).toList(),
            dailyCare: LocalDb.allDailyCare().toList(),
          );
        } else if (_data != null && _data!.sessions.isNotEmpty) {
          // …otherwise keep the cached detail rather than blanking it.
          d = _data!;
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
      setState(() {
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
    final Widget body = (_loading && d == null)
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  _offlineChip(_error!),
                  const SizedBox(height: 12),
                ],
                _hero(d),
                const SizedBox(height: 16),
                CareNoteCard(patientId: widget.patientId, clinical: true),
                const SizedBox(height: 16),
                _alertsPanel(d),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final bool wide = c.maxWidth > 720;
                    final Widget trend = _compositeCard(d);
                    final Widget radar = _radarCard(d);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(flex: 7, child: trend),
                          const SizedBox(width: 16),
                          Expanded(flex: 5, child: radar),
                        ],
                      );
                    }
                    return Column(children: <Widget>[trend, const SizedBox(height: 16), radar]);
                  },
                ),
                const SizedBox(height: 16),
                _adherenceCard(d),
                const SizedBox(height: 16),
                _sessionsCard(d),
                const SizedBox(height: 24),
              ],
            ),
          );

    if (widget.embedded) return Container(color: kClinicalBg, child: body);
    return Scaffold(
      backgroundColor: kClinicalBg,
      appBar: AppBar(
        title: Text(d?.profile?.name ?? 'Patient'),
        backgroundColor: Colors.white,
        foregroundColor: kClinicalTeal,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: body,
    );
  }

  // ---- Cards -------------------------------------------------------------
  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _offlineChip(String text) => Row(children: <Widget>[
        const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(text, style: _t(13, color: const Color(0xFF64748B))),
      ]);

  Widget _hero(DoctorPatientData? d) {
    final String name = d?.profile?.name ?? widget.patientId;
    final List<GameResult> sessions = d?.sessions ?? const <GameResult>[];
    final bool hasAlert =
        (d?.alerts ?? const <Alert>[]).any((a) => a.type == 'cognitive_drop');
    final Triage triage = triageFor(sessions, hasAlert: hasAlert);
    final double? composite = compositeScore(sessions);
    final String initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();

    final String meta = d?.profile == null
        ? 'Code ${widget.patientId}'
        : '${widget.patientId}  ·  ${d!.profile!.age}y  ·  Stage ${d.profile!.stage}  ·  ${d.profile!.region}';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: kClinicalTeal.withValues(alpha: 0.1),
                child: Text(initials,
                    style: _t(18, color: kClinicalTeal, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: <Widget>[
                        Text(name, style: _t(24, weight: FontWeight.w800)),
                        _triageBadge(triage),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(meta, style: _t(14, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              if (composite != null) ...<Widget>[
                _stat('Composite', '${(composite * 100).round()}', '/100', triage.color),
                const SizedBox(width: 12),
              ],
              _stat('Sessions', '${sessions.length}', '', kClinicalTeal),
              const Spacer(),
              FilledButton.icon(
                onPressed: d == null ? null : _download,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Weekly report'),
                style: FilledButton.styleFrom(
                  backgroundColor: kClinicalTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String suffix, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(value, style: _t(20, color: color, weight: FontWeight.w800)),
          if (suffix.isNotEmpty) Text(suffix, style: _t(12, color: color)),
          const SizedBox(width: 8),
          Text(label, style: _t(12, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _triageBadge(Triage t) {
    final String label = switch (t) {
      Triage.red => 'Decline alert',
      Triage.amber => 'Monitoring',
      Triage.green => 'Stable',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Container(width: 8, height: 8, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label.toUpperCase(), style: _t(11, color: t.color, weight: FontWeight.w800)),
      ]),
    );
  }

  Widget _alertsPanel(DoctorPatientData? d) {
    final List<Alert> drops = (d?.alerts ?? const <Alert>[])
        .where((a) => a.type == 'cognitive_drop')
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    if (drops.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(children: <Widget>[
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('No anomaly flags. Baseline stability maintained.',
                style: _t(14, color: const Color(0xFF065F46), weight: FontWeight.w600)),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.warning_amber_rounded, color: kClinicalRed),
            const SizedBox(width: 8),
            Text('Clinical anomaly alerts', style: _t(14, color: const Color(0xFF991B1B), weight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kClinicalRed, borderRadius: BorderRadius.circular(999)),
              child: Text('${drops.length}', style: _t(11, color: Colors.white, weight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          for (final Alert a in drops.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: kClinicalRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text((kDomainLabels[a.domain] ?? a.domain).toUpperCase(),
                      style: _t(10, color: const Color(0xFF991B1B), weight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text('${a.deltaPct.toStringAsFixed(0)}% decline over ~2 weeks — review suggested.',
                        style: _t(14, weight: FontWeight.w600)),
                    Text(DateFormat('MMM d, y').format(a.at),
                        style: _t(12, color: const Color(0xFF64748B))),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _compositeCard(DoctorPatientData? d) {
    final List<GameResult> sessions = d?.sessions ?? const <GameResult>[];
    final double? comp = compositeScore(sessions);
    final double? comp30ago = compositeScore(
        sessions.where((s) => s.at.isBefore(DateTime.now().subtract(const Duration(days: 25)))).toList());
    final double? delta = (comp != null && comp30ago != null) ? (comp - comp30ago) * 100 : null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Composite cognitive score', style: _t(16, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            comp == null
                ? 'Score 0–100 across all domains'
                : 'Current ${(comp * 100).round()}/100'
                    '${delta != null ? '  ·  ${delta >= 0 ? '+' : ''}${delta.round()} pt over 30 days' : ''}',
            style: _t(13, color: delta != null && delta < -5 ? kClinicalRed : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          CompositeTrendChart(sessions: sessions, alerts: d?.alerts ?? const <Alert>[], color: kClinicalTeal),
        ],
      ),
    );
  }

  Widget _radarCard(DoctorPatientData? d) {
    final List<GameResult> sessions = d?.sessions ?? const <GameResult>[];
    final Map<String, double> avgs = domainAverages(sessions);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Cognitive domain profile', style: _t(16, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          Center(child: DomainRadarChart(sessions: sessions, color: kClinicalTeal, size: 220)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String dm in kAllDomains)
                if (avgs.containsKey(dm)) _domainPill(dm, avgs[dm]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _domainPill(String domain, double v) {
    final int pct = (v * 100).round();
    final bool low = pct < 60;
    final Color c = low ? kClinicalRed : kClinicalTeal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text('${kDomainLabels[domain] ?? domain}  $pct%',
          style: _t(12, color: c, weight: FontWeight.w700)),
    );
  }

  Widget _adherenceCard(DoctorPatientData? d) {
    final List<DailyCare> care = d?.dailyCare ?? const <DailyCare>[];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.task_alt_rounded, size: 18, color: kClinicalTeal),
            const SizedBox(width: 8),
            Text('Weekly routine adherence', style: _t(16, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          if (care.isEmpty)
            Text('No care logs yet.', style: _t(14, color: const Color(0xFF64748B)))
          else
            AdherenceBars(care: care),
        ],
      ),
    );
  }

  Widget _sessionsCard(DoctorPatientData? d) {
    final List<GameResult> sessions = List<GameResult>.of(d?.sessions ?? const <GameResult>[]);
    sessions.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'game':
          cmp = a.game.compareTo(b.game);
          break;
        case 'domain':
          cmp = a.domain.compareTo(b.domain);
          break;
        case 'accuracy':
          cmp = a.accuracy.compareTo(b.accuracy);
          break;
        case 'difficulty':
          cmp = a.difficulty.compareTo(b.difficulty);
          break;
        default:
          cmp = a.at.compareTo(b.at);
      }
      return _sortAsc ? cmp : -cmp;
    });

    void onSort(String col) => setState(() {
          if (_sortColumn == col) {
            _sortAsc = !_sortAsc;
          } else {
            _sortColumn = col;
            _sortAsc = false;
          }
        });

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Text('Recent game sessions', style: _t(16, weight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
              child: Text('${sessions.length}', style: _t(12, color: const Color(0xFF64748B), weight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Text('No sessions recorded yet.', style: _t(14, color: const Color(0xFF64748B)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll<Color>(const Color(0xFFF8FAFC)),
                headingTextStyle: _t(13, color: const Color(0xFF475569), weight: FontWeight.w700),
                dataTextStyle: _t(14),
                columnSpacing: 26,
                sortColumnIndex: <String>['game', 'domain', 'accuracy', 'difficulty', 'date'].indexOf(_sortColumn),
                sortAscending: _sortAsc,
                columns: <DataColumn>[
                  DataColumn(label: const Text('Game'), onSort: (_, __) => onSort('game')),
                  DataColumn(label: const Text('Domain'), onSort: (_, __) => onSort('domain')),
                  DataColumn(label: const Text('Accuracy'), numeric: true, onSort: (_, __) => onSort('accuracy')),
                  DataColumn(label: const Text('Level'), numeric: true, onSort: (_, __) => onSort('difficulty')),
                  DataColumn(label: const Text('When'), onSort: (_, __) => onSort('date')),
                ],
                rows: <DataRow>[
                  for (final GameResult s in sessions.take(20))
                    DataRow(cells: <DataCell>[
                      DataCell(Text(_gameLabel(s.game))),
                      DataCell(_domainTag(s.domain)),
                      DataCell(_accuracyPill(s.accuracy)),
                      DataCell(_difficultyDots(s.difficulty)),
                      DataCell(Text(DateFormat('MMM d, h:mm a').format(s.at),
                          style: _t(13, color: const Color(0xFF64748B)))),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _domainTag(String d) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kClinicalTeal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
        child: Text(kDomainLabels[d] ?? d, style: _t(11, color: kClinicalTeal, weight: FontWeight.w700)),
      );

  Widget _accuracyPill(double a) {
    final int pct = (a * 100).round();
    final bool low = pct < 55;
    final Color c = low ? kClinicalRed : const Color(0xFF059669);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text('$pct%', style: _t(13, color: c, weight: FontWeight.w800)),
    );
  }

  Widget _difficultyDots(int level) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 1; i <= 5; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: i <= level ? kClinicalTeal : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
            ),
        ],
      );

  String _gameLabel(String g) {
    switch (g) {
      case 'pattern':
        return 'Pattern Match';
      case 'faces':
        return 'Family Faces';
      case 'voice':
        return 'Voice Recognition';
      case 'name_completion':
        return 'Name Completion';
      case 'milestone':
        return 'Milestone Recall';
      case 'routine':
        return 'Routine Sequencing';
      case 'objects':
        return 'Object ID';
      default:
        return g;
    }
  }

  TextStyle _t(double size, {Color? color, FontWeight? weight}) =>
      AppText.body(color: color).copyWith(fontSize: size, fontWeight: weight ?? FontWeight.w400);
}
