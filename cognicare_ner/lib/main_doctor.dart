import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/services/demo_seeder.dart';
import 'core/services/local_db.dart';
import 'core/services/sync_service.dart';
import 'firebase_options.dart';

/// Doctor entrypoint.
///
/// Reads the role from `--dart-define=ROLE=...`, defaulting to `doctor` when
/// no ROLE is supplied so this entrypoint always launches the doctor app.
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
  // Optional AI keys (Tier 2); missing .env is fine.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  // Fire-and-forget: background offline-first sync, never blocks startup.
  SyncService.instance.init();
  await DemoSeeder.maybeLoadFromEnvironment();

  const String role = String.fromEnvironment('ROLE', defaultValue: 'doctor');
  runApp(const CogniCareApp(role: role));
}
