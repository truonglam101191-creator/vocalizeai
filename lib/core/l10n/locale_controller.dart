import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleController(prefs);
});

final l10nProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(localeProvider);
  return AppLocalizations(locale);
});

class LocaleController extends StateNotifier<Locale> {
  final SharedPreferences _prefs;

  LocaleController(this._prefs) : super(Locale(_prefs.getString('locale') ?? 'en'));

  void toggleLocale() {
    if (state.languageCode == 'en') {
      state = const Locale('vi');
      _prefs.setString('locale', 'vi');
    } else {
      state = const Locale('en');
      _prefs.setString('locale', 'en');
    }
  }
}
