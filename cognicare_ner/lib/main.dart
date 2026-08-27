import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/services/local_db.dart';
import 'core/services/sync_service.dart';
import 'firebase_options.dart';

/// Unified demo entrypoint.
///
/// Runs the app with the in-app role picker + one-tap "Role" switch, so a
/// single device/app can move between patient, caregiver, and doctor views
/// (all sharing the same local store). For locked, per-role production builds
/// use main_patient.dart / main_caregiver.dart / main_doctor.dart instead.
void main() async {
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
  // Target whichever patient this device already knows about.
  SyncService.instance.init(
    patientId: LocalDb.linkedPatientId() ?? LocalDb.caregiverPatientId(),
  );

  runApp(const CogniCareApp(role: '', roleSwitching: true));
}
