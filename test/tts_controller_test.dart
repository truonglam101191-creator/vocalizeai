import 'package:flutter_test/flutter_test.dart';
import 'package:vocalizeai/features/tts/presentation/controllers/tts_controller.dart';
import 'package:vocalizeai/features/tts/presentation/states/tts_state.dart';

void main() {
  group('TtsController Tests', () {
    test('clearMediaFile sets clearMediaFile flag and removes media file', () {
      final controller = TtsController();
      
      // Simulate file selected
      controller.state = controller.state.copyWith(selectedMediaFile: 'mock/path/video.mp4');
      expect(controller.state.selectedMediaFile, 'mock/path/video.mp4');
      
      // Clear
      controller.clearMediaFile();
      expect(controller.state.selectedMediaFile, isNull);
    });

    test('setSelectedVoice updates the voice selection', () {
      final controller = TtsController();
      
      controller.setSelectedVoice('vi-VN-Voice1');
      expect(controller.state.selectedVoice, 'vi-VN-Voice1');
    });
  });
}
