class TtsState {
  final bool isProcessing;
  final String? selectedVoice;
  final List<Map<String, String>> voices;
  final String? outputWavPath;
  final List<String> outputFiles;

  const TtsState({
    this.isProcessing = false,
    this.selectedVoice,
    this.voices = const [],
    this.outputWavPath,
    this.outputFiles = const [],
  });

  TtsState copyWith({
    bool? isProcessing,
    String? selectedVoice,
    List<Map<String, String>>? voices,
    String? outputWavPath,
    List<String>? outputFiles,
  }) {
    return TtsState(
      isProcessing: isProcessing ?? this.isProcessing,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      voices: voices ?? this.voices,
      outputWavPath: outputWavPath ?? this.outputWavPath,
      outputFiles: outputFiles ?? this.outputFiles,
    );
  }
}
