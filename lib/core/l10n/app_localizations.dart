import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'offlineMediaPipeline': 'Offline Media Pipeline',
      'stopAiServer': 'Stop AI Server',
      'resetAiServer': 'Reset AI Server',
      'startingAiEngine': 'Starting AI Engine...',
      'tabStt': 'STT',
      'tabTranslate': 'Translate',
      'tabTts': 'TTS',
      'dropAudio': 'Drop audio here or click to browse',
      'extractTextStt': 'Extract Text (STT)',
      'subtitlesSrt': 'Subtitles (SRT)',
      'copySubtitles': 'Copy subtitles',
      'subtitlesCopied': 'Subtitles copied to clipboard!',
      'sendToTranslate': 'Send to Translate',
      'pasteSrtToTranslate': 'Paste SRT or text to translate here...',
      'loadFromFile': 'Load from file',
      'translateText': 'Translate Text',
      'translatedContent': 'Translated Content',
      'copyTranslation': 'Copy translation',
      'translationCopied': 'Translation copied!',
      'savedTranslations': 'Saved Translations',
      'openFolder': 'Open folder',
      'copyFilePath': 'Copy file path',
      'pathCopied': 'Path copied!',
      'sendToTts': 'Send to TTS',
      'pasteTranslatedSrt': 'Paste translated SRT or plain text here...',
      'clearContent': 'Clear content',
      'generateAudioTts': 'Generate Audio (TTS)',
      'studioAudioReady': 'Studio Audio Ready',
      'generatedAudios': 'Generated Audios',
      'copyContent': 'Copy content',
      'copiedToClipboard': 'Copied to clipboard!',
      'switchLanguage': 'Switch Language (EN/VI)'
    },
    'vi': {
      'offlineMediaPipeline': 'Xử lý Truyền thông Ngoại tuyến',
      'stopAiServer': 'Dừng Máy chủ AI',
      'resetAiServer': 'Khởi động lại AI',
      'startingAiEngine': 'Đang khởi động AI...',
      'tabStt': 'STT (Giọng nói)',
      'tabTranslate': 'Dịch thuật',
      'tabTts': 'TTS (Âm thanh)',
      'dropAudio': 'Kéo thả âm thanh vào đây hoặc nhấp để tải',
      'extractTextStt': 'Trích xuất Văn bản',
      'subtitlesSrt': 'Phụ đề (SRT)',
      'copySubtitles': 'Sao chép phụ đề',
      'subtitlesCopied': 'Đã sao chép phụ đề!',
      'sendToTranslate': 'Gửi tới Dịch thuật',
      'pasteSrtToTranslate': 'Dán phụ đề SRT hoặc văn bản cần dịch...',
      'loadFromFile': 'Tải từ file',
      'translateText': 'Dịch Văn bản',
      'translatedContent': 'Nội dung đã dịch',
      'copyTranslation': 'Sao chép bản dịch',
      'translationCopied': 'Đã sao chép bản dịch!',
      'savedTranslations': 'Bản dịch đã lưu',
      'openFolder': 'Mở thư mục',
      'copyFilePath': 'Sao chép đường dẫn',
      'pathCopied': 'Đã sao chép đường dẫn!',
      'sendToTts': 'Gửi tới TTS',
      'pasteTranslatedSrt': 'Dán phụ đề SRT đã dịch hoặc văn bản...',
      'clearContent': 'Xóa nội dung',
      'generateAudioTts': 'Tạo Âm thanh (TTS)',
      'studioAudioReady': 'Âm thanh Studio Sẵn sàng',
      'generatedAudios': 'Âm thanh đã tạo',
      'copyContent': "Sao chép nội dung",
      'copiedToClipboard': 'Đã sao chép vào khay nhớ tạm!',
      'switchLanguage': 'Đổi ngôn ngữ (EN/VI)'
    }
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key] ?? key;
  }
}
