import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/demo_mode.dart';
import '../../core/services/local_db.dart';
import '../../core/widgets/email_auth_screen.dart';
import '../../core/widgets/loading_view.dart';
import 'add_patient_screen.dart';
import 'caregiver_home.dart';

/// Caregiver entry flow: email/password auth, then "Add patient" onboarding if
/// no patient is linked yet, otherwise the Caregiver Home. In demo mode, auth is
/// bypassed so screens are screenshot-ready.
class CaregiverGate extends StatelessWidget {
  const CaregiverGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DemoMode.notifier,
      builder: (context, _, _) {
        if (DemoMode.isEnabled) {
          return CaregiverHome(
            patientId: LocalDb.caregiverPatientId() ?? DemoMode.patientId,
          );
        }
        final AuthService auth = AuthService();
        return StreamBuilder<User?>(
          stream: auth.authStateChanges(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                auth.currentUser == null) {
              return const LoadingView();
            }
            final User? user = snap.data ?? auth.currentUser;
            if (user == null || user.isAnonymous) {
              return const EmailAuthScreen(
                title: 'Caregiver sign in',
                subtitle:
                    'Sign in or create an account to set up and monitor your patient.',
              );
            }
            return ValueListenableBuilder<Box<dynamic>>(
              valueListenable: LocalDb.appStateBox
                  .listenable(keys: const <String>[LocalDb.kCaregiverPatientId]),
              builder: (context, _, _) {
                final String? patientId = LocalDb.caregiverPatientId();
                if (patientId == null) return const AddPatientScreen();
                return CaregiverHome(patientId: patientId);
              },
            );
          },
        );
      },
    );
  }
}
