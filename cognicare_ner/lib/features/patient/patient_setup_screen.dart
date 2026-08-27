import 'package:flutter/material.dart';

import '../../core/services/local_db.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';

/// Shown on a patient device that isn't paired yet.
///
/// The family creates the patient in the caregiver app, which shows a short
/// pairing code. They type that code here once to link this device.
class PatientSetupScreen extends StatefulWidget {
  const PatientSetupScreen({super.key});

  @override
  State<PatientSetupScreen> createState() => _PatientSetupScreenState();
}

class _PatientSetupScreenState extends State<PatientSetupScreen> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final String code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter the code your family gives you.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await LocalDb.setLinkedPatientId(code);
    // Point the sync engine at this patient and pull their cloud data (if any).
    SyncService.instance.setPatient(code);
    // The PatientGate listens to appState and rebuilds to the Patient Home.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.family_restroom_rounded,
                size: 96,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Ask your family to set up this device',
                textAlign: TextAlign.center,
                style: AppText.title(),
              ),
              const SizedBox(height: 16),
              Text(
                'Your family will give you a short code. Type it below and press '
                'the big button.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted),
              ),
              const SizedBox(height: 28),
              BigCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Pairing code', style: AppText.body()),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _code,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: AppText.gameQuestion(),
                      decoration: InputDecoration(
                        hintText: 'ABC123',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.cardRadius),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppText.body(color: AppColors.gentleWarning),
                ),
              ],
              const SizedBox(height: 28),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                BigButton(
                  label: 'Link this device',
                  icon: Icons.link_rounded,
                  onTap: _link,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
