import 'package:flutter/material.dart';

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
  int _step = 2;

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
            const SizedBox(height: 32),
          ],
        ),
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
