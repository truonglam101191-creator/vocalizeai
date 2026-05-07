import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:vocalizeai/features/tts/presentation/states/tts_state.dart';
import 'package:audioplayers/audioplayers.dart';

final ttsControllerProvider =
    StateNotifierProvider<TtsController, TtsState>((ref) => TtsController());
final ttsInputProvider = Provider((ref) => TextEditingController());
final audioPlayerProvider = Provider((ref) => AudioPlayer());

class TtsController extends StateNotifier<TtsState> {
  TtsController() : super(const TtsState()) {
    loadFiles();
    fetchVoices();
  }

  void setSelectedVoice(String v) => state = state.copyWith(selectedVoice: v);

  Future<void> loadFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docDir.path}/VocalizeAI/TTS');
      if (await targetDir.exists()) {
        final files = targetDir.listSync().whereType<File>().toList();
        files.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        state = state.copyWith(outputFiles: files.map((f) => f.path).toList());
      }
    } catch (_) {}
  }

  Future<void> fetchVoices() async {
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:5000/voices'));
      if (res.statusCode == 200) {
        final vd = jsonDecode(res.body);
        List<Map<String, String>> vlist = [];
        if (vd.containsKey('categories')) {
          final cats = vd['categories'] as Map<String, dynamic>;
          for (var entry in cats.entries) {
            final lang = entry.key;
            final list = entry.value as List;
            for (var v in list) {
              vlist.add(
                  {'id': v['id'].toString(), 'name': '$lang: ${v['name']}'});
            }
          }
          vlist.sort((a, b) => a['name']!.compareTo(b['name']!));
        }
        String? sel = vd['default'];
        if (vlist.isNotEmpty && !vlist.any((v) => v['id'] == sel)) {
          sel = vlist.first['id'];
        }
        state = state.copyWith(voices: vlist, selectedVoice: sel);
      }
    } catch (_) {}
  }

  Future<void> runTts(String text, AudioPlayer player) async {
    if (text.isEmpty) return;
    state = state.copyWith(isProcessing: true, outputWavPath: null);
    player.stop();
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/tts'));
      req.fields['text'] = text;
      if (state.selectedVoice != null) {
        req.fields['tts_voice'] = state.selectedVoice!;
      }
      final res = await req.send().timeout(const Duration(minutes: 10));
      if (res.statusCode == 200) {
        final bytes = await res.stream.toBytes();
        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = Directory('${docDir.path}/VocalizeAI/TTS');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        final outPath = p.join(
            targetDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
        await File(outPath).writeAsBytes(bytes);

        final newFiles = List<String>.from(state.outputFiles);
        if (!newFiles.contains(outPath)) {
          newFiles.insert(0, outPath);
        }

        state = state.copyWith(
            outputWavPath: outPath, outputFiles: newFiles, isProcessing: false);
      } else {
        state = state.copyWith(isProcessing: false);
      }
    } catch (e) {
      debugPrint("TTS Error: $e");
      state = state.copyWith(isProcessing: false);
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
