import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/patient_profile.dart';
import '../../core/models/reminder.dart';
import '../../core/services/local_db.dart';
import '../../core/services/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/big_card.dart';
import '../../l10n/app_localizations.dart';
import 'calm_mode.dart';
import 'games/family_game.dart';
import 'games/pattern_game.dart';
import 'games/voice_game.dart';
import 'simulation_mode_screen.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key, required this.patientId});

  final String patientId;

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  Timer? _reminderTimer;
  final Set<String> _shownReminders = {};
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startReminderTimer();
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkReminders();
    });
  }

  void _checkReminders() {
    final now = TimeOfDay.now();
    final hhmm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final reminders = LocalDb.allReminders();

    for (final reminder in reminders) {
      if (reminder.time == hhmm) {
        final key = '${reminder.id}_$hhmm';
        if (!_shownReminders.contains(key)) {
          _shownReminders.add(key);
          _showReminderDialog(reminder);
        }
      }
    }
  }

  Future<void> _showReminderDialog(Reminder reminder) async {
    if (reminder.audioLocalPath != null) {
      try {
        await _player.setFilePath(reminder.audioLocalPath!);
        await _player.play();
      } catch (e) {
        debugPrint('Failed to play reminder audio: $e');
      }
    }

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog.fullscreen(
          child: Container(
            color: AppColors.primary.withOpacity(0.1),
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active_rounded, size: 100, color: AppColors.primary),
                const SizedBox(height: 32),
                Text(
                  reminder.title,
                  style: AppText.title().copyWith(fontSize: 48),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'It is time for your ${reminder.type}.',
                  style: AppText.body().copyWith(fontSize: 32),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 64),
                BigButton(
                  label: 'Dismiss',
                  icon: Icons.check_circle_rounded,
                  onTap: () {
                    _player.stop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<Box<PatientProfile>>(
        valueListenable: LocalDb.profileBox.listenable(),
        builder: (context, _, _) {
          final PatientProfile? profile = LocalDb.getProfile(widget.patientId);
          final AppLocalizations t = AppLocalizations.of(context);
          if (profile != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final saved = LocalDb.getSetting('app_locale') as String?;
                if (saved != null) {
                  LocaleController.setLocale(Locale(saved));
                } else {
                  LocaleController.setFromLanguages(profile.languages);
                }
            });
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.screenPadding),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.emoji_emotions_rounded, size: 48, color: Colors.white),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile == null ? 'Getting ready...' : 'Hello,',
                                    style: AppText.title().copyWith(color: Colors.white70, fontSize: 24),
                                  ),
                                  if (profile != null)
                                    Text(
                                      profile.name,
                                      style: AppText.title().copyWith(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Unlink device',
                    icon: const Icon(Icons.link_off_rounded, color: Colors.white),
                    onPressed: LocalDb.clearLinkedPatientId,
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.screenPadding),
                  child: profile == null
                      ? BigCard(
                          child: Text(
                            'This device is linked (code ${widget.patientId}). Your activities will appear here once everything is set up.',
                            textAlign: TextAlign.center,
                            style: AppText.body(color: AppColors.textMuted),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Activities for today', style: AppText.title().copyWith(fontSize: 28)),
                            const SizedBox(height: 24),
                            _GameCard(
                              title: t.whatComesNext,
                              description: 'Pattern matching exercise',
                              icon: Icons.extension_rounded,
                              gradient: const LinearGradient(colors: AppColors.primaryGradient),
                              onTap: () => _open(context, PatternGame(patientId: widget.patientId)),
                            ),
                            const SizedBox(height: 16),
                            _GameCard(
                              title: t.whoIsThis,
                              description: 'Face recognition game',
                              icon: Icons.face_rounded,
                              gradient: const LinearGradient(colors: AppColors.secondaryGradient),
                              onTap: () => _open(context, FamilyGame(patientId: widget.patientId)),
                            ),
                            const SizedBox(height: 16),
                            _GameCard(
                              title: t.whoseVoiceIsThis,
                              description: 'Voice recognition exercise',
                              icon: Icons.hearing_rounded,
                              gradient: const LinearGradient(colors: AppColors.successGradient),
                              onTap: () => _open(context, VoiceGame(patientId: widget.patientId)),
                            ),
                            const SizedBox(height: 24),
                            _GameCard(
                              title: t.relax,
                              description: 'Take a break and calm down',
                              icon: Icons.self_improvement_rounded,
                              gradient: const LinearGradient(colors: AppColors.calmGradient),
                              iconColor: AppColors.secondary,
                              onTap: () => _open(context, const CalmModeScreen()),
                            ),
                            const SizedBox(height: 24),
                            BigButton(
                              label: 'VR Simulation (Experimental)',
                              icon: Icons.spa_rounded,
                              color: AppColors.secondary,
                              onTap: () => _open(context, const SimulationModeScreen()),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    this.iconColor = Colors.white,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
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
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: Center(
                    child: Icon(icon, size: 40, color: iconColor),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.button().copyWith(color: AppColors.text, fontSize: 26)),
                      const SizedBox(height: 8),
                      Text(description, style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 20)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

