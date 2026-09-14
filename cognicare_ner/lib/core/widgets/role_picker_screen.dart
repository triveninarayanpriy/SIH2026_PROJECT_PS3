import 'package:flutter/material.dart';

import '../../features/shared/language_selector_screen.dart';
import '../services/local_db.dart';
import '../services/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'nawal_ui.dart';

/// Launch role picker for the unified demo app.
///
/// Choosing a role stores it in [LocalDb.setActiveRole]; the app then rebuilds
/// into that role's flow. The bottom "Switch" button returns here.
class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool wide = AppTheme.isWide(context);
    return Scaffold(
      backgroundColor: AppColors.skyBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding, vertical: 12),
          child: NawalPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: _LanguagePill(),
                ),
                SizedBox(height: wide ? 24 : 8),
                Text(
                  'NAWAL',
                  textAlign: TextAlign.center,
                  style: AppText.title().copyWith(
                    fontSize: wide ? 84 : 60,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.inkDark,
                  ),
                ),
                Text(
                  'नवल',
                  textAlign: TextAlign.center,
                  style: AppText.title().copyWith(fontSize: wide ? 34 : 28, color: AppColors.ink),
                ),
                const SizedBox(height: 10),
                Text(
                  'A new life, built from old memories',
                  textAlign: TextAlign.center,
                  style: AppText.body().copyWith(
                    fontStyle: FontStyle.italic,
                    fontSize: wide ? 20 : 17,
                    color: AppColors.inkDark,
                  ),
                ),
                SizedBox(height: wide ? 48 : 32),
                ResponsiveCardGrid(
                  columns: 3,
                  spacing: 20,
                  children: <Widget>[
                    NawalHeroCard(
                      icon: Icons.emoji_emotions_rounded,
                      title: 'Patient',
                      description: 'Play games and exercises',
                      onTap: () => LocalDb.setActiveRole('patient'),
                    ),
                    NawalHeroCard(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Caregiver',
                      description: 'Manage care and track progress',
                      onTap: () => LocalDb.setActiveRole('caregiver'),
                    ),
                    NawalHeroCard(
                      icon: Icons.medical_services_rounded,
                      title: 'Doctor',
                      description: 'Monitor patients and reports',
                      onTap: () => LocalDb.setActiveRole('doctor'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'You can switch roles anytime',
                  textAlign: TextAlign.center,
                  style: AppText.body(color: AppColors.inkDark),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Language chooser on the landing page. Sets the app-wide locale so the
/// patient, caregiver, and doctor views all follow it.
class _LanguagePill extends StatelessWidget {
  String get _current {
    final String code = (LocalDb.getSetting('app_locale') as String?) ?? 'en';
    for (final Map<String, String> l in LocaleController.supportedLanguages) {
      if (l['code'] == code) return l['nativeName'] ?? l['name'] ?? 'English';
    }
    return 'English';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LanguageSelectorScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.language_rounded, color: AppColors.ink, size: 22),
              const SizedBox(width: 8),
              Text(_current,
                  style: AppText.body().copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
