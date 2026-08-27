import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/big_card.dart';
import 'doctor_patient_detail.dart';
import 'doctor_repository.dart';

const Color _clinicalRed = Color(0xFFD64545);

/// Doctor web dashboard — read-only patient list.
///
/// Reads the doctor's patientIds[] and shows each patient with name, stage,
/// last-active, and a red dot for any unseen cognitive_drop alert. Cached
/// locally for a snappy load and offline viewing.
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

  @override
  void initState() {
    super.initState();
    _rows = DoctorRepository.cachedRows(widget.uid);
    _loading = _rows.isEmpty;
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final List<DoctorPatientRow> rows =
          await DoctorRepository.fetchRows(widget.uid);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  Future<void> _addByCode() async {
    final String code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _fs.linkPatientToRole(
          uid: widget.uid, patientId: code, isDoctor: true);
      _code.clear();
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not add that code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorPatientDetail(patientId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _addCard(),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(_error!,
                          style: _t(14, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text('Patients (${_rows.length})',
                    style: _t(20, weight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_rows.isEmpty)
                  BigCard(
                    child: Text(
                      'No patients yet. Add one with a pairing code above.',
                      style: _t(15, color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final DoctorPatientRow r in _rows) _rowTile(r),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addCard() {
    return BigCard(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              style: _t(16),
              decoration: InputDecoration(
                labelText: 'Add patient by pairing code',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _addByCode(),
            ),
          ),
          const SizedBox(width: 12),
          _busy
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: CircularProgressIndicator()))
              : FilledButton.icon(
                  onPressed: _addByCode,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _rowTile(DoctorPatientRow r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(r.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                    style: _t(18,
                        color: AppColors.primary, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(17, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Stage ${r.stage}  ·  Last active ${_lastActive(r.lastActive)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (r.hasAlert)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: const BoxDecoration(
                        color: _clinicalRed, shape: BoxShape.circle),
                  ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ),
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
    return DateFormat('MMM d, y').format(at);
  }

  TextStyle _t(double size, {Color? color, FontWeight? weight}) =>
      AppText.body(color: color)
          .copyWith(fontSize: size, fontWeight: weight ?? FontWeight.w400);
}
