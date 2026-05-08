import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocalizeai/core/l10n/locale_controller.dart';
import 'package:vocalizeai/core/l10n/app_localizations.dart';

void main() {
  group('LocaleController Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial locale is English when no preference is saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = LocaleController(prefs);
      
      expect(controller.state.languageCode, 'en');
    });

    test('Initial locale loads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'locale': 'vi'});
      final prefs = await SharedPreferences.getInstance();
      final controller = LocaleController(prefs);
      
      expect(controller.state.languageCode, 'vi');
    });

    test('toggleLocale switches between English and Vietnamese and saves to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = LocaleController(prefs);
      
      expect(controller.state.languageCode, 'en');
      
      controller.toggleLocale();
      expect(controller.state.languageCode, 'vi');
      expect(prefs.getString('locale'), 'vi');
      
      controller.toggleLocale();
      expect(controller.state.languageCode, 'en');
      expect(prefs.getString('locale'), 'en');
    });
  });

  group('AppLocalizations Tests', () {
    test('Returns correct translation for English', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.get('tabStt'), 'STT');
      expect(l10n.get('exportTxtMinutes'), 'Export as TXT (Minutes)');
    });

    test('Returns correct translation for Vietnamese', () {
      final l10n = AppLocalizations(const Locale('vi'));
      expect(l10n.get('tabStt'), 'STT (Giọng nói)');
      expect(l10n.get('exportTxtMinutes'), 'Xuất file TXT (Biên bản)');
    });

    test('Returns key if translation is missing', () {
      final l10n = AppLocalizations(const Locale('vi'));
      expect(l10n.get('missing_key_123'), 'missing_key_123');
    });
  });
}
