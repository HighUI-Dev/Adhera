import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:adhera/services/localization_service.dart';

class DemoAccessService {
  DemoAccessService._();

  static bool _demoSession = false;

  static void markDemoSession() {
    _demoSession = true;
  }

  static void clearDemoSession() {
    _demoSession = false;
  }

  static bool isCurrentUserDemo() {
    return _demoSession && FirebaseAuth.instance.currentUser != null;
  }

  static void showReadOnlyMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('demo_read_only_message'))),
    );
  }
}
