import 'package:flutter_test/flutter_test.dart';
import 'package:vocalizeai/features/stt/presentation/controllers/stt_controller.dart';
import 'package:vocalizeai/features/stt/presentation/states/stt_state.dart';

void main() {
  group('SttController Tests', () {
    test('Initial state is empty', () {
      final controller = SttController();
      final state = controller.state;
      
      expect(state.selectedFiles.isEmpty, true);
      expect(state.outputs.isEmpty, true);
      expect(state.errors.isEmpty, true);
      expect(state.isProcessing, false);
    });

    test('removeFile removes file from selectedFiles, outputs, and errors', () {
      final controller = SttController();
      
      // Setup mock state
      controller.state = const SttState(
        selectedFiles: ['file1.mp3', 'file2.mp4'],
        outputs: {'file1.mp3': 'SRT Content 1', 'file2.mp4': 'SRT Content 2'},
        errors: {'file1.mp3': 'Error 1'},
      );
      
      controller.removeFile('file1.mp3');
      
      expect(controller.state.selectedFiles.contains('file1.mp3'), false);
      expect(controller.state.outputs.containsKey('file1.mp3'), false);
      expect(controller.state.errors.containsKey('file1.mp3'), false);
      
      // Ensure file2 remains
      expect(controller.state.selectedFiles.contains('file2.mp4'), true);
      expect(controller.state.outputs.containsKey('file2.mp4'), true);
    });

    test('updateOutput updates output correctly', () {
      final controller = SttController();
      
      controller.state = const SttState(
        selectedFiles: ['file1.mp3'],
        outputs: {'file1.mp3': 'Old Content'},
      );
      
      controller.updateOutput('file1.mp3', 'New Content');
      
      expect(controller.state.outputs['file1.mp3'], 'New Content');
    });
  });
}
