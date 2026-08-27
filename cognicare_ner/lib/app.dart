import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/services/local_db.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/role_picker_screen.dart';
import 'core/widgets/theme_preview_screen.dart';
import 'features/caregiver/caregiver_gate.dart';
import 'features/doctor/doctor_gate.dart';
import 'features/patient/patient_gate.dart';

/// Root widget for CogniCare NER.
///
/// Two modes:
///  * Locked per-role build (`roleSwitching == false`): branches on the
///    compile-time [role] into exactly one role's flow. A build only ever
///    contains one role's screens (route guard by construction).
///  * Unified demo app (`roleSwitching == true`, via `main.dart`): shows a role
///    picker, remembers the choice, and offers a one-tap "Role" switch — so a
///    single device/app can move between caregiver and patient views.
class CogniCareApp extends StatelessWidget {
  const CogniCareApp({
    super.key,
    required this.role,
    this.roleSwitching = false,
  });

  /// Compile-time role for locked builds; ignored in role-switching mode.
  final String role;

  /// When true, runs the unified demo app (picker + in-app switch).
  final bool roleSwitching;

  /// Navigator key used by the role switch to pop back to the home route.
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CogniCare NER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: roleSwitching ? navKey : null,
      routes: {
        '/theme-preview': (_) => const ThemePreviewScreen(),
      },
      home: roleSwitching ? const _SwitchableHome() : _RoleGate(role: role),
      builder: roleSwitching
          ? (context, child) => Stack(
                textDirection: TextDirection.ltr,
                children: [
                  // Non-positioned child so the Stack takes the app's size.
                  child ?? const SizedBox.shrink(),
                  // ExcludeFocus keeps this out-of-Navigator button out of the
                  // view's focus traversal, which otherwise asserts on Flutter
                  // web when the browser focuses the view before first layout.
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
  }
}

/// Reads the runtime-selected role and shows the picker or the matching gate.
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

/// Small always-on-top "Role" switch, shown only in the unified demo app.
class _SwitchRoleButton extends StatelessWidget {
  const _SwitchRoleButton();

  void _switch() {
    // Return to the home route, then drop the active role -> role picker.
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
                'Role',
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
      appBar: AppBar(title: const Text('CogniCare NER')),
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
