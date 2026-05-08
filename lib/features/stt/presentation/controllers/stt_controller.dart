import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:vocalizeai/features/stt/presentation/states/stt_state.dart';
import 'dart:convert';

final sttControllerProvider =
    StateNotifierProvider<SttController, SttState>((ref) => SttController());

class SttController extends StateNotifier<SttState> {
  SttController() : super(const SttState());

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (res != null && res.files.isNotEmpty) {
      final paths = res.files.map((e) => e.path!).toList();
      state = state.copyWith(
          selectedFiles: paths, outputs: {}, errors: {}, clearCurrentFile: true);
    }
  }

  void removeFile(String path) {
    if (state.isProcessing) return;
    final newFiles = List<String>.from(state.selectedFiles)..remove(path);
    final newOutputs = Map<String, String>.from(state.outputs)..remove(path);
    final newErrors = Map<String, String>.from(state.errors)..remove(path);
    state = state.copyWith(selectedFiles: newFiles, outputs: newOutputs, errors: newErrors);
  }

  void updateOutput(String path, String newOutput) {
    final newOutputs = Map<String, String>.from(state.outputs);
    newOutputs[path] = newOutput;
    state = state.copyWith(outputs: newOutputs);
  }

  Future<void> runStt() async {
    if (state.selectedFiles.isEmpty) return;
    state = state.copyWith(isProcessing: true, errors: {}, outputs: {});
    
    for (String filePath in state.selectedFiles) {
      state = state.copyWith(currentProcessingFile: filePath);
      try {
        final req =
            http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5055/stt'));
        req.files
            .add(await http.MultipartFile.fromPath('file', filePath));
        final res = await req.send().timeout(const Duration(minutes: 30));
        
        if (res.statusCode == 200) {
          final body = await res.stream.bytesToString();
          final json = jsonDecode(body);
          final newOutputs = Map<String, String>.from(state.outputs);
          newOutputs[filePath] = json['srt'] ?? '';
          state = state.copyWith(outputs: newOutputs);
        } else {
          final newErrors = Map<String, String>.from(state.errors);
          newErrors[filePath] = "Error: ${res.statusCode}";
          state = state.copyWith(errors: newErrors);
        }
      } catch (e) {
        final newErrors = Map<String, String>.from(state.errors);
        newErrors[filePath] = "Exception: $e";
        state = state.copyWith(errors: newErrors);
      }
    }
    
    state = state.copyWith(isProcessing: false, clearCurrentFile: true);
  }
}
