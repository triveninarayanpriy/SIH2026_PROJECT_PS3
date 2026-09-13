import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_card.dart';
import 'milestone_config_screen.dart';
import 'object_config_screen.dart';
import 'routine_config_screen.dart';

/// Hub for the four personalised games' content. Family Name Completion reuses
/// the Family Media faces; the other three have dedicated editors here.
class GamesContentScreen extends StatelessWidget {
  const GamesContentScreen({super.key, this.embedded = false});

  /// When embedded in a tab, render the body only (no Scaffold/AppBar).
  final bool embedded;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: <Widget>[
          Text('These games use content you add, so every session feels personal.',
              style: AppText.body(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          _tile(
            context,
            title: 'Memories to recall',
            subtitle: 'Milestone & Life Events game',
            icon: Icons.auto_stories_rounded,
            color: AppColors.secondary,
            screen: const MilestoneConfigScreen(),
          ),
          _tile(
            context,
            title: 'Daily routine',
            subtitle: 'Routine Sequencing game',
            icon: Icons.checklist_rounded,
            color: AppColors.primary,
            screen: const RoutineConfigScreen(),
          ),
          _tile(
            context,
            title: 'Objects to identify',
            subtitle: 'Cultural & Personal Objects game',
            icon: Icons.category_rounded,
            color: AppColors.success,
            screen: const ObjectConfigScreen(),
          ),
          const SizedBox(height: 8),
          BigCard(
            color: AppColors.primarySoft,
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Family Name Completion uses the photos and names you add under '
                    'Family Media.',
                    style: AppText.body(color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    return embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Personalise games')),
            body: body,
          );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: () => _open(context, screen),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppText.button().copyWith(color: AppColors.text)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppText.body(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.border, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
