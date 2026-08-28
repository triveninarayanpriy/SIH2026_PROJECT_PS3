import 'package:flutter/foundation.dart';

import 'local_db.dart';

/// Debug/demo flag. When enabled, the caregiver/doctor gates skip real auth so
/// every screen is screenshot-ready without a live Firebase login. Never set in
/// a real build (only via `--dart-define=DEMO=true` or the hidden long-press).
class DemoMode {
  DemoMode._();

  static bool _enabled = false;

  /// Flips true when demo mode turns on, so the role gates can rebuild.
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);

  static bool get isEnabled =>
      _enabled || (LocalDb.getSetting('demoMode') == true);

  static Future<void> enable() async {
    _enabled = true;
    await LocalDb.putSetting('demoMode', true);
    notifier.value = true;
  }

  /// Fixed ids so re-seeding overwrites rather than piling up.
  static const String patientId = 'DEMO01';
  static const String doctorUid = 'demo-doctor';
}
