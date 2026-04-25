import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_list.dart';
import 'alerts_page.dart';
import 'profile_page.dart';
import 'package:adhera/services/notification_service.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    PatientListPage(),
    AlertsPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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
          height: 78,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.people), label: 'Patients'),
            NavigationDestination(
              icon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Exit App?'),
          content: const Text('Are you sure you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                await NotificationService.instance.cancelMedicationReminders();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}
