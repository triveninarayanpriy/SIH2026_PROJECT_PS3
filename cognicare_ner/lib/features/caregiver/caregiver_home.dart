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
import 'caregiver_alert_banner.dart';
import 'caregiver_dashboard.dart';
import 'caregiver_game_config_screen.dart';
import 'caregiver_media_hub.dart';
import '../shared/language_selector_screen.dart';
import 'caregiver_reminders_screen.dart';

/// Caregiver landing screen. Shows the alert banner, the linked patient + the
/// pairing code, a shortcut into the progress dashboard, and sign-out.
class CaregiverHome extends StatelessWidget {
  const CaregiverHome({super.key, required this.patientId});

  final String patientId;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Hub'),
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
                CaregiverAlertBanner(patientId: patientId),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.primaryGradient),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile == null ? 'Your patient' : 'Caring for',
                              style: AppText.body(color: Colors.white70),
                            ),
                            if (profile != null)
                              Text(
                                profile.name,
                                style: AppText.title().copyWith(color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Quick Actions', style: AppText.title().copyWith(fontSize: 24)),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'View Progress',
                  description: 'Track cognitive stats and history',
                  icon: Icons.insights_rounded,
                  color: AppColors.primary,
                  onTap: () => _open(context, CaregiverDashboard(patientId: patientId)),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Family Media',
                  description: 'Manage photos and familiar voices',
                  icon: Icons.photo_library_rounded,
                  color: AppColors.secondary,
                  onTap: () => _open(context, CaregiverMediaHub(patientId: patientId)),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Reminders',
                  description: 'Set medication and daily tasks',
                  icon: Icons.alarm_rounded,
                  color: AppColors.gentleWarning,
                  onTap: () => _open(context, CaregiverRemindersScreen(patientId: patientId)),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Game Settings',
                  description: 'Configure game difficulty and rules',
                  icon: Icons.videogame_asset_rounded,
                  color: AppColors.success,
                  onTap: () => _open(context, const CaregiverGameConfigScreen()),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Language',
                  description: 'Change application language',
                  icon: Icons.language_rounded,
                  color: AppColors.primaryDark,
                  onTap: () => _open(context, const LanguageSelectorScreen()),
                ),
                const SizedBox(height: 24),
                BigCard(
                  color: AppColors.primarySoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pairing code', style: AppText.body()),
                      const SizedBox(height: 8),
                      Text(
                        patientId,
                        style: AppText.gameQuestion(color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter this on the patient's device to link it.",
                        style: AppText.body(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.button().copyWith(color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text(description, style: AppText.body(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.border, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
