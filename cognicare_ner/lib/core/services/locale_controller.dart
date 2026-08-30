import 'package:flutter/widgets.dart';

import 'local_db.dart';
import 'tts_service.dart';

/// Holds the active app locale (reactive) and keeps the TTS locale in sync.
///
/// The patient app sets it from the patient's chosen language
/// (PatientProfile.languages first entry); caregiver/doctor default to English.
class LocaleController {
  LocaleController._();

  static final ValueNotifier<Locale?> notifier = ValueNotifier<Locale?>(null);

  static void init() {
    final String? code = LocalDb.getSetting('app_locale') as String?;
    if (code != null) {
      setLocale(Locale(code));
    }
  }

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

  /// All supported NER language names and their codes — used by caregiver UI
  /// for language selection dropdowns.
  static const List<Map<String, String>> supportedLanguages = <Map<String, String>>[
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
    {'code': 'as', 'name': 'Assamese', 'nativeName': 'অসমীয়া'},
    {'code': 'bn', 'name': 'Bengali', 'nativeName': 'বাংলা'},
    {'code': 'brx', 'name': 'Bodo', 'nativeName': 'बड़ो'},
    {'code': 'mni', 'name': 'Manipuri', 'nativeName': 'মৈতৈলোন্'},
    {'code': 'ne', 'name': 'Nepali', 'nativeName': 'नेपाली'},
    {'code': 'lus', 'name': 'Mizo', 'nativeName': 'Mizo ṭawng'},
    {'code': 'kha', 'name': 'Khasi', 'nativeName': 'Ka Ktien Khasi'},
    {'code': 'nag', 'name': 'Nagamese', 'nativeName': 'Nagamese'},
  ];

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
      case 'ne':
      case 'nepali':
        return 'ne';
      case 'lus':
      case 'mizo':
      case 'lushai':
        return 'lus';
      case 'kha':
      case 'khasi':
        return 'kha';
      case 'nag':
      case 'nagamese':
      case 'naga':
        return 'nag';
      default:
        return null;
    }
  }

  /// TTS engine locale for a language code (closest available; Bodo/Meitei/Mizo
  /// use the nearest script's voice when no native TTS exists).
  static String _ttsLocaleFor(String? code) {
    switch (code) {
      case 'hi':
        return 'hi-IN';
      case 'bn':
        return 'bn-IN';
      case 'as':
        return 'as-IN';
      case 'ne':
        return 'ne-NP';
      case 'brx':
        return 'hi-IN'; // Bodo: closest available TTS
      case 'mni':
        return 'bn-IN'; // Manipuri: closest available TTS
      case 'lus':
        return 'en-IN'; // Mizo: no native TTS, use English
      case 'kha':
        return 'en-IN'; // Khasi: no native TTS, use English
      case 'nag':
        return 'en-IN'; // Nagamese: no native TTS, use English
      case 'en':
      default:
        return 'en-IN';
    }
  }
}
