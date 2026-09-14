import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/patient_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_card.dart';
import '../../core/widgets/nawal_ui.dart';
import '../../core/widgets/remote_status_chip.dart';
import 'caregiver_alert_banner.dart';
import 'caregiver_dashboard.dart';
import 'caregiver_game_config_screen.dart';
import 'caregiver_media_hub.dart';
import '../shared/language_selector_screen.dart';
import 'caregiver_reminders_screen.dart';
import 'remote_connect_screen.dart';

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
      backgroundColor: AppColors.skyBg,
      appBar: AppBar(
        title: const Text('Caregiver Hub'),
        actions: [
          const Center(child: RemoteStatusChip(compact: true)),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: NawalPage(
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
                    gradient: const LinearGradient(colors: <Color>[AppColors.ink, AppColors.inkDark]),
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
                Text('Quick Actions', style: AppText.title().copyWith(fontSize: 24, color: AppColors.inkDark)),
                const SizedBox(height: 16),
                ResponsiveCardGrid(
                  columns: 2,
                  children: <Widget>[
                    NawalListTile(
                      icon: Icons.insights_rounded,
                      title: 'View Progress',
                      subtitle: 'Track cognitive stats and history',
                      onTap: () => _open(context, CaregiverDashboard(patientId: patientId)),
                    ),
                    NawalListTile(
                      icon: Icons.perm_media_rounded,
                      title: 'Content Studio',
                      subtitle: 'Photos, voices, music, welcome & game content',
                      onTap: () => _open(context, CaregiverMediaHub(patientId: patientId)),
                    ),
                    NawalListTile(
                      icon: Icons.alarm_rounded,
                      title: 'Reminders',
                      subtitle: 'Set medication and daily tasks',
                      onTap: () => _open(context, CaregiverRemindersScreen(patientId: patientId)),
                    ),
                    NawalListTile(
                      icon: Icons.videogame_asset_rounded,
                      title: 'Game Settings',
                      subtitle: 'Configure game difficulty and rules',
                      onTap: () => _open(context, const CaregiverGameConfigScreen()),
                    ),
                    NawalListTile(
                      icon: Icons.gamepad_rounded,
                      title: 'NAWAL Remote',
                      subtitle: 'Pair the Bluetooth remote and see its buttons',
                      onTap: () => _open(context, const RemoteConnectScreen()),
                    ),
                    NawalListTile(
                      icon: Icons.language_rounded,
                      title: 'Language',
                      subtitle: 'Change application language',
                      onTap: () => _open(context, const LanguageSelectorScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                BigCard(
                  color: AppColors.surface,
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
      ),
    );
  }
}
