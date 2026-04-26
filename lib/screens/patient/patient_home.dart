import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import 'package:adhera/services/notification_service.dart';
import 'package:adhera/services/localization_service.dart';
import 'tracking_page.dart';
import 'treatment_page.dart';
import 'symptoms_page.dart';
import 'insights_page.dart';
import 'profile_page.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    TrackingPage(),
    TreatmentPage(),
    SymptomsPage(),
    InsightsPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.syncForCurrentUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.syncForCurrentUser();
    }
  }

  // Sign out function
  /*
  await FirebaseAuth.instance.signOut();
  if (context.mounted) {
    Navigator.pushReplacementNamed(context, '/');
  }
  */

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitApp();
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home),
              label: context.t('tracking'),
            ),
            NavigationDestination(
              icon: const FaIcon(FontAwesomeIcons.capsules, size: 22),
              label: context.t('treatment'),
            ),
            NavigationDestination(
              icon: const FaIcon(FontAwesomeIcons.heartPulse, size: 22),
              label: context.t('symptoms'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights),
              label: context.t('insights'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_rounded),
              label: context.t('profile'),
            ),
          ],
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
        ),
      ),
    );
  }

  void _exitApp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.t('exit_app')),
          content: Text(context.t('exit_app_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Exit the app
                if (Platform.isAndroid) {
                  SystemNavigator.pop();
                } else if (Platform.isIOS) {
                  exit(0);
                }
              },
              child: Text(context.t('exit')),
            ),
          ],
        );
      },
    );
  }
}
