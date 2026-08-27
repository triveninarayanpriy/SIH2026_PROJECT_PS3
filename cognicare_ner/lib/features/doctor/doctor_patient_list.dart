import 'package:flutter/material.dart';

import '../../core/models/patient_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';

/// Doctor landing screen: the list of patients assigned to this doctor.
///
/// For the demo a doctor can add a patient by its pairing code (the same code
/// the caregiver generated), which links the patient to this doctor account.
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
    try {
      final List<String> ids =
          await _fs.patientIdsForRole(uid: widget.uid, isDoctor: true);
      for (final String id in ids) {
        final Map<String, dynamic>? doc = await _fs.fetchPatientDoc(id);
        if (doc != null && doc.isNotEmpty) {
          patients.add(PatientProfile.fromMap(doc));
        }
      }
      _error = null;
    } catch (_) {
      _error = 'Could not load patients. Check your connection.';
    }
    if (!mounted) return;
    setState(() {
      _patients = patients;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BigCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add a patient by code', style: AppText.body()),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    style: AppText.body(),
                    decoration: InputDecoration(
                      hintText: 'Pairing code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_busy)
                    const Center(child: CircularProgressIndicator())
                  else
                    BigButton(
                      label: 'Add patient',
                      icon: Icons.add_rounded,
                      color: AppColors.secondary,
                      onTap: _addByCode,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: AppText.body(color: AppColors.gentleWarning)),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_patients.isEmpty)
              BigCard(
                child: Text(
                  'No patients assigned yet. Add one with a pairing code above.',
                  style: AppText.body(color: AppColors.textMuted),
                ),
              )
            else
              ..._patients.map(_patientCard),
          ],
        ),
      ),
    );
  }

  Widget _patientCard(PatientProfile p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BigCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: AppText.title()),
            const SizedBox(height: 8),
            Text(
              'Age ${p.age}  ·  Stage ${p.stage}  ·  ${p.id}',
              style: AppText.body(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
