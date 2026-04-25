import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'patient_detail.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Patient Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildAlertsList(),
    );
  }

  Widget _buildAlertsList() {
    return FutureBuilder<Map<String, List<AlertData>>>(
      future: _generateAlertsBySections(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final alertData = snapshot.data ??
            {
              'missed_doses': <AlertData>[],
              'low_adherence': <AlertData>[],
            };
        final missedDosesAlerts = alertData['missed_doses'] ?? [];
        final lowAdherenceAlerts = alertData['low_adherence'] ?? [];
        final hasAlerts =
            missedDosesAlerts.isNotEmpty ||
            lowAdherenceAlerts.isNotEmpty;

        if (!hasAlerts) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          size: 32,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No alerts',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All patients are on track',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (missedDosesAlerts.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  title: 'Missed Doses - Last 7 Days',
                  subtitle:
                      '${missedDosesAlerts.length} patient${missedDosesAlerts.length > 1 ? 's' : ''} need immediate attention',
                  color: Colors.red,
                ),
                ...missedDosesAlerts.map(
                  (alert) => _AlertCard(
                    alert: alert,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PatientDetailPage(patientUid: alert.patientUid),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (lowAdherenceAlerts.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  title: 'Low Adherence - Overall Treatment',
                  subtitle:
                      '${lowAdherenceAlerts.length} patient${lowAdherenceAlerts.length > 1 ? 's' : ''} below 80% adherence',
                  color: Colors.orange,
                ),
                ...lowAdherenceAlerts.map(
                  (alert) => _AlertCard(
                    alert: alert,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PatientDetailPage(patientUid: alert.patientUid),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, List<AlertData>>> _generateAlertsBySections() async {
    final missedDosesAlerts = <AlertData>[];
    final lowAdherenceAlerts = <AlertData>[];

    try {
      final patientsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();

      for (final patientDoc in patientsSnapshot.docs) {
        final patientId = patientDoc.id;
        final patientData = patientDoc.data();
        final patientName = patientData['name'] ?? 'Unknown';

        final doseLogsSnapshot = await _firestore
            .collection('users')
            .doc(patientId)
            .collection('doseLogs')
            .get();

        final doseLogs = doseLogsSnapshot.docs
            .map((doc) => DoseLogData.fromMap(doc.data()))
            .toList();

        final adherence = PatientData.computeAdherence(doseLogs);
        final missedThisWeek = PatientData.computeMissedDosesThisWeek(doseLogs);

        if (missedThisWeek > 0) {
          missedDosesAlerts.add(
            AlertData(
              patientUid: patientId,
              patientName: patientName,
              alertType: 'missed_doses',
              message:
                  '$missedThisWeek missed dose${missedThisWeek > 1 ? 's' : ''} this week',
              value: missedThisWeek.toDouble(),
              timestamp: DateTime.now(),
            ),
          );
        }

        if (doseLogs.isNotEmpty && adherence < 80) {
          lowAdherenceAlerts.add(
            AlertData(
              patientUid: patientId,
              patientName: patientName,
              alertType: 'low_adherence',
              message:
                  'Overall adherence at ${adherence.toStringAsFixed(0)}%',
              value: adherence,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      missedDosesAlerts.sort((a, b) => (b.value ?? 0).compareTo(a.value ?? 0));
      lowAdherenceAlerts.sort((a, b) => (a.value ?? 0).compareTo(b.value ?? 0));
    } catch (e) {
      print('Error generating alerts: $e');
    }

    return {
      'missed_doses': missedDosesAlerts,
      'low_adherence': lowAdherenceAlerts,
    };
  }
}

class _AlertCard extends StatelessWidget {
  final AlertData alert;
  final VoidCallback onTap;

  const _AlertCard({
    required this.alert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMissedDoses = alert.alertType == 'missed_doses';
    final backgroundColor = isMissedDoses ? Colors.red[50] : Colors.orange[50];
    final borderColor = isMissedDoses ? Colors.red[200] : Colors.orange[200];
    final iconColor = isMissedDoses ? Colors.red[600] : Colors.orange[600];
    final icon = isMissedDoses ? Icons.priority_high : Icons.warning_amber;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor ?? Colors.transparent, width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor?.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
        title: Text(
          alert.patientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.message,
                style: TextStyle(
                  fontSize: 14,
                  color: isMissedDoses ? Colors.red[800] : Colors.orange[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to view patient details',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: iconColor),
      ),
    );
  }
}
