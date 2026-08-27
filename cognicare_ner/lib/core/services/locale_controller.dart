import 'package:flutter/widgets.dart';

import 'tts_service.dart';

/// Holds the active app locale (reactive) and keeps the TTS locale in sync.
///
/// The patient app sets it from the patient's chosen language
/// (PatientProfile.languages first entry); caregiver/doctor default to English.
class LocaleController {
  LocaleController._();

  static final ValueNotifier<Locale?> notifier = ValueNotifier<Locale?>(null);

  static void setLocale(Locale? locale) {
    if (notifier.value?.languageCode == locale?.languageCode) return;
    notifier.value = locale;
    TtsService.instance.setLocale(_ttsLocaleFor(locale?.languageCode));
  }

  /// Sets the locale from a patient's languages list (first recognised entry).
  static void setFromLanguages(List<String> languages) {
    for (final String l in languages) {
      final String? code = _codeFor(l);
      if (code != null) {
        setLocale(Locale(code));
        return;
      }
    }
    setLocale(const Locale('en'));
  }

  /// Maps a language name or code to a supported locale code.
  static String? _codeFor(String name) {
    switch (name.trim().toLowerCase()) {
      case 'en':
      case 'english':
        return 'en';
      case 'hi':
      case 'hindi':
        return 'hi';
      case 'as':
      case 'assamese':
        return 'as';
      case 'bn':
      case 'bengali':
      case 'bangla':
        return 'bn';
      case 'brx':
      case 'bodo':
      case 'boro':
        return 'brx';
      case 'mni':
      case 'manipuri':
      case 'meitei':
      case 'meiteilon':
        return 'mni';
      default:
        return null;
    }
  }

  /// TTS engine locale for a language code (closest available; Bodo/Meitei use
  /// the nearest script's voice).
  static String _ttsLocaleFor(String? code) {
    switch (code) {
      case 'hi':
        return 'hi-IN';
      case 'bn':
        return 'bn-IN';
      case 'as':
        return 'as-IN';
      case 'brx':
        return 'hi-IN';
      case 'mni':
        return 'bn-IN';
      case 'en':
      default:
        return 'en-IN';
    }
  }
}
