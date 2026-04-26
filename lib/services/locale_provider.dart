import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhera/services/localization_service.dart';

class LocaleProvider extends ChangeNotifier {
  static final LocaleProvider _instance = LocaleProvider._internal();
  static const String _languageCodeKey = 'selected_language_code';

  factory LocaleProvider() {
    return _instance;
  }

  LocaleProvider._internal() {
    _locale = const Locale('en');
  }

  late Locale _locale;
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  Future<void> loadSavedLocale() async {
    if (_isInitialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(_languageCodeKey);

    if (savedLanguageCode != null && savedLanguageCode.isNotEmpty) {
      _locale = Locale(savedLanguageCode);
    }

    LocalizationService().setLocale(_locale);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    LocalizationService().setLocale(locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, locale.languageCode);

    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    if (_locale.languageCode == 'en') {
      await setLocale(const Locale('fr'));
    } else {
      await setLocale(const Locale('en'));
    }
  }
}
