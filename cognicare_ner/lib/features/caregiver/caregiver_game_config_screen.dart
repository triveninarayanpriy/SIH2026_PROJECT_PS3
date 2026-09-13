import 'package:flutter/material.dart';

import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';

/// One configurable game.
class _GameDef {
  const _GameDef(this.key, this.title, this.domain, this.icon, this.color);
  final String key;
  final String title;
  final String domain;
  final IconData icon;
  final Color color;
}

const List<_GameDef> _games = <_GameDef>[
  _GameDef('pattern', 'Pattern Match', 'Attention', Icons.grid_view_rounded, AppColors.primary),
  _GameDef('faces', 'Family Faces', 'Memory', Icons.face_rounded, AppColors.secondary),
  _GameDef('voice', 'Voice Recognition', 'Listening', Icons.record_voice_over_rounded, AppColors.success),
  _GameDef('name_completion', 'Name Completion', 'Language', Icons.abc_rounded, AppColors.primaryDark),
  _GameDef('milestone', 'Memories to Recall', 'Memory', Icons.auto_stories_rounded, AppColors.secondaryDark),
  _GameDef('routine', 'Daily Routine', 'Sequencing', Icons.checklist_rounded, AppColors.gentleWarning),
  _GameDef('objects', 'Object Identification', 'Attention', Icons.category_rounded, AppColors.success),
];

/// Professional caregiver control panel for each game: on/off, adaptive vs a
/// fixed difficulty, and the number of rounds. Difficulty applies only when
/// Adaptive is off (otherwise the app tunes it automatically).
class CaregiverGameConfigScreen extends StatefulWidget {
  const CaregiverGameConfigScreen({super.key});

  @override
  State<CaregiverGameConfigScreen> createState() => _CaregiverGameConfigScreenState();
}

class _CaregiverGameConfigScreenState extends State<CaregiverGameConfigScreen> {
  bool _b(String key, bool fallback) =>
      (LocalDb.getSetting(key) as bool?) ?? fallback;
  int _i(String key, int fallback) =>
      (LocalDb.getSetting(key) as int?) ?? fallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(title: const Text('Game Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: <Widget>[
              Text('Customise each game', style: AppText.title().copyWith(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                'Turn games on or off, choose how challenging they are, and set '
                'how many rounds each session runs.',
                style: AppText.body(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              for (final _GameDef g in _games) ...<Widget>[
                _GameCard(
                  def: g,
                  enabled: _b('gameConfig_${g.key}_enabled', true),
                  adaptive: _b('gameConfig_${g.key}_adaptive', true),
                  difficulty: _i('gameConfig_${g.key}_difficulty', 2),
                  rounds: _i('gameConfig_${g.key}_rounds', 5),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.def,
    required this.enabled,
    required this.adaptive,
    required this.difficulty,
    required this.rounds,
    required this.onChanged,
  });

  final _GameDef def;
  final bool enabled;
  final bool adaptive;
  final int difficulty;
  final int rounds;
  final VoidCallback onChanged;

  void _set(String suffix, Object value) {
    LocalDb.putSetting('gameConfig_${def.key}_$suffix', value);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row: icon, title/domain, enable switch.
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: def.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(def.icon, color: def.color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(def.title, style: AppText.title().copyWith(fontSize: 18)),
                    Text(def.domain,
                        style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 13)),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: AppColors.success,
                onChanged: (v) => _set('enabled', v),
              ),
            ],
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: 8),
            const Divider(height: 20, color: Color(0xFFEEF1F5)),
            // Adaptive toggle.
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Adaptive difficulty',
                      style: AppText.body().copyWith(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: adaptive,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => _set('adaptive', v),
                ),
              ],
            ),
            Text(
              adaptive
                  ? 'The app adjusts the level automatically based on how the patient does.'
                  : 'Fixed at the level you choose below.',
              style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 14),
            // Difficulty segmented (only when not adaptive).
            Opacity(
              opacity: adaptive ? 0.4 : 1,
              child: IgnorePointer(
                ignoring: adaptive,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Difficulty', style: AppText.body().copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        for (int i = 1; i <= 5; i++)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _set('difficulty', i),
                              child: Container(
                                margin: EdgeInsets.only(right: i < 5 ? 6 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: i == difficulty ? def.color : AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: i == difficulty ? def.color : AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text('$i',
                                    style: AppText.body().copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: i == difficulty ? Colors.white : AppColors.text,
                                    )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Rounds stepper.
            Row(
              children: <Widget>[
                Text('Rounds per session',
                    style: AppText.body().copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                _StepBtn(
                  icon: Icons.remove_rounded,
                  onTap: rounds > 1 ? () => _set('rounds', rounds - 1) : null,
                ),
                SizedBox(
                  width: 44,
                  child: Text('$rounds',
                      textAlign: TextAlign.center,
                      style: AppText.title().copyWith(fontSize: 22)),
                ),
                _StepBtn(
                  icon: Icons.add_rounded,
                  onTap: rounds < 10 ? () => _set('rounds', rounds + 1) : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return Material(
      color: on ? AppColors.primarySoft : AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon,
              size: 24, color: on ? AppColors.primary : AppColors.border),
        ),
      ),
    );
  }
}
