import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/patient_profile.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';
import 'games/pattern_game.dart';

/// Patient landing screen. No scrolling, one calm greeting, big and simple.
///
/// Reacts to the local profile box so it shows a gentle "getting ready" state
/// until the linked [PatientProfile] is available (e.g. after a first sync).
class PatientHome extends StatelessWidget {
  const PatientHome({super.key, required this.patientId});

  final String patientId;

  void _play(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatternGame(patientId: patientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Small, out-of-the-way way to re-pair this device during testing.
          IconButton(
            tooltip: 'Unlink device',
            icon: const Icon(Icons.link_off_rounded),
            onPressed: LocalDb.clearLinkedPatientId,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: ValueListenableBuilder<Box<PatientProfile>>(
            valueListenable: LocalDb.profileBox.listenable(),
            builder: (context, _, _) {
              final PatientProfile? profile = LocalDb.getProfile(patientId);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    profile == null
                        ? Icons.hourglass_top_rounded
                        : Icons.emoji_emotions_rounded,
                    size: 96,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    profile == null
                        ? 'Getting things ready…'
                        : 'Hello, ${profile.name}',
                    textAlign: TextAlign.center,
                    style: AppText.gameQuestion(),
                  ),
                  const SizedBox(height: 24),
                  if (profile == null)
                    BigCard(
                      child: Text(
                        'This device is linked (code $patientId). Your '
                        'activities will appear here once everything is set up.',
                        textAlign: TextAlign.center,
                        style: AppText.body(color: AppColors.textMuted),
                      ),
                    )
                  else
                    BigButton(
                      label: 'What comes next?',
                      icon: Icons.extension_rounded,
                      onTap: () => _play(context),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
