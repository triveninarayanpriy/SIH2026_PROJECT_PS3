import 'package:flutter/material.dart';

/// Root widget for CogniCare NER.
///
/// The concrete role (`patient` | `caregiver` | `doctor`) is supplied by the
/// role-specific entrypoint (`main_patient.dart`, `main_caregiver.dart`,
/// `main_doctor.dart`). For now the app only shows a placeholder screen that
/// centers the role name; feature UIs and Firebase wiring come later.
class CogniCareApp extends StatelessWidget {
  const CogniCareApp({super.key, required this.role});

  /// One of: `patient`, `caregiver`, `doctor`.
  final String role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CogniCare NER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: _RolePlaceholder(role: role),
    );
  }
}

class _RolePlaceholder extends StatelessWidget {
  const _RolePlaceholder({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final String label = role.isEmpty ? 'unknown' : role;
    return Scaffold(
      appBar: AppBar(title: const Text('CogniCare NER')),
      body: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
