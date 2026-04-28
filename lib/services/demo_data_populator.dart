import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

/// Service to populate demo patient data for presentations
class DemoDataPopulator {
  static const int intensivePhaseDays = 60;
  static const int missedDaysCount = 7;

  /// Populate demo data for current patient with 60 days of dose logs
  /// with 7 randomly missed doses, starting from the TB treatment start date
  static Future<void> populateDemoPatientData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final firestore = FirebaseFirestore.instance;
      final random = Random();
      
      // Fetch user's treatment start date
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc['tbTreatmentStart'] == null) {
        throw Exception('Treatment start date not found for this user');
      }

      final treatmentStartDate = (userDoc['tbTreatmentStart'] as Timestamp).toDate();
      
      // Generate random days to mark as missed (0-59)
      final missedDays = <int>{};
      while (missedDays.length < missedDaysCount) {
        missedDays.add(random.nextInt(intensivePhaseDays));
      }

      print('Generating demo data for ${user.email}...');
      print('Treatment start date: ${DateFormat('yyyy-MM-dd').format(treatmentStartDate)}');
      print('Missed days: $missedDays');

      // Create dose logs for each day starting from treatment start date
      for (int i = 0; i < intensivePhaseDays; i++) {
        final date = treatmentStartDate.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        final isMissed = missedDays.contains(i);

        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('doseLogs')
            .add({
          'date': dateString,
          'taken': !isMissed, // Mark as NOT taken if it's a missed day
          'timestamp': Timestamp.fromDate(date),
        });

        print('Created dose log for day ${i + 1}/$intensivePhaseDays (missed: $isMissed)');
      }

      print('✓ Demo data population completed successfully!');
      print('Created $intensivePhaseDays dose logs with $missedDaysCount missed doses');
    } catch (e) {
      print('Error populating demo data: $e');
      rethrow;
    }
  }

  /// Clear all demo data (useful for testing)
  static Future<void> clearDemoPatientData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('doseLogs')
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      print('✓ Demo data cleared successfully!');
    } catch (e) {
      print('Error clearing demo data: $e');
      rethrow;
    }
  }

  /// Get summary of current patient's dose logs
  static Future<Map<String, dynamic>> getDemoPatientSummary() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('doseLogs')
          .get();

      int totalDays = snapshot.docs.length;
      int takenDays = snapshot.docs.where((doc) => doc['taken'] == true).length;
      int missedDays = totalDays - takenDays;

      return {
        'totalDays': totalDays,
        'takenDays': takenDays,
        'missedDays': missedDays,
        'adherencePercent': totalDays > 0 ? ((takenDays / totalDays) * 100).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      print('Error getting demo data summary: $e');
      rethrow;
    }
  }
}
