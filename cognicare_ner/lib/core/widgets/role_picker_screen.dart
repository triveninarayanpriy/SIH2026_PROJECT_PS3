import 'package:flutter/material.dart';

import '../../features/shared/language_selector_screen.dart';
import '../services/local_db.dart';
import '../services/locale_controller.dart';
import '../../l10n/app_localizations.dart';
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
    final AppLocalizations t = AppLocalizations.of(context);
    // Content is compact so it fits one screen without scrolling; the scroll
    // view is only a safety net for very short devices.
    return Scaffold(
      backgroundColor: AppColors.skyBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                child: NawalPage(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(alignment: Alignment.centerRight, child: _LanguagePill()),
                      SizedBox(height: wide ? 20 : 10),
                      Text(
                        'NAWAL',
                        textAlign: TextAlign.center,
                        style: AppText.title().copyWith(
                          fontSize: wide ? 76 : 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.inkDark,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'नवल',
                        textAlign: TextAlign.center,
                        style: AppText.title()
                            .copyWith(fontSize: wide ? 30 : 24, color: AppColors.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.tagline,
                        textAlign: TextAlign.center,
                        style: AppText.body().copyWith(
                          fontStyle: FontStyle.italic,
                          fontSize: wide ? 18 : 15,
                          color: AppColors.inkDark,
                        ),
                      ),
                      SizedBox(height: wide ? 36 : 24),
                      if (wide)
                        ResponsiveCardGrid(
                          columns: 3,
                          spacing: 20,
                          children: <Widget>[
                            NawalHeroCard(
                              icon: Icons.emoji_emotions_rounded,
                              title: t.rolePatient,
                              description: t.rolePatientDesc,
                              onTap: () => LocalDb.setActiveRole('patient'),
                            ),
                            NawalHeroCard(
                              icon: Icons.volunteer_activism_rounded,
                              title: t.roleCaregiver,
                              description: t.roleCaregiverDesc,
                              onTap: () => LocalDb.setActiveRole('caregiver'),
                            ),
                            NawalHeroCard(
                              icon: Icons.medical_services_rounded,
                              title: t.roleDoctor,
                              description: t.roleDoctorDesc,
                              onTap: () => LocalDb.setActiveRole('doctor'),
                            ),
                          ],
                        )
                      else ...<Widget>[
                        _RoleRow(
                          icon: Icons.emoji_emotions_rounded,
                          title: t.rolePatient,
                          description: t.rolePatientDesc,
                          onTap: () => LocalDb.setActiveRole('patient'),
                        ),
                        const SizedBox(height: 14),
                        _RoleRow(
                          icon: Icons.volunteer_activism_rounded,
                          title: t.roleCaregiver,
                          description: t.roleCaregiverDesc,
                          onTap: () => LocalDb.setActiveRole('caregiver'),
                        ),
                        const SizedBox(height: 14),
                        _RoleRow(
                          icon: Icons.medical_services_rounded,
                          title: t.roleDoctor,
                          description: t.roleDoctorDesc,
                          onTap: () => LocalDb.setActiveRole('doctor'),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        t.switchAnytime,
                        textAlign: TextAlign.center,
                        style: AppText.body(color: AppColors.inkDark).copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact role row for phones (icon box + title + description + chevron).
class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NawalCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.skyBg.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 34, color: AppColors.ink),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppText.title().copyWith(fontSize: 22, color: AppColors.text)),
                Text(description,
                    style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 14)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink, size: 30),
        ],
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
