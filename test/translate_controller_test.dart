import 'package:flutter_test/flutter_test.dart';
import 'package:vocalizeai/features/translate/presentation/controllers/translate_controller.dart';
import 'package:vocalizeai/features/translate/presentation/states/translate_state.dart';

void main() {
  group('TranslateController Tests', () {
    test('Initial state has default languages (en to vi) and empty fields', () {
      final controller = TranslateController();
      final state = controller.state;
      
      expect(state.fromLang, 'en');
      expect(state.toLang, 'vi');
      expect(state.isProcessing, false);
      expect(state.translatedText, '');
      expect(state.error, '');
    });

    test('setFromLang and setToLang update state correctly', () {
      final controller = TranslateController();
      
      controller.setFromLang('fr');
      expect(controller.state.fromLang, 'fr');
      
      controller.setToLang('de');
      expect(controller.state.toLang, 'de');
    });
  });
}
