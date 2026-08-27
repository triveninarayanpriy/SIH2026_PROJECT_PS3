import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/game_result.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'big_button.dart';
import 'big_card.dart';
import 'big_progress_dots.dart';
import 'gentle_feedback.dart';
import 'speak_label.dart';

/// Debug screen showing every design-system token and widget, for screenshots.
///
/// This screen may scroll because it is a developer/debug surface — patient
/// screens never scroll.
class ThemePreviewScreen extends StatefulWidget {
  const ThemePreviewScreen({super.key});

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  static const String _demoPatientId = 'demo-patient';

  int _step = 2;
  int _queueLen = 0;

  @override
  void initState() {
    super.initState();
    _queueLen = LocalDb.syncQueueLength();
  }

  /// Writes a dummy GameResult locally + enqueues it for cloud sync, then
  /// refreshes the visible queue length. Offline, the queue grows; online, the
  /// sync engine drains it back to 0.
  Future<void> _queueDummyResult() async {
    final GameResult result = GameResult(
      id: const Uuid().v4(),
      patientId: _demoPatientId,
      game: 'pattern',
      domain: 'attention',
      correct: 3,
      total: 5,
      durationMs: 4200,
      difficulty: 2,
      at: DateTime.now(),
    );
    await SyncService.instance.saveGameResult(result);
    if (!mounted) return;
    setState(() => _queueLen = LocalDb.syncQueueLength());
  }

  Future<void> _syncNow() async {
    await SyncService.instance.syncNow();
    if (!mounted) return;
    setState(() => _queueLen = LocalDb.syncQueueLength());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme preview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Colors'),
            _swatches(),
            _gap(),
            _section('Type scale'),
            Text('Game question · 40', style: AppText.gameQuestion()),
            const SizedBox(height: 10),
            Text('Title · 34 medium', style: AppText.title()),
            const SizedBox(height: 10),
            Text('Button · 28 medium', style: AppText.button()),
            const SizedBox(height: 10),
            Text(
              'Body · 24 — the quick brown fox jumps over the lazy dog.',
              style: AppText.body(),
            ),
            _gap(),
            _section('Big buttons'),
            BigButton(
              label: 'Play',
              icon: Icons.play_circle_fill_rounded,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            BigButton(
              label: 'Listen',
              icon: Icons.volume_up_rounded,
              color: AppColors.secondary,
              onTap: () {},
            ),
            _gap(),
            _section('Card + SpeakLabel'),
            BigCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SpeakLabel(text: 'Whose voice is this?'),
                  const SizedBox(height: 20),
                  const SpeakLabel(
                    text: 'Papa',
                    audioPath: 'assets/sounds/placeholder.m4a',
                  ),
                ],
              ),
            ),
            _gap(),
            _section('Progress dots (no timer)'),
            BigProgressDots(total: 5, current: _step),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BigButton(
                    label: 'Back',
                    color: AppColors.secondary,
                    onTap: () =>
                        setState(() => _step = (_step - 1).clamp(0, 5)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: BigButton(
                    label: 'Next',
                    onTap: () =>
                        setState(() => _step = (_step + 1).clamp(0, 5)),
                  ),
                ),
              ],
            ),
            _gap(),
            _section('Gentle feedback'),
            BigButton(
              label: 'Show "Very good!"',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              onTap: () => GentleFeedback.correct(context),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: "Show \"Let's try again\"",
              icon: Icons.refresh_rounded,
              color: AppColors.gentleWarning,
              onTap: () => GentleFeedback.tryAgain(context),
            ),
            _gap(),
            _section('Offline sync — Airplane test'),
            BigCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<String>(
                    stream: SyncService.instance.status,
                    initialData: SyncService.instance.currentStatus,
                    builder: (context, snap) =>
                        _syncChip(snap.data ?? SyncService.statusOffline),
                  ),
                  const SizedBox(height: 16),
                  Text('Queue length: $_queueLen', style: AppText.title()),
                  const SizedBox(height: 8),
                  Text(
                    'Turn ON Airplane mode, tap "Queue a game result" a few '
                    'times (watch the number grow), then turn Airplane mode OFF '
                    'and watch it drain back to 0 as it syncs to Firestore.',
                    style: AppText.body(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: 'Queue a game result',
              icon: Icons.add_task_rounded,
              color: AppColors.secondary,
              onTap: _queueDummyResult,
            ),
            const SizedBox(height: 16),
            BigButton(
              label: 'Sync now',
              icon: Icons.sync_rounded,
              onTap: _syncNow,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _syncChip(String status) {
    final (Color color, IconData icon, String label) = switch (status) {
      SyncService.statusSynced => (
          AppColors.success,
          Icons.cloud_done_rounded,
          'Synced',
        ),
      SyncService.statusSyncing => (
          AppColors.primary,
          Icons.sync_rounded,
          'Syncing…',
        ),
      _ => (AppColors.gentleWarning, Icons.cloud_off_rounded, 'Offline'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 8),
          Text(label, style: AppText.body(color: color)),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: AppText.title(color: AppColors.primary)),
      );

  Widget _gap() => const SizedBox(height: 28);

  Widget _swatches() {
    const List<(String, Color)> items = <(String, Color)>[
      ('primary', AppColors.primary),
      ('secondary', AppColors.secondary),
      ('success', AppColors.success),
      ('gentleWarning', AppColors.gentleWarning),
      ('correct', AppColors.correct),
      ('tryAgain', AppColors.tryAgain),
      ('reward', AppColors.reward),
      ('background', AppColors.background),
      ('surface', AppColors.surface),
      ('text', AppColors.text),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((it) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 72,
              decoration: BoxDecoration(
                color: it.$2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 84,
              child: Text(
                it.$1,
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textMuted)
                    .copyWith(fontSize: 15),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
