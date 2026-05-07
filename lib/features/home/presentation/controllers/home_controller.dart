import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/backend_manager.dart';

final isBackendReadyProvider = StateProvider<bool>((ref) => false);

final homeControllerProvider = Provider((ref) => HomeController(ref));

class HomeController {
  final Ref _ref;
  HomeController(this._ref);

  Future<void> initBackend() async {
    await BackendManager.launch();
    final ready = await BackendManager.waitReady();
    _ref.read(isBackendReadyProvider.notifier).state = ready;
  }

  Future<void> stopBackend() async {
    _ref.read(isBackendReadyProvider.notifier).state = false;
    await BackendManager.stop();
  }

  Future<void> restartBackend() async {
    _ref.read(isBackendReadyProvider.notifier).state = false;
    await BackendManager.restart();
    final ready = await BackendManager.waitReady();
    _ref.read(isBackendReadyProvider.notifier).state = ready;
  }
}
