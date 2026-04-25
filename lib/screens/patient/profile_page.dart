import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: user == null
            ? null
            : FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Patient profile not found.'));
          }

          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final name = (data['name'] as String?)?.trim();
          final email = (data['email'] as String?)?.trim();
          final age = data['age'];
          final sex = (data['sex'] as String?)?.trim();
          final currentPhase = (data['currentPhase'] as String?)?.trim();
          final weight = data['weight'];
          final treatmentStart = data['tbTreatmentStart'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(
                  context,
                  name: name ?? 'Unknown Patient',
                  email: email ?? user?.email ?? 'No email',
                  currentPhase: currentPhase ?? 'intensive',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        label: 'Age',
                        value: age?.toString() ?? 'Not set',
                        icon: Icons.cake_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        label: 'Sex',
                        value: sex?.isNotEmpty == true ? sex! : 'Not set',
                        icon: Icons.wc_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        label: 'Weight',
                        value: _formatWeight(weight),
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        label: 'Treatment Start',
                        value: _formatDate(treatmentStart),
                        icon: Icons.event_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionTitle(context, 'Treatment Overview'),
                const SizedBox(height: 12),
                _buildDetailCard(
                  context,
                  children: [
                    _buildDetailRow('Current Phase', _formatPhase(currentPhase)),
                    _buildDetailRow('Email', email ?? user?.email ?? 'No email'),
                    _buildDetailRow(
                      'Day in Treatment',
                      _formatTreatmentDay(treatmentStart),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required String name,
    required String email,
    required String currentPhase,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P';

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
            name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withOpacity(0.78),
            ),
          ),
          const SizedBox(height: 14),
          Chip(
            avatar: const Icon(Icons.local_hospital_outlined, size: 18),
            label: Text(_formatPhase(currentPhase)),
            backgroundColor: colorScheme.surface.withOpacity(0.7),
            side: BorderSide.none,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String label,
    required String value,
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
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
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

  Widget _buildDetailCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPhase(String? phase) {
    if (phase == null || phase.isEmpty) return 'Not set';
    final normalized = phase.toLowerCase();
    if (normalized == 'intensive') return 'Intensive Phase';
    if (normalized == 'continuation') return 'Continuation Phase';
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String _formatWeight(dynamic weight) {
    if (weight == null) return 'Not set';
    if (weight is int) return '$weight kg';
    if (weight is double) {
      final hasFraction = weight % 1 != 0;
      return hasFraction ? '${weight.toStringAsFixed(1)} kg' : '${weight.toInt()} kg';
    }
    return '$weight kg';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM d, yyyy').format(timestamp.toDate());
    }
    return 'Not set';
  }

  String _formatTreatmentDay(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Not started';
    final start = timestamp.toDate();
    final startDate = DateTime(start.year, start.month, start.day);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final day = todayDate.difference(startDate).inDays + 1;
    return day > 0 ? 'Day $day of 180' : 'Not started';
  }
}
