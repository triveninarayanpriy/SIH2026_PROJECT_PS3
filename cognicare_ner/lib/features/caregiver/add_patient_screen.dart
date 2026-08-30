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
  final TextEditingController _clinicalNotes = TextEditingController();
  
  String _selectedLanguage = 'English';
  final List<String> _languages = [
    'Assamese', 'Bengali', 'Bodo', 'English', 'Hindi', 'Khasi', 'Manipuri/Meitei', 'Mizo', 'Nagamese'
  ];

  String _selectedRegion = 'Assam';
  final List<String> _regions = [
    'Arunachal Pradesh', 'Assam', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Sikkim', 'Tripura'
  ];

  int _stage = 1;
  bool _busy = false;
  String? _error;
  String? _createdId;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _clinicalNotes.dispose();
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
      languages: [_selectedLanguage],
      region: _selectedRegion,
      clinicalNotes: _clinicalNotes.text.trim(),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          code == null ? 'Add Patient Profile' : 'Profile Created',
          style: AppText.title(color: AppColors.primary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: code == null ? _form() : _codeView(code),
      ),
    );
  }

  Widget _form() {
    return BigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Patient Information', style: AppText.title(color: AppColors.primaryDark)),
          const SizedBox(height: 8),
          Text('Please enter the clinical details for the person you care for.', style: AppText.body(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          _field(_name, 'Full Name', Icons.person_outline),
          const SizedBox(height: 16),
          _field(_age, 'Age', Icons.cake_outlined, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _dropdownField<String>(
            label: 'Primary Language',
            icon: Icons.language_outlined,
            value: _selectedLanguage,
            items: _languages,
            onChanged: (val) => setState(() => _selectedLanguage = val!),
          ),
          const SizedBox(height: 16),
          _stagePicker(),
          const SizedBox(height: 16),
          _dropdownField<String>(
            label: 'Region / Location',
            icon: Icons.location_on_outlined,
            value: _selectedRegion,
            items: _regions,
            onChanged: (val) => setState(() => _selectedRegion = val!),
          ),
          const SizedBox(height: 16),
          _field(
            _clinicalNotes, 
            'Clinical Notes / Medical History', 
            Icons.medical_information_outlined,
            maxLines: 4,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.gentleWarning),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error!, style: AppText.body(color: AppColors.gentleWarning))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            BigButton(
              label: 'Create Patient Profile',
              icon: Icons.person_add_alt_1_rounded,
              onTap: _create,
            ),
        ],
      ),
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
        Text('Patient Profile Created!', textAlign: TextAlign.center,
            style: AppText.title()),
        const SizedBox(height: 16),
        Text(
          "Enter this secure pairing code on the patient's device to link their account:",
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
          label: 'Complete Setup',
          icon: Icons.arrow_forward_rounded,
          onTap: _finish,
        ),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      style: AppText.body(),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _stagePicker() {
    return DropdownButtonFormField<int>(
      value: _stage,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
      decoration: InputDecoration(
        labelText: 'Dementia Stage (1-5)',
        labelStyle: AppText.body(color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.medical_services_outlined, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      style: AppText.body(),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Stage 1 - Normal / No Impairment')),
        DropdownMenuItem(value: 2, child: Text('Stage 2 - Very Mild Decline')),
        DropdownMenuItem(value: 3, child: Text('Stage 3 - Mild Decline')),
        DropdownMenuItem(value: 4, child: Text('Stage 4 - Moderate Decline')),
        DropdownMenuItem(value: 5, child: Text('Stage 5 - Moderately Severe')),
      ],
      onChanged: (v) => setState(() => _stage = v ?? 1),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppText.body(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body(color: AppColors.textMuted),
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            top: maxLines > 1 ? 16.0 : 0.0,
            bottom: maxLines > 1 ? (16.0 * (maxLines - 1)) : 0.0,
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
