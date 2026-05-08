// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get offlineMediaPipeline => 'Offline Media Pipeline';

  @override
  String get stopAiServer => 'Stop AI Server';

  @override
  String get resetAiServer => 'Reset AI Server';

  @override
  String get startingAiEngine => 'Starting AI Engine...';

  @override
  String get tabStt => 'STT';

  @override
  String get tabTranslate => 'Translate';

  @override
  String get tabTts => 'TTS';

  @override
  String get dropAudio => 'Drop audio here or click to browse';

  @override
  String get extractTextStt => 'Extract Text (STT)';

  @override
  String get subtitlesSrt => 'Subtitles (SRT)';

  @override
  String get copySubtitles => 'Copy subtitles';

  @override
  String get subtitlesCopied => 'Subtitles copied to clipboard!';

  @override
  String get sendToTranslate => 'Send to Translate';

  @override
  String get pasteSrtToTranslate => 'Paste SRT or text to translate here...';

  @override
  String get loadFromFile => 'Load from file';

  @override
  String get translateText => 'Translate Text';

  @override
  String get translatedContent => 'Translated Content';

  @override
  String get copyTranslation => 'Copy translation';

  @override
  String get translationCopied => 'Translation copied!';

  @override
  String get savedTranslations => 'Saved Translations';

  @override
  String get openFolder => 'Open folder';

  @override
  String get copyFilePath => 'Copy file path';

  @override
  String get pathCopied => 'Path copied!';

  @override
  String get sendToTts => 'Send to TTS';

  @override
  String get pasteTranslatedSrt => 'Paste translated SRT or plain text here...';

  @override
  String get clearContent => 'Clear content';

  @override
  String get generateAudioTts => 'Generate Audio (TTS)';

  @override
  String get studioAudioReady => 'Studio Audio Ready';

  @override
  String get generatedAudios => 'Generated Audios';

  @override
  String get copyContent => 'Copy content';

  @override
  String get copiedToClipboard => 'Copied to clipboard!';

  @override
  String get modelManager => 'Model Manager';

  @override
  String get whisperStt => 'Whisper (STT)';

  @override
  String get piperTts => 'Piper (TTS)';

  @override
  String get noModelsAvailable => 'No models available';

  @override
  String get multilingual => 'Multilingual';

  @override
  String get deleteModelTooltip => 'Delete Model';

  @override
  String get deleteModelConfirmTitle => 'Delete Model';

  @override
  String deleteModelConfirmBody(String modelName) {
    return 'Are you sure you want to delete $modelName?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get download => 'Download';

  @override
  String get switchLanguage => 'Switch Language';
}
