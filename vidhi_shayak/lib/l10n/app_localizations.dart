import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'VidhiShayak'**
  String get appTitle;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Your AI Legal Friend'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Get instant help for legal, study, or AI support needs.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Mode'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Select your category and chat instantly with the right assistant.'**
  String get onboardingDesc2;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language & Region'**
  String get selectLanguage;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @categoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get categoryTitle;

  /// No description provided for @categoryHeader.
  ///
  /// In en, this message translates to:
  /// **'How can we help you today?'**
  String get categoryHeader;

  /// No description provided for @categorySubheader.
  ///
  /// In en, this message translates to:
  /// **'Choose the option that best describes your needs.'**
  String get categorySubheader;

  /// No description provided for @catStudy.
  ///
  /// In en, this message translates to:
  /// **'I need a study companion'**
  String get catStudy;

  /// No description provided for @catLawyer.
  ///
  /// In en, this message translates to:
  /// **'I need a lawyer (Vidhi Sahayak)'**
  String get catLawyer;

  /// No description provided for @catLegal.
  ///
  /// In en, this message translates to:
  /// **'I need legal guidance'**
  String get catLegal;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'AI Friend (Personal Advisor)'**
  String get catOther;

  /// No description provided for @lblStudy.
  ///
  /// In en, this message translates to:
  /// **'Study Companion'**
  String get lblStudy;

  /// No description provided for @lblLawyer.
  ///
  /// In en, this message translates to:
  /// **'Lawyer'**
  String get lblLawyer;

  /// No description provided for @lblLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal Guidance'**
  String get lblLegal;

  /// No description provided for @lblOther.
  ///
  /// In en, this message translates to:
  /// **'AI Friend'**
  String get lblOther;

  /// No description provided for @errSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get errSelectCategory;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navHiring.
  ///
  /// In en, this message translates to:
  /// **'Hiring'**
  String get navHiring;

  /// No description provided for @voiceSelectLang.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get voiceSelectLang;

  /// No description provided for @voiceMicPerm.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to use voice chat.'**
  String get voiceMicPerm;

  /// No description provided for @voiceReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get voiceReconnecting;

  /// No description provided for @voiceNetError.
  ///
  /// In en, this message translates to:
  /// **'Network Error: Check your connection.'**
  String get voiceNetError;

  /// No description provided for @voiceNoMatch.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t catch that. Try again.'**
  String get voiceNoMatch;

  /// No description provided for @voiceRecovering.
  ///
  /// In en, this message translates to:
  /// **'Recovering voice session...'**
  String get voiceRecovering;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get voiceListening;

  /// No description provided for @voiceThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get voiceThinking;

  /// No description provided for @voiceProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get voiceProcessing;

  /// No description provided for @voiceSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking...'**
  String get voiceSpeaking;

  /// No description provided for @voiceTapSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to Speak'**
  String get voiceTapSpeak;

  /// No description provided for @voiceOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'OPEN SETTINGS'**
  String get voiceOpenSettings;

  /// No description provided for @voiceTapFinish.
  ///
  /// In en, this message translates to:
  /// **'TAP TO FINISH'**
  String get voiceTapFinish;

  /// No description provided for @voiceRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get voiceRetry;

  /// No description provided for @voiceInit.
  ///
  /// In en, this message translates to:
  /// **'INITIALIZING...'**
  String get voiceInit;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get chatTypeMessage;

  /// No description provided for @chatMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get chatMenu;

  /// No description provided for @chatProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get chatProfile;

  /// No description provided for @chatSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get chatSettings;

  /// No description provided for @chatLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get chatLogout;

  /// No description provided for @chatLoginGoogle.
  ///
  /// In en, this message translates to:
  /// **'Login with Google'**
  String get chatLoginGoogle;

  /// No description provided for @chatDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get chatDarkMode;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @chatGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get chatGuest;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your legal journey'**
  String get loginSubtitle;

  /// No description provided for @loginGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginGoogle;

  /// No description provided for @loginTerms.
  ///
  /// In en, this message translates to:
  /// **'By signing in, you agree to our Terms & Privacy Policy.'**
  String get loginTerms;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: '**
  String get loginFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
