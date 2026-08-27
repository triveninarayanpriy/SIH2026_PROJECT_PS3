import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/theme_preview_screen.dart';
import 'features/caregiver/caregiver_gate.dart';
import 'features/doctor/doctor_gate.dart';
import 'features/patient/patient_gate.dart';

/// Root widget for CogniCare NER.
///
/// Branches on the compile-time [role] into exactly one role's flow. Because
/// ROLE is a `--dart-define`, a given build only ever contains one role's
/// screens — a role cannot navigate into another role's UI (route guard by
/// construction). The only extra route is the debug theme preview.
class CogniCareApp extends StatelessWidget {
  const CogniCareApp({super.key, required this.role});

  /// One of: `patient`, `caregiver`, `doctor`.
  final String role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CogniCare NER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routes: {
        '/theme-preview': (_) => const ThemePreviewScreen(),
      },
      home: _RoleGate(role: role),
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
            '--dart-define=ROLE=patient | caregiver | doctor.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
