import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/widgets/email_auth_screen.dart';
import '../../core/widgets/loading_view.dart';
import 'doctor_patient_list.dart';

/// Doctor entry flow: email/password auth, then the patient list.
class DoctorGate extends StatelessWidget {
  const DoctorGate({super.key});

  @override
  Widget build(BuildContext context) {
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
            title: 'Doctor sign in',
            subtitle: 'Sign in to view your patients.',
          );
        }
        return DoctorPatientList(uid: user.uid);
      },
    );
  }
}
