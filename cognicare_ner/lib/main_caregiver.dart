import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/local_db.dart';
import 'core/services/sync_service.dart';
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
  await LocalDb.init();
  // Fire-and-forget: background offline-first sync, never blocks startup.
  SyncService.instance.init();

  const String role = String.fromEnvironment('ROLE', defaultValue: 'caregiver');
  runApp(const CogniCareApp(role: role));
}
