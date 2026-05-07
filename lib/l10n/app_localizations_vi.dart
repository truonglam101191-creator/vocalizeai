// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get offlineMediaPipeline => 'Xử lý Truyền thông Ngoại tuyến';

  @override
  String get stopAiServer => 'Dừng Máy chủ AI';

  @override
  String get resetAiServer => 'Khởi động lại AI';

  @override
  String get startingAiEngine => 'Đang khởi động AI...';

  @override
  String get tabStt => 'STT (Nhận diện giọng nói)';

  @override
  String get tabTranslate => 'Dịch thuật';

  @override
  String get tabTts => 'TTS (Chuyển văn bản thành giọng nói)';

  @override
  String get dropAudio => 'Kéo thả âm thanh vào đây hoặc nhấp để tải';

  @override
  String get extractTextStt => 'Trích xuất Văn bản (STT)';

  @override
  String get subtitlesSrt => 'Phụ đề (SRT)';

  @override
  String get copySubtitles => 'Sao chép phụ đề';

  @override
  String get subtitlesCopied => 'Đã sao chép phụ đề!';

  @override
  String get sendToTranslate => 'Gửi tới Dịch thuật';

  @override
  String get pasteSrtToTranslate =>
      'Dán phụ đề SRT hoặc văn bản cần dịch vào đây...';

  @override
  String get loadFromFile => 'Tải từ file';

  @override
  String get translateText => 'Dịch Văn bản';

  @override
  String get translatedContent => 'Nội dung đã dịch';

  @override
  String get copyTranslation => 'Sao chép bản dịch';

  @override
  String get translationCopied => 'Đã sao chép bản dịch!';

  @override
  String get savedTranslations => 'Bản dịch đã lưu';

  @override
  String get openFolder => 'Mở thư mục';

  @override
  String get copyFilePath => 'Sao chép đường dẫn file';

  @override
  String get pathCopied => 'Đã sao chép đường dẫn!';

  @override
  String get sendToTts => 'Gửi tới TTS';

  @override
  String get pasteTranslatedSrt =>
      'Dán phụ đề SRT đã dịch hoặc văn bản vào đây...';

  @override
  String get clearContent => 'Xóa nội dung';

  @override
  String get generateAudioTts => 'Tạo Âm thanh (TTS)';

  @override
  String get studioAudioReady => 'Âm thanh Studio Sẵn sàng';

  @override
  String get generatedAudios => 'Âm thanh đã tạo';

  @override
  String get copyContent => 'Sao chép nội dung';

  @override
  String get copiedToClipboard => 'Đã sao chép vào khay nhớ tạm!';

  @override
  String get switchLanguage => 'Đổi Ngôn ngữ';
}
