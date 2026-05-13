import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:vocalizeai/features/stt/presentation/states/stt_state.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final sttControllerProvider =
    StateNotifierProvider<SttController, SttState>((ref) => SttController());

class SttController extends StateNotifier<SttState> {
  SttController() : super(const SttState()) {
    loadHistory();
  }

  @override
  set state(SttState value) {
    super.state = value;
    if (!value.isProcessing) {
      saveHistory();
    }
  }

  Future<void> saveHistory() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final historyFile = File('${docDir.path}/VocalizeAI/STT_History.json');
      if (!historyFile.parent.existsSync()) {
        historyFile.parent.createSync(recursive: true);
      }
      final historyData = {
        'files': state.selectedFiles,
        'outputs': state.outputs,
      };
      await historyFile.writeAsString(jsonEncode(historyData));
    } catch (_) {}
  }

  Future<void> loadHistory() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final historyFile = File('${docDir.path}/VocalizeAI/STT_History.json');
      if (await historyFile.exists()) {
        final jsonStr = await historyFile.readAsString();
        final data = jsonDecode(jsonStr);
        final files = List<String>.from(data['files'] ?? []);
        final outputs = Map<String, String>.from(data['outputs'] ?? {});
        
        files.removeWhere((f) => !File(f).existsSync());
        outputs.removeWhere((k, v) => !files.contains(k));
        
        super.state = state.copyWith(selectedFiles: files, outputs: outputs);
      }
    } catch (_) {}
  }

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'ogg', 'mp4', 'mkv', 'mov'],
      allowMultiple: true
    );
    if (res != null && res.files.isNotEmpty) {
      final paths = res.files.map((e) => e.path!).toList();
      state = state.copyWith(
          selectedFiles: paths, outputs: {}, errors: {}, clearCurrentFile: true);
    }
  }

  Future<void> pickFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder for Batch Processing',
    );
    if (dirPath != null) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;
      
      final files = dir.listSync(recursive: false).where((f) {
        if (f is File) {
          final ext = p.extension(f.path).toLowerCase();
          return ['.mp3', '.wav', '.m4a', '.flac', '.ogg', '.mp4', '.mkv', '.mov'].contains(ext);
        }
        return false;
      }).map((e) => e.path).toList();
      
      if (files.isNotEmpty) {
        final currentFiles = List<String>.from(state.selectedFiles);
        for (var f in files) {
          if (!currentFiles.contains(f)) currentFiles.add(f);
        }
        state = state.copyWith(selectedFiles: currentFiles, clearCurrentFile: true);
      }
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

  void toggleOcr(bool value) {
    state = state.copyWith(useOcr: value);
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
        req.fields['use_ocr'] = state.useOcr.toString();
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

  Future<void> exportAsTxt(String path) async {
    final srtContent = state.outputs[path];
    if (srtContent == null || srtContent.isEmpty) return;

    final lines = srtContent.split('\n');
    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (int.tryParse(line) != null && (i == 0 || lines[i - 1].trim().isEmpty)) continue;
      if (line.contains('-->')) continue;
      buffer.write('$line ');
    }
    final plainText = buffer.toString().trim();

    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Meeting Minutes (TXT)',
      fileName: '${p.basenameWithoutExtension(path)}_minutes.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsString(plainText);
    }
  }

  Future<void> exportAsSrt(String path) async {
    final srtContent = state.outputs[path];
    if (srtContent == null || srtContent.isEmpty) return;

    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Subtitles (SRT)',
      fileName: '${p.basenameWithoutExtension(path)}.srt',
      type: FileType.custom,
      allowedExtensions: ['srt'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsString(srtContent);
    }
  }
}
