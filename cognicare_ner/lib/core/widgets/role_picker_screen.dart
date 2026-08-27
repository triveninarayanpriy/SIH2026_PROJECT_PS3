import 'package:flutter/material.dart';

import '../services/local_db.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'big_button.dart';

/// Launch role picker for the unified demo app.
///
/// Choosing a role stores it in [LocalDb.setActiveRole]; the app then rebuilds
/// into that role's flow. The small "Role" button (bottom-left) returns here to
/// switch — all on one device, one running app.
class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CogniCare NER')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.groups_rounded, size: 96, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Who is using this device?',
                textAlign: TextAlign.center,
                style: AppText.title(),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a role to begin. You can switch anytime.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              BigButton(
                label: 'Patient',
                icon: Icons.emoji_emotions_rounded,
                onTap: () => LocalDb.setActiveRole('patient'),
              ),
              const SizedBox(height: 16),
              BigButton(
                label: 'Caregiver',
                icon: Icons.volunteer_activism_rounded,
                color: AppColors.secondary,
                onTap: () => LocalDb.setActiveRole('caregiver'),
              ),
              const SizedBox(height: 16),
              BigButton(
                label: 'Doctor',
                icon: Icons.medical_services_rounded,
                color: AppColors.success,
                onTap: () => LocalDb.setActiveRole('doctor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
