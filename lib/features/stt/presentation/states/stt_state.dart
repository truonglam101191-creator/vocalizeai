class SttState {
  final bool isProcessing;
  final String? selectedMp3;
  final String outputText;
  final String error;

  const SttState({
    this.isProcessing = false,
    this.selectedMp3,
    this.outputText = '',
    this.error = '',
  });

  SttState copyWith({
    bool? isProcessing,
    String? selectedMp3,
    String? outputText,
    String? error,
  }) {
    return SttState(
      isProcessing: isProcessing ?? this.isProcessing,
      selectedMp3: selectedMp3 ?? this.selectedMp3,
      outputText: outputText ?? this.outputText,
      error: error ?? this.error,
    );
  }
}
