import 'package:flutter/material.dart';

import '../services/local_db.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primarySoft, AppColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Column(
                  children: [
                    const Icon(Icons.favorite_rounded, size: 64, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'NAWAL',
                      style: AppText.title().copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'नवल',
                      style: AppText.title().copyWith(
                        fontSize: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A new life, built from old memories',
                      style: AppText.body().copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                _RoleCard(
                  title: 'Patient',
                  description: 'Play games and exercises',
                  icon: Icons.emoji_emotions_rounded,
                  gradient: const LinearGradient(colors: AppColors.successGradient),
                  onTap: () => LocalDb.setActiveRole('patient'),
                ),
                const SizedBox(height: 20),
                _RoleCard(
                  title: 'Caregiver',
                  description: 'Manage care and track progress',
                  icon: Icons.volunteer_activism_rounded,
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                  onTap: () => LocalDb.setActiveRole('caregiver'),
                ),
                const SizedBox(height: 20),
                _RoleCard(
                  title: 'Doctor',
                  description: 'Monitor patients and reports',
                  icon: Icons.medical_services_rounded,
                  gradient: const LinearGradient(colors: AppColors.secondaryGradient),
                  onTap: () => LocalDb.setActiveRole('doctor'),
                ),
                const SizedBox(height: 32),
                Text(
                  'You can switch roles anytime',
                  textAlign: TextAlign.center,
                  style: AppText.body(color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowDark,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.cardRadius),
                      bottomLeft: Radius.circular(AppTheme.cardRadius),
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, size: 48, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppText.title().copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: AppText.body(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
