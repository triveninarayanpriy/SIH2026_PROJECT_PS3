import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/patient_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';

/// Caregiver landing screen (placeholder for the caregiver feature set).
///
/// Shows the linked patient and re-displays the pairing code so it can be read
/// out to the family, plus sign-out and a developer shortcut.
class CaregiverHome extends StatelessWidget {
  const CaregiverHome({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: ValueListenableBuilder<Box<PatientProfile>>(
          valueListenable: LocalDb.profileBox.listenable(),
          builder: (context, _, _) {
            final PatientProfile? profile = LocalDb.getProfile(patientId);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  profile == null
                      ? 'Your patient'
                      : 'Caring for ${profile.name}',
                  style: AppText.title(),
                ),
                const SizedBox(height: 20),
                BigCard(
                  color: AppColors.primarySoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pairing code', style: AppText.body()),
                      const SizedBox(height: 8),
                      Text(
                        patientId,
                        style: AppText.gameQuestion(color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter this on the patient's device to link it.",
                        style: AppText.body(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                BigCard(
                  child: Text(
                    'Reminders, family voice recordings, photos and the daily '
                    'care log will live here.',
                    style: AppText.body(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                BigButton(
                  label: 'Developer: theme preview',
                  icon: Icons.palette_rounded,
                  color: AppColors.secondary,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/theme-preview'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
