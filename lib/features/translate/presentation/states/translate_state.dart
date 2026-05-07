class TranslateState {
  final String fromLang;
  final String toLang;
  final bool isProcessing;
  final String translatedText;
  final String error;
  final List<String> outputFiles;

  const TranslateState({
    this.fromLang = 'en',
    this.toLang = 'vi',
    this.isProcessing = false,
    this.translatedText = '',
    this.error = '',
    this.outputFiles = const [],
  });

  TranslateState copyWith({
    String? fromLang,
    String? toLang,
    bool? isProcessing,
    String? translatedText,
    String? error,
    List<String>? outputFiles,
  }) {
    return TranslateState(
      fromLang: fromLang ?? this.fromLang,
      toLang: toLang ?? this.toLang,
      isProcessing: isProcessing ?? this.isProcessing,
      translatedText: translatedText ?? this.translatedText,
      error: error ?? this.error,
      outputFiles: outputFiles ?? this.outputFiles,
    );
  }
}
