import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_as.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_brx.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kha.dart';
import 'app_localizations_lus.dart';
import 'app_localizations_mni.dart';
import 'app_localizations_nag.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('as'),
    Locale('bn'),
    Locale('brx'),
    Locale('en'),
    Locale('hi'),
    Locale('kha'),
    Locale('lus'),
    Locale('mni'),
    Locale('nag'),
    Locale('ne'),
  ];

  /// Pattern game question
  ///
  /// In en, this message translates to:
  /// **'What comes next?'**
  String get whatComesNext;

  /// Family-face game question
  ///
  /// In en, this message translates to:
  /// **'Who is this?'**
  String get whoIsThis;

  /// Voice game question
  ///
  /// In en, this message translates to:
  /// **'Whose voice is this?'**
  String get whoseVoiceIsThis;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @relax.
  ///
  /// In en, this message translates to:
  /// **'Relax'**
  String get relax;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @again.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get again;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @veryGood.
  ///
  /// In en, this message translates to:
  /// **'Very good!'**
  String get veryGood;

  /// No description provided for @letsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Let\'s try again'**
  String get letsTryAgain;

  /// No description provided for @reminderMedicine.
  ///
  /// In en, this message translates to:
  /// **'Time for your medicine'**
  String get reminderMedicine;

  /// No description provided for @reminderHydration.
  ///
  /// In en, this message translates to:
  /// **'Please drink some water'**
  String get reminderHydration;

  /// No description provided for @reminderMeal.
  ///
  /// In en, this message translates to:
  /// **'Time to eat'**
  String get reminderMeal;

  /// No description provided for @reminderAppointment.
  ///
  /// In en, this message translates to:
  /// **'You have an appointment'**
  String get reminderAppointment;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get hello;

  /// No description provided for @gettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get gettingReady;

  /// No description provided for @activitiesForToday.
  ///
  /// In en, this message translates to:
  /// **'Activities for today'**
  String get activitiesForToday;

  /// No description provided for @descPattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern matching exercise'**
  String get descPattern;

  /// No description provided for @descFaces.
  ///
  /// In en, this message translates to:
  /// **'Face recognition game'**
  String get descFaces;

  /// No description provided for @descVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition exercise'**
  String get descVoice;

  /// No description provided for @gameCompleteName.
  ///
  /// In en, this message translates to:
  /// **'Complete the name'**
  String get gameCompleteName;

  /// No description provided for @descCompleteName.
  ///
  /// In en, this message translates to:
  /// **'Finish your family member\'s name'**
  String get descCompleteName;

  /// No description provided for @gameRemember.
  ///
  /// In en, this message translates to:
  /// **'Do you remember?'**
  String get gameRemember;

  /// No description provided for @descRemember.
  ///
  /// In en, this message translates to:
  /// **'Recall special life moments'**
  String get descRemember;

  /// No description provided for @descRoutine.
  ///
  /// In en, this message translates to:
  /// **'Put the daily routine in order'**
  String get descRoutine;

  /// No description provided for @gameDailyRoutine.
  ///
  /// In en, this message translates to:
  /// **'Daily routine'**
  String get gameDailyRoutine;

  /// No description provided for @gameWhatIsThis.
  ///
  /// In en, this message translates to:
  /// **'What is this?'**
  String get gameWhatIsThis;

  /// No description provided for @descObjects.
  ///
  /// In en, this message translates to:
  /// **'Name familiar objects'**
  String get descObjects;

  /// No description provided for @takeBreak.
  ///
  /// In en, this message translates to:
  /// **'Take a break and calm down'**
  String get takeBreak;

  /// No description provided for @answerByVoice.
  ///
  /// In en, this message translates to:
  /// **'Answer by voice'**
  String get answerByVoice;

  /// No description provided for @listeningLabel.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listeningLabel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @rewardWonderful.
  ///
  /// In en, this message translates to:
  /// **'Wonderful! You did it.'**
  String get rewardWonderful;

  /// No description provided for @rewardGreat.
  ///
  /// In en, this message translates to:
  /// **'Great effort. Well done!'**
  String get rewardGreat;

  /// No description provided for @rewardGood.
  ///
  /// In en, this message translates to:
  /// **'Good try. You finished the game!'**
  String get rewardGood;

  /// No description provided for @scoreOutOf.
  ///
  /// In en, this message translates to:
  /// **'You got {correct} out of {total}.'**
  String scoreOutOf(int correct, int total);

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @reminderItsTime.
  ///
  /// In en, this message translates to:
  /// **'It\'s time.'**
  String get reminderItsTime;

  /// No description provided for @calmTitle.
  ///
  /// In en, this message translates to:
  /// **'Relax & Unwind'**
  String get calmTitle;

  /// No description provided for @calmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a moment to feel at peace.'**
  String get calmSubtitle;

  /// No description provided for @breathingExercise.
  ///
  /// In en, this message translates to:
  /// **'Breathing Exercise'**
  String get breathingExercise;

  /// No description provided for @familyPhotos.
  ///
  /// In en, this message translates to:
  /// **'Family Photos'**
  String get familyPhotos;

  /// No description provided for @musicLabel.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get musicLabel;

  /// No description provided for @videosLabel.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videosLabel;

  /// No description provided for @inhale.
  ///
  /// In en, this message translates to:
  /// **'Inhale'**
  String get inhale;

  /// No description provided for @exhale.
  ///
  /// In en, this message translates to:
  /// **'Exhale'**
  String get exhale;

  /// No description provided for @breathe.
  ///
  /// In en, this message translates to:
  /// **'Breathe'**
  String get breathe;

  /// No description provided for @noPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos found.'**
  String get noPhotos;

  /// No description provided for @noMusic.
  ///
  /// In en, this message translates to:
  /// **'No music found.'**
  String get noMusic;

  /// No description provided for @noVideos.
  ///
  /// In en, this message translates to:
  /// **'No videos available.'**
  String get noVideos;

  /// No description provided for @completeNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Who is this? Complete the name.'**
  String get completeNamePrompt;

  /// No description provided for @listenAgainHint.
  ///
  /// In en, this message translates to:
  /// **'Take your time — listen again, then pick the matching answer.'**
  String get listenAgainHint;

  /// No description provided for @addFamilyPhotos.
  ///
  /// In en, this message translates to:
  /// **'Ask your family to add photos of family members.'**
  String get addFamilyPhotos;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rolePatient;

  /// No description provided for @roleCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get roleCaregiver;

  /// No description provided for @roleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get roleDoctor;

  /// No description provided for @rolePatientDesc.
  ///
  /// In en, this message translates to:
  /// **'Play games and exercises'**
  String get rolePatientDesc;

  /// No description provided for @roleCaregiverDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage care and track progress'**
  String get roleCaregiverDesc;

  /// No description provided for @roleDoctorDesc.
  ///
  /// In en, this message translates to:
  /// **'Monitor patients and reports'**
  String get roleDoctorDesc;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'A new life, built from old memories'**
  String get tagline;

  /// No description provided for @switchAnytime.
  ///
  /// In en, this message translates to:
  /// **'You can switch roles anytime'**
  String get switchAnytime;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'as',
    'bn',
    'brx',
    'en',
    'hi',
    'kha',
    'lus',
    'mni',
    'nag',
    'ne',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'as':
      return AppLocalizationsAs();
    case 'bn':
      return AppLocalizationsBn();
    case 'brx':
      return AppLocalizationsBrx();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kha':
      return AppLocalizationsKha();
    case 'lus':
      return AppLocalizationsLus();
    case 'mni':
      return AppLocalizationsMni();
    case 'nag':
      return AppLocalizationsNag();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
