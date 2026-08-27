import 'package:flutter/material.dart';

import '../../core/models/patient_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/big_card.dart';
import 'doctor_patient_detail.dart';

/// Doctor web dashboard: manage multiple patients.
///
/// A doctor adds patients by their pairing code (links `doctors/{uid}` ->
/// patientIds[]), sees them as a responsive grid of cards, and opens any card
/// to a read-only patient detail (profile, performance, sessions, alerts).
class DoctorPatientList extends StatefulWidget {
  const DoctorPatientList({super.key, required this.uid});

  final String uid;

  @override
  State<DoctorPatientList> createState() => _DoctorPatientListState();
}

class _DoctorPatientListState extends State<DoctorPatientList> {
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _code = TextEditingController();

  List<PatientProfile> _patients = <PatientProfile>[];
  List<String> _unresolvedIds = <String>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<PatientProfile> patients = <PatientProfile>[];
    final List<String> unresolved = <String>[];
    try {
      final List<String> ids =
          await _fs.patientIdsForRole(uid: widget.uid, isDoctor: true);
      for (final String id in ids) {
        final Map<String, dynamic>? doc = await _fs.fetchPatientDoc(id);
        if (doc != null && doc.isNotEmpty) {
          patients.add(PatientProfile.fromMap(doc));
        } else {
          // Linked but its patient doc hasn't synced to the cloud yet.
          unresolved.add(id);
        }
      }
      _error = null;
    } catch (_) {
      _error = 'Could not load patients. Check your connection.';
    }
    if (!mounted) return;
    setState(() {
      _patients = patients;
      _unresolvedIds = unresolved;
      _loading = false;
    });
  }

  Future<void> _addByCode() async {
    final String code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _fs.linkPatientToRole(
        uid: widget.uid,
        patientId: code,
        isDoctor: true,
      );
      _code.clear();
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not add that code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(String patientId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorPatientDetail(patientId: patientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
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
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _addPatientCard(),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(_error!, style: _t(15, color: AppColors.gentleWarning)),
                  const SizedBox(height: 16),
                ],
                Text('Patients (${_patients.length + _unresolvedIds.length})',
                    style: _t(20, weight: FontWeight.w500)),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_patients.isEmpty && _unresolvedIds.isEmpty)
                  BigCard(
                    child: Text(
                      'No patients yet. Add one with a pairing code above.',
                      style: _t(15, color: AppColors.textMuted),
                    ),
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final PatientProfile p in _patients)
                        _patientCard(
                          id: p.id,
                          title: p.name.isEmpty ? p.id : p.name,
                          subtitle: 'Age ${p.age} · Stage ${p.stage}',
                          resolved: true,
                        ),
                      for (final String id in _unresolvedIds)
                        _patientCard(
                          id: id,
                          title: id,
                          subtitle: 'Waiting for cloud sync…',
                          resolved: false,
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addPatientCard() {
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a patient by code', style: _t(18, weight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  style: _t(16),
                  decoration: InputDecoration(
                    hintText: 'Pairing code (e.g. ABC123)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _addByCode(),
                ),
              ),
              const SizedBox(width: 12),
              _busy
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : FilledButton.icon(
                      onPressed: _addByCode,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _patientCard({
    required String id,
    required String title,
    required String subtitle,
    required bool resolved,
  }) {
    return SizedBox(
      width: 280,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: resolved ? () => _open(id) : null,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    title.isNotEmpty ? title[0].toUpperCase() : '?',
                    style: _t(18,
                        color: AppColors.primary, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(17, weight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (resolved)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Compact text helper for the (non-elderly) doctor web surface.
  TextStyle _t(double size, {Color? color, FontWeight? weight}) =>
      AppText.body(color: color).copyWith(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
      );
}
