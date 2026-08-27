import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/alert.dart';
import '../../core/services/local_db.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';

/// Gentle heads-up shown only to the caregiver when a cognitive drop was
/// detected for [patientId]. The patient never sees this. Shows nothing when
/// there are no unseen alerts.
class CaregiverAlertBanner extends StatelessWidget {
  const CaregiverAlertBanner({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
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
                      child: Text('A gentle heads-up',
                          style: AppText.body()
                              .copyWith(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'We noticed ${_domainPhrase(a.domain)} getting harder over '
                  '~2 weeks — consider consulting a doctor.',
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
