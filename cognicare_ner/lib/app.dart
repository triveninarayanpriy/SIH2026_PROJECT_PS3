import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/services/local_db.dart';
import 'core/services/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/role_picker_screen.dart';
import 'core/widgets/theme_preview_screen.dart';
import 'features/caregiver/caregiver_gate.dart';
import 'features/doctor/doctor_gate.dart';
import 'features/patient/patient_gate.dart';
import 'l10n/app_localizations.dart';

/// Root widget for CogniCare NER.
///
/// Two modes:
///  * Locked per-role build (`roleSwitching == false`): branches on the
///    compile-time [role] into exactly one role's flow.
///  * Unified demo app (`roleSwitching == true`, via `main.dart`): role picker
///    + one-tap "Role" switch.
///
/// The active locale is driven by [LocaleController] (patient app sets it from
/// the patient's language; caregiver/doctor default to English).
class CogniCareApp extends StatelessWidget {
  const CogniCareApp({
    super.key,
    required this.role,
    this.roleSwitching = false,
  });

  final String role;
  final bool roleSwitching;

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.notifier,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'NAWAL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            // Fallbacks so locales the framework doesn't ship (e.g. Bodo,
            // Manipuri) still render Material/Cupertino chrome in English.
            const _FallbackMaterialLocalizationsDelegate(),
            const _FallbackCupertinoLocalizationsDelegate(),
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorKey: roleSwitching ? navKey : null,
          routes: {
            '/theme-preview': (_) => const ThemePreviewScreen(),
          },
          home:
              roleSwitching ? const _SwitchableHome() : _RoleGate(role: role),
          builder: roleSwitching
              ? (context, child) => Stack(
                    textDirection: TextDirection.ltr,
                    children: [
                      child ?? const SizedBox.shrink(),
                      const Positioned(
                        left: 12,
                        bottom: 12,
                        child: SafeArea(
                          child: ExcludeFocus(child: _SwitchRoleButton()),
                        ),
                      ),
                    ],
                  )
              : null,
        );
      },
    );
  }
}

class _SwitchableHome extends StatelessWidget {
  const _SwitchableHome();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: LocalDb.appStateBox
          .listenable(keys: const <String>[LocalDb.kActiveRole]),
      builder: (context, _, _) {
        final String? active = LocalDb.activeRole();
        if (active == null || active.isEmpty) {
          return const RolePickerScreen();
        }
        return _RoleGate(role: active);
      },
    );
  }
}

class _RoleGate extends StatelessWidget {
  const _RoleGate({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    if (role == 'caregiver' || role == 'doctor') {
      // Caregiver / doctor default to English unless explicitly set. (Patient
      // locale is set from the profile in the patient home.)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final saved = LocalDb.getSetting('app_locale') as String?;
        LocaleController.setLocale(saved != null ? Locale(saved) : const Locale('en'));
      });
    }
    switch (role) {
      case 'patient':
        return const PatientGate();
      case 'caregiver':
        return const CaregiverGate();
      case 'doctor':
        return const DoctorGate();
      default:
        return const _UnknownRole();
    }
  }
}

class _SwitchRoleButton extends StatelessWidget {
  const _SwitchRoleButton();

  void _switch() {
    CogniCareApp.navKey.currentState?.popUntil((route) => route.isFirst);
    LocalDb.clearActiveRole();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD11E2430),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _switch,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
              SizedBox(width: 6),
              Text(
                'Switch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownRole extends StatelessWidget {
  const _UnknownRole();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NAWAL')),
      body: const Padding(
        padding: EdgeInsets.all(AppTheme.screenPadding),
        child: Center(
          child: Text(
            'Unknown role.\nLaunch with '
            '--dart-define=ROLE=patient | caregiver | doctor, '
            'or run lib/main.dart for the role picker.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) =>
      false;
}

class _FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(
          covariant LocalizationsDelegate<CupertinoLocalizations> old) =>
      false;
}
