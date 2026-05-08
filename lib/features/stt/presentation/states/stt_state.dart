class SttState {
  final bool isProcessing;
  final List<String> selectedFiles;
  final Map<String, String> outputs;
  final Map<String, String> errors;
  final String? currentProcessingFile;

  const SttState({
    this.isProcessing = false,
    this.selectedFiles = const [],
    this.outputs = const {},
    this.errors = const {},
    this.currentProcessingFile,
  });

  SttState copyWith({
    bool? isProcessing,
    List<String>? selectedFiles,
    Map<String, String>? outputs,
    Map<String, String>? errors,
    String? currentProcessingFile,
    bool clearCurrentFile = false,
  }) {
    return SttState(
      isProcessing: isProcessing ?? this.isProcessing,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      outputs: outputs ?? this.outputs,
      errors: errors ?? this.errors,
      currentProcessingFile: clearCurrentFile ? null : (currentProcessingFile ?? this.currentProcessingFile),
    );
  }
}
