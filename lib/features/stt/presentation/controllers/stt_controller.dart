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
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.path != null) {
      state = state.copyWith(
          selectedMp3: res.files.single.path, outputText: '', error: '');
    }
  }

  Future<void> runStt() async {
    if (state.selectedMp3 == null) return;
    state = state.copyWith(isProcessing: true, error: '');
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/stt'));
      req.files
          .add(await http.MultipartFile.fromPath('file', state.selectedMp3!));
      final res = await req.send().timeout(const Duration(minutes: 30));
      if (res.statusCode == 200) {
        final body = await res.stream.bytesToString();
        final json = jsonDecode(body);
        state =
            state.copyWith(outputText: json['srt'] ?? '', isProcessing: false);
      } else {
        state = state.copyWith(
            error: "Error: ${res.statusCode}", isProcessing: false);
      }
    } catch (e) {
      state = state.copyWith(error: "Exception: $e", isProcessing: false);
    }
  }
}
