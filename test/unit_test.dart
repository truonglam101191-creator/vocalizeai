import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocalizeai/features/translate/presentation/states/translate_state.dart';
import 'package:vocalizeai/core/theme/app_theme.dart';
import 'package:vocalizeai/core/theme/app_colors.dart';

void main() {
  group('TranslateState Unit Tests', () {
    test('Default values are correct', () {
      const state = TranslateState();
      
      expect(state.fromLang, 'en');
      expect(state.toLang, 'vi');
      expect(state.isProcessing, false);
      expect(state.translatedText, '');
      expect(state.error, '');
      expect(state.outputFiles, isEmpty);
    });

    test('copyWith updates specific fields correctly', () {
      const state = TranslateState();
      
      final newState = state.copyWith(
        fromLang: 'fr',
        isProcessing: true,
        translatedText: 'Bonjour',
      );
      
      expect(newState.fromLang, 'fr');
      expect(newState.toLang, 'vi'); // Unchanged
      expect(newState.isProcessing, true);
      expect(newState.translatedText, 'Bonjour');
      expect(newState.error, ''); // Unchanged
    });
  });

  group('AppTheme Unit Tests', () {
    test('darkTheme has correct properties', () {
      final theme = AppTheme.darkTheme;
      
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.error, AppColors.error);
    });
  });
}
