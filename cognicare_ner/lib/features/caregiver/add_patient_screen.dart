import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/models/patient_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/local_db.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';

/// Unambiguous pairing-code alphabet (no 0/O, 1/I/L).
const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String generatePatientId() {
  final Random rng = Random();
  return List<String>.generate(
    6,
    (_) => _codeAlphabet[rng.nextInt(_codeAlphabet.length)],
  ).join();
}

/// Caregiver onboarding: create the patient and reveal the pairing code.
class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _languages = TextEditingController(text: 'English');
  final TextEditingController _region = TextEditingController();

  int _stage = 1;
  bool _busy = false;
  String? _error;
  String? _createdId;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _languages.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Please enter the patient's name.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final String id = generatePatientId();
    final PatientProfile profile = PatientProfile(
      id: id,
      name: name,
      age: int.tryParse(_age.text.trim()) ?? 0,
      stage: _stage,
      languages: _languages.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      region: _region.text.trim(),
      createdAt: DateTime.now(),
    );

    // Write-through: local first, enqueue patients/{id} for cloud sync.
    await SyncService.instance.saveProfile(profile);
    final String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await FirestoreService()
            .linkPatientToRole(uid: uid, patientId: id, isDoctor: false);
      } catch (_) {
        // Best-effort; the local link below is what routing relies on.
      }
    }
    SyncService.instance.setPatient(id);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _createdId = id;
    });
  }

  Future<void> _finish() async {
    // Setting this flips the CaregiverGate over to the Caregiver Home.
    await LocalDb.setCaregiverPatientId(_createdId!);
  }

  @override
  Widget build(BuildContext context) {
    final String? code = _createdId;
    return Scaffold(
      appBar: AppBar(title: Text(code == null ? 'Add patient' : 'Patient added')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: code == null ? _form() : _codeView(code),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tell us about the person you care for.', style: AppText.body()),
        const SizedBox(height: 20),
        _field(_name, 'Name'),
        const SizedBox(height: 16),
        _field(_age, 'Age', keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _stagePicker(),
        const SizedBox(height: 16),
        _field(_languages, 'Languages (comma separated)'),
        const SizedBox(height: 16),
        _field(_region, 'Region'),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: AppText.body(color: AppColors.gentleWarning)),
        ],
        const SizedBox(height: 28),
        if (_busy)
          const Center(child: CircularProgressIndicator())
        else
          BigButton(
            label: 'Create patient',
            icon: Icons.person_add_alt_1_rounded,
            onTap: _create,
          ),
      ],
    );
  }

  Widget _codeView(String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.check_circle_rounded,
            size: 88, color: AppColors.success),
        const SizedBox(height: 20),
        Text('Patient created!', textAlign: TextAlign.center,
            style: AppText.title()),
        const SizedBox(height: 16),
        Text(
          "Enter this code on the patient's device to link it:",
          textAlign: TextAlign.center,
          style: AppText.body(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        BigCard(
          color: AppColors.primarySoft,
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: AppText.gameQuestion(color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 28),
        BigButton(
          label: 'Done',
          icon: Icons.arrow_forward_rounded,
          onTap: _finish,
        ),
      ],
    );
  }

  Widget _stagePicker() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Dementia stage (1–5)',
        labelStyle: AppText.body(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: DropdownButton<int>(
        value: _stage,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        style: AppText.body(),
        items: [for (int i = 1; i <= 5; i++) i]
            .map((i) => DropdownMenuItem<int>(
                  value: i,
                  child: Text('Stage $i', style: AppText.body()),
                ))
            .toList(),
        onChanged: (v) => setState(() => _stage = v ?? 1),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppText.body(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
      ),
    );
  }
}
