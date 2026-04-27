import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:adhera/services/notification_service.dart';
import 'package:adhera/services/demo_access_service.dart';
import 'package:adhera/services/arabic_localizations.dart';

import 'models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Profil',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDoctorInfoSection(context, user),
            const SizedBox(height: 16),
            Text(
              'Aperçu du cabinet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatsSection(context),
            const SizedBox(height: 16),
            _buildActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorInfoSection(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: user == null
          ? null
          : _firestore.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = (data['name'] as String?)?.trim();
        final doctorName = name?.isNotEmpty == true ? 'Dr. $name' : 'Dr. Unknown';
        final initial =
            doctorName.replaceFirst('Dr. ', '').trim().isNotEmpty
                ? doctorName.replaceFirst('Dr. ', '').trim()[0].toUpperCase()
                : 'D';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer,
                colorScheme.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.08),
                child: Text(
                  initial,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                doctorName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user?.email ?? 'Aucun e-mail',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer.withOpacity(0.78),
                ),
              ),
              const SizedBox(height: 14),
              Chip(
                avatar: const Icon(Icons.local_hospital_outlined, size: 18),
                label: const Text('Médecin'),
                backgroundColor: colorScheme.surface.withOpacity(0.7),
                side: BorderSide.none,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: _computeStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final stats = snapshot.data ??
            {
              'totalPatients': 0,
              'lowAdherenceCount': 0,
              'missedThisWeek': 0,
            };

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    label: 'Nombre total de patients',
                    value: convertArabicToWesternNumbers('${stats['totalPatients']}'),
                    color: Colors.blue,
                    icon: Icons.people_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    label: 'Faible observance',
                    value: convertArabicToWesternNumbers('${stats['lowAdherenceCount']}'),
                    color: Colors.orange,
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.event_busy_outlined,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            convertArabicToWesternNumbers('${stats['missedThisWeek']}'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Patients avec des doses manquées cette semaine',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout),
        label: const Text('Déconnexion'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _computeStats() async {
    try {
      final patientsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();

      final totalPatients = patientsSnapshot.docs.length;
      int lowAdherenceCount = 0;
      int missedThisWeekCount = 0;

      for (final patientDoc in patientsSnapshot.docs) {
        final patientId = patientDoc.id;

        final doseLogsSnapshot = await _firestore
            .collection('users')
            .doc(patientId)
            .collection('doseLogs')
            .get();

        final doseLogs = doseLogsSnapshot.docs
            .map((doc) => DoseLogData.fromMap(doc.data()))
            .toList();

        final adherence = PatientData.computeAdherence(doseLogs);
        if (adherence < 80 && doseLogs.isNotEmpty) {
          lowAdherenceCount++;
        }

        final missedThisWeek = PatientData.computeMissedDosesThisWeek(doseLogs);
        if (missedThisWeek > 0) {
          missedThisWeekCount++;
        }
      }

      return {
        'totalPatients': totalPatients,
        'lowAdherenceCount': lowAdherenceCount,
        'missedThisWeek': missedThisWeekCount,
      };
    } catch (e) {
      print('Error computing stats: $e');
      return {
        'totalPatients': 0,
        'lowAdherenceCount': 0,
        'missedThisWeek': 0,
      };
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Déconnexion ?'),
          content: const Text('Voulez-vous vraiment vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                DemoAccessService.clearDemoSession();
                await _auth.signOut();
                await NotificationService.instance.cancelMedicationReminders();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
