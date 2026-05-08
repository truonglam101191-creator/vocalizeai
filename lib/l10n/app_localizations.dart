import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

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
    Locale('vi')
  ];

  /// No description provided for @offlineMediaPipeline.
  ///
  /// In en, this message translates to:
  /// **'Offline Media Pipeline'**
  String get offlineMediaPipeline;

  /// No description provided for @stopAiServer.
  ///
  /// In en, this message translates to:
  /// **'Stop AI Server'**
  String get stopAiServer;

  /// No description provided for @resetAiServer.
  ///
  /// In en, this message translates to:
  /// **'Reset AI Server'**
  String get resetAiServer;

  /// No description provided for @startingAiEngine.
  ///
  /// In en, this message translates to:
  /// **'Starting AI Engine...'**
  String get startingAiEngine;

  /// No description provided for @tabStt.
  ///
  /// In en, this message translates to:
  /// **'STT'**
  String get tabStt;

  /// No description provided for @tabTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get tabTranslate;

  /// No description provided for @tabTts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get tabTts;

  /// No description provided for @dropAudio.
  ///
  /// In en, this message translates to:
  /// **'Drop audio here or click to browse'**
  String get dropAudio;

  /// No description provided for @extractTextStt.
  ///
  /// In en, this message translates to:
  /// **'Extract Text (STT)'**
  String get extractTextStt;

  /// No description provided for @subtitlesSrt.
  ///
  /// In en, this message translates to:
  /// **'Subtitles (SRT)'**
  String get subtitlesSrt;

  /// No description provided for @copySubtitles.
  ///
  /// In en, this message translates to:
  /// **'Copy subtitles'**
  String get copySubtitles;

  /// No description provided for @subtitlesCopied.
  ///
  /// In en, this message translates to:
  /// **'Subtitles copied to clipboard!'**
  String get subtitlesCopied;

  /// No description provided for @sendToTranslate.
  ///
  /// In en, this message translates to:
  /// **'Send to Translate'**
  String get sendToTranslate;

  /// No description provided for @pasteSrtToTranslate.
  ///
  /// In en, this message translates to:
  /// **'Paste SRT or text to translate here...'**
  String get pasteSrtToTranslate;

  /// No description provided for @loadFromFile.
  ///
  /// In en, this message translates to:
  /// **'Load from file'**
  String get loadFromFile;

  /// No description provided for @translateText.
  ///
  /// In en, this message translates to:
  /// **'Translate Text'**
  String get translateText;

  /// No description provided for @translatedContent.
  ///
  /// In en, this message translates to:
  /// **'Translated Content'**
  String get translatedContent;

  /// No description provided for @copyTranslation.
  ///
  /// In en, this message translates to:
  /// **'Copy translation'**
  String get copyTranslation;

  /// No description provided for @translationCopied.
  ///
  /// In en, this message translates to:
  /// **'Translation copied!'**
  String get translationCopied;

  /// No description provided for @savedTranslations.
  ///
  /// In en, this message translates to:
  /// **'Saved Translations'**
  String get savedTranslations;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// No description provided for @copyFilePath.
  ///
  /// In en, this message translates to:
  /// **'Copy file path'**
  String get copyFilePath;

  /// No description provided for @pathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied!'**
  String get pathCopied;

  /// No description provided for @sendToTts.
  ///
  /// In en, this message translates to:
  /// **'Send to TTS'**
  String get sendToTts;

  /// No description provided for @pasteTranslatedSrt.
  ///
  /// In en, this message translates to:
  /// **'Paste translated SRT or plain text here...'**
  String get pasteTranslatedSrt;

  /// No description provided for @clearContent.
  ///
  /// In en, this message translates to:
  /// **'Clear content'**
  String get clearContent;

  /// No description provided for @generateAudioTts.
  ///
  /// In en, this message translates to:
  /// **'Generate Audio (TTS)'**
  String get generateAudioTts;

  /// No description provided for @studioAudioReady.
  ///
  /// In en, this message translates to:
  /// **'Studio Audio Ready'**
  String get studioAudioReady;

  /// No description provided for @generatedAudios.
  ///
  /// In en, this message translates to:
  /// **'Generated Audios'**
  String get generatedAudios;

  /// No description provided for @copyContent.
  ///
  /// In en, this message translates to:
  /// **'Copy content'**
  String get copyContent;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard!'**
  String get copiedToClipboard;

  /// No description provided for @modelManager.
  ///
  /// In en, this message translates to:
  /// **'Model Manager'**
  String get modelManager;

  /// No description provided for @whisperStt.
  ///
  /// In en, this message translates to:
  /// **'Whisper (STT)'**
  String get whisperStt;

  /// No description provided for @piperTts.
  ///
  /// In en, this message translates to:
  /// **'Piper (TTS)'**
  String get piperTts;

  /// No description provided for @noModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models available'**
  String get noModelsAvailable;

  /// No description provided for @multilingual.
  ///
  /// In en, this message translates to:
  /// **'Multilingual'**
  String get multilingual;

  /// No description provided for @deleteModelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Model'**
  String get deleteModelTooltip;

  /// No description provided for @deleteModelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Model'**
  String get deleteModelConfirmTitle;

  /// No description provided for @deleteModelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {modelName}?'**
  String deleteModelConfirmBody(String modelName);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch Language'**
  String get switchLanguage;
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
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
