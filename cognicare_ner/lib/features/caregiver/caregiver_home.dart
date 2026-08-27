import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/alert.dart';
import '../../core/models/patient_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_db.dart';
import '../../core/services/sync_service.dart';
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
                _alertBanner(),
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

  /// Gentle heads-up shown only to the caregiver when a cognitive drop was
  /// detected. The patient is never shown this.
  Widget _alertBanner() {
    return ValueListenableBuilder<Box<Alert>>(
      valueListenable: LocalDb.alertsBox.listenable(),
      builder: (context, _, _) {
        final List<Alert> unseen = LocalDb.allAlerts()
            .where((a) => a.patientId == patientId && !a.seen)
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
        if (unseen.isEmpty) return const SizedBox.shrink();
        final Alert a = unseen.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.tryAgainSurface,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: AppColors.gentleWarning, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.gentleWarning, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A gentle heads-up',
                        style:
                            AppText.body().copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'We noticed ${_domainPhrase(a.domain)} getting harder over '
                  '~2 weeks — consider seeing a doctor.',
                  style: AppText.body(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _dismiss(unseen),
                    child: Text('Okay, thanks',
                        style: AppText.body(color: AppColors.primary)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _domainPhrase(String domain) {
    switch (domain) {
      case 'memory':
        return 'memory tasks';
      case 'attention':
        return 'attention tasks';
      case 'auditory':
        return 'listening tasks';
      default:
        return 'some activities';
    }
  }

  Future<void> _dismiss(List<Alert> alerts) async {
    for (final Alert a in alerts) {
      await SyncService.instance.saveAlert(
        Alert(
          id: a.id,
          patientId: a.patientId,
          type: a.type,
          domain: a.domain,
          deltaPct: a.deltaPct,
          at: a.at,
          seen: true,
        ),
      );
    }
  }
}
