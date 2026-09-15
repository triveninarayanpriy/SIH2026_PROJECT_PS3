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
import '../../core/widgets/nawal_ui.dart';
import '../../core/widgets/remote_status_chip.dart';
import '../../l10n/app_localizations.dart';
import 'calm_mode.dart';
import 'games/family_game.dart';
import 'games/milestone_game.dart';
import 'games/name_completion_game.dart';
import 'games/object_game.dart';
import 'games/pattern_game.dart';
import 'games/routine_game.dart';
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
        final AppLocalizations t = AppLocalizations.of(context);
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
                  t.reminderItsTime,
                  style: AppText.body().copyWith(fontSize: 32),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 64),
                BigButton(
                  label: t.dismiss,
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

  /// Whether a game is enabled in caregiver Game Settings (default on).
  bool _enabled(String key) =>
      (LocalDb.getSetting('gameConfig_${key}_enabled') as bool?) ?? true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.skyBg,
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
                backgroundColor: AppColors.ink,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[AppColors.ink, AppColors.inkDark],
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
                                    profile == null ? t.gettingReady : t.hello,
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
                actions: const [
                  Center(child: RemoteStatusChip(compact: true)),
                  SizedBox(width: 4),
                  _UnlinkButton(),
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
                      : NawalPage(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(t.activitiesForToday,
                                  style: AppText.title().copyWith(fontSize: 28, color: AppColors.inkDark)),
                              const SizedBox(height: 20),
                              ResponsiveCardGrid(
                                columns: 2,
                                children: <Widget>[
                                  if (_enabled('pattern'))
                                    NawalListTile(
                                      icon: Icons.extension_rounded,
                                      title: t.whatComesNext,
                                      subtitle: t.descPattern,
                                      onTap: () => _open(context, PatternGame(patientId: widget.patientId)),
                                    ),
                                  if (_enabled('faces'))
                                    NawalListTile(
                                      icon: Icons.face_rounded,
                                      title: t.whoIsThis,
                                      subtitle: t.descFaces,
                                      onTap: () => _open(context, FamilyGame(patientId: widget.patientId)),
                                    ),
                                  if (_enabled('voice'))
                                    NawalListTile(
                                      icon: Icons.hearing_rounded,
                                      title: t.whoseVoiceIsThis,
                                      subtitle: t.descVoice,
                                      onTap: () => _open(context, VoiceGame(patientId: widget.patientId)),
                                    ),
                                  if (_enabled('name_completion'))
                                    NawalListTile(
                                      icon: Icons.abc_rounded,
                                      title: t.gameCompleteName,
                                      subtitle: t.descCompleteName,
                                      onTap: () => _open(context, NameCompletionGame(patientId: widget.patientId)),
                                    ),
                                  if (_enabled('milestone'))
                                    NawalListTile(
                                      icon: Icons.auto_stories_rounded,
                                      title: t.gameRemember,
                                      subtitle: t.descRemember,
                                      onTap: () => _open(context, MilestoneGame(patientId: widget.patientId)),
                                    ),
                                  if (_enabled('routine'))
                                    NawalListTile(
                                      icon: Icons.checklist_rounded,
                                      title: t.gameDailyRoutine,
                                      subtitle: t.descRoutine,
                                      onTap: () => _open(context, RoutineGame(patientId: widget.patientId)),
                                    ),
                                  if (_enabled('objects'))
                                    NawalListTile(
                                      icon: Icons.category_rounded,
                                      title: t.gameWhatIsThis,
                                      subtitle: t.descObjects,
                                      onTap: () => _open(context, ObjectGame(patientId: widget.patientId)),
                                    ),
                                  // Rest sits in the same grid so it aligns with
                                  // the game tiles instead of spanning full width.
                                  NawalListTile(
                                    icon: Icons.self_improvement_rounded,
                                    iconColor: AppColors.secondary,
                                    title: t.relax,
                                    subtitle: t.takeBreak,
                                    onTap: () => _open(context, const CalmModeScreen()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              BigButton(
                                label: 'VR Simulation (Experimental)',
                                icon: Icons.spa_rounded,
                                color: AppColors.ink,
                                onTap: () => _open(context, const SimulationModeScreen()),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
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

class _UnlinkButton extends StatelessWidget {
  const _UnlinkButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Unlink device',
      icon: const Icon(Icons.link_off_rounded, color: Colors.white),
      onPressed: LocalDb.clearLinkedPatientId,
    );
  }
}


