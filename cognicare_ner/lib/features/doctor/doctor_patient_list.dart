import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/clinical_charts.dart';
import 'doctor_patient_detail.dart';
import 'doctor_repository.dart';

/// Doctor dashboard — clinical patient monitor. On wide screens a sidebar list
/// sits beside the selected patient's detail; on phones it's a list that opens
/// each patient full-screen.
class DoctorPatientList extends StatefulWidget {
  const DoctorPatientList({super.key, required this.uid});

  final String uid;

  @override
  State<DoctorPatientList> createState() => _DoctorPatientListState();
}

class _DoctorPatientListState extends State<DoctorPatientList> {
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _code = TextEditingController();

  List<DoctorPatientRow> _rows = const <DoctorPatientRow>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _selectedId; // for the wide two-pane layout

  @override
  void initState() {
    super.initState();
    _rows = DoctorRepository.cachedRows(widget.uid);
    _loading = _rows.isEmpty;
    _selectedId = _rows.isNotEmpty ? _rows.first.id : null;
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Triage _triage(DoctorPatientRow r) {
    final sessions = DoctorRepository.cachedDetail(r.id)?.sessions ?? const [];
    return triageFor(sessions, hasAlert: r.hasAlert);
  }

  Future<void> _refresh() async {
    // Capture cached rows first (includes demo-seeded patients) so a
    // Firestore fetch that returns fewer rows doesn't drop them.
    final List<DoctorPatientRow> cachedBefore = DoctorRepository.cachedRows(widget.uid);
    List<DoctorPatientRow> fetched = const <DoctorPatientRow>[];
    String? error;
    try {
      fetched = await DoctorRepository.fetchRows(widget.uid);
    } catch (_) {
      error = 'Offline — showing cached data.';
    }
    // Merge by id, preferring fresh fetched rows but keeping cached-only ones.
    final Map<String, DoctorPatientRow> byId = <String, DoctorPatientRow>{
      for (final DoctorPatientRow r in fetched) r.id: r,
    };
    for (final DoctorPatientRow r in cachedBefore) {
      byId.putIfAbsent(r.id, () => r);
    }
    final List<DoctorPatientRow> merged = byId.values.toList();
    if (merged.isNotEmpty) {
      await LocalDb.putSetting(
          'doctorRows_${widget.uid}', merged.map((r) => r.toMap()).toList());
    }
    if (!mounted) return;
    setState(() {
      if (merged.isNotEmpty) _rows = merged;
      _selectedId ??= _rows.isNotEmpty ? _rows.first.id : null;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _addByCode() async {
    final String code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _fs.linkPatientToRole(uid: widget.uid, patientId: code, isDoctor: true);
      _code.clear();
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not add that code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openNarrow(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DoctorPatientDetail(patientId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClinicalBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kClinicalTeal,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kClinicalTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.biotech_rounded, color: kClinicalTeal, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('NAWAL Clinical',
                    style: AppText.title().copyWith(fontSize: 17, color: kClinicalTeal)),
                Text('Remote cognitive monitoring',
                    style: AppText.body(color: const Color(0xFF64748B)).copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final bool wide = c.maxWidth > 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(width: 320, child: _sidebar()),
                Expanded(
                  child: _selectedId == null
                      ? Center(
                          child: Text('Select a patient',
                              style: AppText.body(color: const Color(0xFF64748B))))
                      : DoctorPatientDetail(
                          key: ValueKey<String>(_selectedId!),
                          patientId: _selectedId!,
                          embedded: true,
                        ),
                ),
              ],
            );
          }
          return _listOnly();
        },
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _summaryPills(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: <Widget>[
                      for (final DoctorPatientRow r in _rows)
                        _rowTile(r, selected: r.id == _selectedId, onTap: () {
                          setState(() => _selectedId = r.id);
                        }),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: _addRow()),
        ],
      ),
    );
  }

  Widget _listOnly() {
    return ListView(
      children: <Widget>[
        _summaryPills(),
        Padding(padding: const EdgeInsets.all(16), child: _addRow()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: <Widget>[
              const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(_error!, style: AppText.body(color: const Color(0xFF64748B)).copyWith(fontSize: 13)),
            ]),
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          for (final DoctorPatientRow r in _rows)
            _rowTile(r, selected: false, onTap: () => _openNarrow(r.id)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _summaryPills() {
    int red = 0, amber = 0, green = 0;
    for (final DoctorPatientRow r in _rows) {
      switch (_triage(r)) {
        case Triage.red:
          red++;
          break;
        case Triage.amber:
          amber++;
          break;
        case Triage.green:
          green++;
          break;
      }
    }
    Widget pill(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: AppText.body().copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          pill(kClinicalRed, '$red Alert'),
          pill(const Color(0xFFF59E0B), '$amber Watch'),
          pill(const Color(0xFF059669), '$green Stable'),
        ],
      ),
    );
  }

  Widget _addRow() {
    return Row(children: <Widget>[
      Expanded(
        child: TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          style: AppText.body().copyWith(fontSize: 15),
          decoration: InputDecoration(
            labelText: 'Add patient by code',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (_) => _addByCode(),
        ),
      ),
      const SizedBox(width: 8),
      _busy
          ? const SizedBox(width: 40, height: 40, child: Center(child: CircularProgressIndicator()))
          : IconButton.filled(
              onPressed: _addByCode,
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(backgroundColor: kClinicalTeal),
            ),
    ]);
  }

  Widget _rowTile(DoctorPatientRow r, {required bool selected, required VoidCallback onTap}) {
    final Triage t = _triage(r);
    return Material(
      color: selected ? kClinicalTeal.withValues(alpha: 0.06) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: selected ? kClinicalTeal : Colors.transparent, width: 4),
              bottom: const BorderSide(color: Color(0xFFF1F5F9)),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body().copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: selected ? kClinicalTeal : const Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('Stage ${r.stage}  ·  ${_lastActive(r.lastActive)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(color: const Color(0xFF64748B)).copyWith(fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: t.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(t.label,
                    style: AppText.body().copyWith(fontSize: 11, fontWeight: FontWeight.w800, color: t.color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastActive(DateTime? at) {
    if (at == null) return '—';
    final int days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    return DateFormat('MMM d').format(at);
  }
}
