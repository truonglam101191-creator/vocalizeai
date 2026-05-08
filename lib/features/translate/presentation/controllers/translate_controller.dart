import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:vocalizeai/features/translate/presentation/states/translate_state.dart';

final translateControllerProvider =
    StateNotifierProvider<TranslateController, TranslateState>(
        (ref) => TranslateController());
final translateInputProvider = Provider((ref) => TextEditingController());

class TranslateController extends StateNotifier<TranslateState> {
  TranslateController() : super(const TranslateState()) {
    loadFiles();
  }

  void setFromLang(String lang) => state = state.copyWith(fromLang: lang);
  void setToLang(String lang) => state = state.copyWith(toLang: lang);

  Future<void> loadFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docDir.path}/VocalizeAI/Translations');
      if (await targetDir.exists()) {
        final files = targetDir.listSync().whereType<File>().toList();
        files.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        state = state.copyWith(outputFiles: files.map((f) => f.path).toList());
      }
    } catch (_) {}
  }

  Future<void> pickTextFile(TextEditingController ctrl) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    if (res != null && res.files.single.path != null) {
      final text = await File(res.files.single.path!).readAsString();
      ctrl.text = text;
    }
  }

  Future<void> runTranslate(String text) async {
    if (text.isEmpty) return;
    state = state.copyWith(isProcessing: true, error: '');
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('http://127.0.0.1:5055/translate'));
      req.fields['text'] = text;
      req.fields['from_lang'] = state.fromLang;
      req.fields['to_lang'] = state.toLang;

      final res = await req.send().timeout(const Duration(minutes: 5));
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        final json = jsonDecode(body);
        final result = json['translated_text'] ?? '';

        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = Directory('${docDir.path}/VocalizeAI/Translations');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        final isSrt = text.contains('-->');
        final ext = isSrt ? 'srt' : 'txt';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${targetDir.path}/translation_$timestamp.$ext');
        await file.writeAsString(result);

        final newFiles = List<String>.from(state.outputFiles);
        if (!newFiles.contains(file.path)) {
          newFiles.insert(0, file.path);
        }

        state = state.copyWith(
            translatedText: result, outputFiles: newFiles, isProcessing: false);
      } else {
        state = state.copyWith(error: "Error: $body", isProcessing: false);
      }
    } catch (e) {
      state = state.copyWith(error: "Exception: $e", isProcessing: false);
    }
  }

  void openFolder(String filePath) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(filePath).parent.path]);
    }
  }
}
