import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/ai_model.dart';

final downloadingModelsProvider = StateProvider<Set<String>>((ref) => {});

final modelManagerProvider =
    AsyncNotifierProvider<ModelManagerController, Map<String, List<AiModel>>>(
        () {
  return ModelManagerController();
});

class ModelManagerController extends AsyncNotifier<Map<String, List<AiModel>>> {
  static const String _baseUrl = 'http://127.0.0.1:5055/api/models';
  Timer? _timer;

  @override
  Future<Map<String, List<AiModel>>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchModels().then((data) {
        if (data.isNotEmpty) {
          state = AsyncData(data);
          // Check if any downloading models are now downloaded, if so remove from downloading set
          final downloading = ref.read(downloadingModelsProvider);
          if (downloading.isNotEmpty) {
            final Set<String> newDownloading = {...downloading};
            bool changed = false;
            for (final list in data.values) {
              for (final m in list) {
                if (m.downloaded && newDownloading.contains(m.name)) {
                  newDownloading.remove(m.name);
                  changed = true;
                }
              }
            }
            if (changed) {
              ref.read(downloadingModelsProvider.notifier).state =
                  newDownloading;
            }
          }
        }
      });
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return fetchModels();
  }

  Future<Map<String, List<AiModel>>> fetchModels() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final whisperList =
            (data['whisper'] as List).map((e) => AiModel.fromJson(e)).toList();
        final ttsList =
            (data['tts'] as List).map((e) => AiModel.fromJson(e)).toList();
        final openvoiceList = (data['openvoice'] as List?)
                ?.map((e) => AiModel.fromJson(e))
                .toList() ??
            [];
        return {
          'whisper': whisperList,
          'tts': ttsList,
          'openvoice': openvoiceList
        };
      }
    } catch (e) {
      // Ignore or log error
    }
    return state.value ?? {'whisper': [], 'tts': [], 'openvoice': []};
  }

  Future<void> downloadModel(String name, String type) async {
    ref
        .read(downloadingModelsProvider.notifier)
        .update((state) => {...state, name});
    try {
      await http.post(
        Uri.parse('$_baseUrl/download'),
        body: {'model_name': name, 'model_type': type},
      );
    } catch (e) {
      ref.read(downloadingModelsProvider.notifier).update((state) {
        final s = {...state};
        s.remove(name);
        return s;
      });
    }
  }

  Future<void> deleteModel(String name, String type) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/$type/$name'));
      final data = await fetchModels();
      state = AsyncData(data);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> refreshModels() async {
    final data = await fetchModels();
    state = AsyncData(data);
  }
}

// Add a provider to poll status from backend to show download progress
final backendStatusProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  while (true) {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5055/status'));
      if (response.statusCode == 200) {
        yield jsonDecode(response.body);
      }
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 1000));
  }
});
