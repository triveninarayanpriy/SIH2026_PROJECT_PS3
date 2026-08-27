import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

/// Caregiver entrypoint.
///
/// Reads the role from `--dart-define=ROLE=...`, defaulting to `caregiver` when
/// no ROLE is supplied so this entrypoint always launches the caregiver app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  const String role = String.fromEnvironment('ROLE', defaultValue: 'caregiver');
  runApp(const CogniCareApp(role: role));
}
