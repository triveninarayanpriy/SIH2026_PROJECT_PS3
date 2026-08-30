import 'package:flutter/material.dart';
import '../../core/services/local_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_card.dart';

class CaregiverGameConfigScreen extends StatefulWidget {
  const CaregiverGameConfigScreen({Key? key}) : super(key: key);

  @override
  _CaregiverGameConfigScreenState createState() => _CaregiverGameConfigScreenState();
}

class _CaregiverGameConfigScreenState extends State<CaregiverGameConfigScreen> {
  
  Widget _buildGameConfigCard({
    required String title,
    required String gameKey,
    required IconData icon,
  }) {
    bool enabled = (LocalDb.getSetting('gameConfig_${gameKey}_enabled') as bool?) ?? true;
    int difficulty = (LocalDb.getSetting('gameConfig_${gameKey}_difficulty') as int?) ?? 1;
    int rounds = (LocalDb.getSetting('gameConfig_${gameKey}_rounds') as int?) ?? 3;

    return BigCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: AppTheme.iconSize, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(title, style: AppText.title().copyWith(color: AppColors.primary)),
                  ],
                ),
                Switch(
                  value: enabled,
                  activeColor: AppColors.success,
                  onChanged: (val) {
                    setState(() {
                      LocalDb.putSetting('gameConfig_${gameKey}_enabled', val);
                    });
                  },
                ),
              ],
            ),
            const Divider(height: 32, thickness: 1),
            Text('Difficulty: $difficulty', style: AppText.body()),
            Slider(
              value: difficulty.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: AppColors.secondary,
              onChanged: enabled ? (val) {
                setState(() {
                  LocalDb.putSetting('gameConfig_${gameKey}_difficulty', val.toInt());
                });
              } : null,
            ),
            const SizedBox(height: 16),
            Text('Rounds: $rounds', style: AppText.body()),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle, size: 40),
                  color: AppColors.primary,
                  onPressed: enabled && rounds > 1 ? () {
                    setState(() {
                      LocalDb.putSetting('gameConfig_${gameKey}_rounds', rounds - 1);
                    });
                  } : null,
                ),
                Text('$rounds', style: AppText.title()),
                IconButton(
                  icon: const Icon(Icons.add_circle, size: 40),
                  color: AppColors.primary,
                  onPressed: enabled && rounds < 10 ? () {
                    setState(() {
                      LocalDb.putSetting('gameConfig_${gameKey}_rounds', rounds + 1);
                    });
                  } : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 16),
            // Extra professional settings
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Adaptive Difficulty', style: AppText.body().copyWith(fontSize: 18)),
              subtitle: Text('Auto-adjust based on performance', style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 14)),
              value: (LocalDb.getSetting('gameConfig_${gameKey}_adaptive') as bool?) ?? true,
              activeColor: AppColors.primary,
              onChanged: enabled ? (val) {
                setState(() => LocalDb.putSetting('gameConfig_${gameKey}_adaptive', val));
              } : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Show Visual Hints', style: AppText.body().copyWith(fontSize: 18)),
              subtitle: Text('Highlight correct answers after delay', style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 14)),
              value: (LocalDb.getSetting('gameConfig_${gameKey}_hints') as bool?) ?? false,
              activeColor: AppColors.primary,
              onChanged: enabled ? (val) {
                setState(() => LocalDb.putSetting('gameConfig_${gameKey}_hints', val));
              } : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Replay Question', style: AppText.body().copyWith(fontSize: 18)),
              subtitle: Text('Repeat audio prompt on wrong answer', style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 14)),
              value: (LocalDb.getSetting('gameConfig_${gameKey}_replay') as bool?) ?? true,
              activeColor: AppColors.primary,
              onChanged: enabled ? (val) {
                setState(() => LocalDb.putSetting('gameConfig_${gameKey}_replay', val));
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          Text('Customize Brain Games', style: AppText.title()),
          const SizedBox(height: 8),
          Text('Adjust the difficulty and number of rounds based on the patient\'s cognitive abilities.', style: AppText.body()),
          const SizedBox(height: 24),
          
          _buildGameConfigCard(
            title: 'Pattern Match',
            gameKey: 'pattern',
            icon: Icons.grid_view,
          ),
          const SizedBox(height: 16),
          
          _buildGameConfigCard(
            title: 'Family Faces',
            gameKey: 'familyFaces',
            icon: Icons.face,
          ),
          const SizedBox(height: 16),
          
          _buildGameConfigCard(
            title: 'Voice Recognition',
            gameKey: 'voice',
            icon: Icons.record_voice_over,
          ),
        ],
      ),
    );
  }
}
