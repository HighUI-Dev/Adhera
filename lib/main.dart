import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adhera/firebase_options.dart';
import 'package:adhera/screens/auth/auth_page.dart';
import 'package:adhera/screens/patient/patient_home.dart';
import 'package:adhera/screens/doctor/doctor_dashboard.dart';
import 'package:adhera/services/notification_service.dart';
import 'package:adhera/services/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.initialize();

  String initialRoute = '/';
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String role = doc['role'];
      if (role == 'patient') {
        initialRoute = '/patient_home';
        await NotificationService.instance.syncForCurrentUser();
      } else {
        initialRoute = '/doctor_dashboard';
        await NotificationService.instance.cancelMedicationReminders();
      }
    } catch (e) {
      // If error fetching role, go to auth
      initialRoute = '/';
      await NotificationService.instance.cancelMedicationReminders();
    }
  } else {
    await NotificationService.instance.cancelMedicationReminders();
  }

  runApp(MainApp(initialRoute: initialRoute));
}

class MainApp extends StatefulWidget {
  final String initialRoute;

  const MainApp({super.key, required this.initialRoute});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late LocaleProvider _localeProvider;

  @override
  void initState() {
    super.initState();
    _localeProvider = LocaleProvider();
    _localeProvider.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    _localeProvider.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _localeProvider.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      initialRoute: widget.initialRoute,
      routes: {
        '/': (context) => AuthPage(),
        '/patient_home': (context) => PatientHome(),
        '/doctor_dashboard': (context) => DoctorDashboard(),
      },
    );
  }
}
