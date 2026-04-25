import 'package:flutter/material.dart';
import 'package:adhera/services/localization_service.dart';

class LocaleProvider extends ChangeNotifier {
  static final LocaleProvider _instance = LocaleProvider._internal();

  factory LocaleProvider() {
    return _instance;
  }

  LocaleProvider._internal() {
    _locale = const Locale('en');
  }

  late Locale _locale;

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    LocalizationService().setLocale(locale);
    notifyListeners();
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('fr'));
    } else {
      setLocale(const Locale('en'));
    }
  }
}
