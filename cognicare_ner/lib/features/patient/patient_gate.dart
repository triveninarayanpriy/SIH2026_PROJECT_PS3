import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/local_db.dart';
import '../../core/widgets/loading_view.dart';

import 'patient_setup_screen.dart';
import 'welcome_screen.dart';

/// Patient entry flow: ensure anonymous sign-in, then route to the Patient Home
/// if this device is paired, otherwise to the pairing screen. No login UI.
class PatientGate extends StatefulWidget {
  const PatientGate({super.key});

  @override
  State<PatientGate> createState() => _PatientGateState();
}

class _PatientGateState extends State<PatientGate> {
  final AuthService _auth = AuthService();
  late final Future<void> _signIn;

  @override
  void initState() {
    super.initState();
    _signIn = _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
    } catch (_) {
      // Anonymous auth may be disabled or offline — the patient still works
      // fully from the local store.
    }
  }

  /// A patient id already present on this device (caregiver-created), or null.
  /// Persists it as the linked id so the link survives restarts.
  String? _autoLinkId() {
    String? candidate = LocalDb.caregiverPatientId();
    if (candidate == null) {
      final profiles = LocalDb.allProfiles();
      if (profiles.length == 1) candidate = profiles.first.id;
    }
    if (candidate != null) {
      LocalDb.setLinkedPatientId(candidate);
    }
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _signIn,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        return ValueListenableBuilder<Box<dynamic>>(
          valueListenable: LocalDb.appStateBox
              .listenable(keys: const <String>[LocalDb.kLinkedPatientId]),
          builder: (context, _, _) {
            String? patientId = LocalDb.linkedPatientId();
            // Same-device auto-link: if this device already has the patient's
            // profile (e.g. the caregiver set it up here), link automatically so
            // no pairing code needs to be typed. A second, separate device has
            // no local profile, so it still shows the pairing screen.
            patientId ??= _autoLinkId();
            if (patientId == null) return const PatientSetupScreen();
            return WelcomeScreen(patientId: patientId);
          },
        );
      },
    );
  }
}
