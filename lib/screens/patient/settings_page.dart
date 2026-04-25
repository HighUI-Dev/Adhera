import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:adhera/services/localization_service.dart';
import 'package:adhera/services/locale_provider.dart';
import 'package:adhera/screens/auth/auth_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late LocaleProvider _localeProvider;

  @override
  void initState() {
    super.initState();
    _localeProvider = LocaleProvider();
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.t('language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                onTap: () {
                  _localeProvider.setLocale(const Locale('en'));
                  setState(() {});
                  Navigator.pop(context);
                },
                selected: _localeProvider.locale.languageCode == 'en',
              ),
              ListTile(
                title: const Text('Français'),
                onTap: () {
                  _localeProvider.setLocale(const Locale('fr'));
                  setState(() {});
                  Navigator.pop(context);
                },
                selected: _localeProvider.locale.languageCode == 'fr',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: Text(context.t('logout_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t('cancel')),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                }
              },
              child: Text(context.t('sign_out')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('settings'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Language Setting
              Card(
                child: ListTile(
                  title: Text(context.t('language')),
                  subtitle: Text(
                    _localeProvider.locale.languageCode == 'en'
                        ? 'English'
                        : 'Français',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _showLanguageDialog,
                ),
              ),
              const SizedBox(height: 16),
              // Sign Out
              Card(
                child: ListTile(
                  title: Text(
                    context.t('sign_out'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.logout, color: Colors.red),
                  onTap: _showLogoutDialog,
                ),
              ),
              const SizedBox(height: 24),
              // About Section
              Text(
                context.t('about'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Adhera v1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
