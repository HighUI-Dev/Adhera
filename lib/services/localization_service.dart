import 'package:flutter/material.dart';

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();

  factory LocalizationService() {
    return _instance;
  }

  LocalizationService._internal();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
  }

  String getLanguageName(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'en':
      default:
        return 'English';
    }
  }

  static const Map<String, Map<String, String>> translations = {
    'en': {
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'french': 'Français',
      'sign_out': 'Sign Out',
      'account': 'Account',
      'about': 'About',
      'help': 'Help',
      'privacy': 'Privacy Policy',
      'terms': 'Terms of Service',
      'dark_mode': 'Dark Mode',
      'notifications': 'Notifications',
      'app_name': 'Adhera',
      'welcome': 'Welcome',
      'sign_in': 'Sign In to Your Account',
      'email': 'Email',
      'password': 'Password',
      'remember_me': 'Remember Me',
      'forgot_password': 'Forgot Password?',
      'sign_in_button': 'Sign In',
      'dont_have_account': "Don't have an account?",
      'sign_up': 'Sign Up',
      'tracking': 'Tracking',
      'add_dose': 'Add Dose',
      'mark_taken': 'Mark as Taken',
      'medication': 'Medication',
      'dose': 'Dose',
      'date': 'Date',
      'time': 'Time',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'back': 'Back',
      'next': 'Next',
      'previous': 'Previous',
      'logout_message': 'Are you sure you want to sign out?',
      'confirm': 'Confirm',
    },
    'fr': {
      'settings': 'Paramètres',
      'language': 'Langue',
      'english': 'English',
      'french': 'Français',
      'sign_out': 'Se déconnecter',
      'account': 'Compte',
      'about': 'À propos',
      'help': 'Aide',
      'privacy': 'Politique de confidentialité',
      'terms': 'Conditions de service',
      'dark_mode': 'Mode sombre',
      'notifications': 'Notifications',
      'app_name': 'Adhera',
      'welcome': 'Bienvenue',
      'sign_in': 'Connectez-vous à votre compte',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'remember_me': 'Se souvenir de moi',
      'forgot_password': 'Mot de passe oublié?',
      'sign_in_button': 'Se connecter',
      'dont_have_account': "Vous n'avez pas de compte?",
      'sign_up': "S'inscrire",
      'tracking': 'Suivi',
      'add_dose': 'Ajouter une dose',
      'mark_taken': 'Marquer comme pris',
      'medication': 'Médicament',
      'dose': 'Dose',
      'date': 'Date',
      'time': 'Heure',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'back': 'Retour',
      'next': 'Suivant',
      'previous': 'Précédent',
      'logout_message': 'Êtes-vous sûr de vouloir vous déconnecter?',
      'confirm': 'Confirmer',
    }
  };

  static String translate(String key, {String locale = 'en'}) {
    return translations[locale]?[key] ?? translations['en']?[key] ?? key;
  }

  String t(String key) {
    return translate(key, locale: _locale.languageCode);
  }
}

extension TranslationExtension on BuildContext {
  String t(String key) {
    return LocalizationService().t(key);
  }
}
