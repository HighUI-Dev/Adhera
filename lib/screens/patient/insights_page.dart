import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhera/services/localization_service.dart';
import 'package:adhera/services/arabic_localizations.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(context.t('please_sign_in'))),
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
          final treatmentStartTimestamp = userData['tbTreatmentStart'];
          final treatmentStartDate = treatmentStartTimestamp is Timestamp
              ? treatmentStartTimestamp.toDate()
              : null;

          final doseLogsStream = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('doseLogs')
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: doseLogsStream,
            builder: (context, doseLogsSnapshot) {
              if (doseLogsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final metrics = _computeMetrics(
                treatmentStartDate: treatmentStartDate,
                docs: doseLogsSnapshot.data?.docs ?? const [],
              );

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        context.t('statistics'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${context.t('day')} ${convertArabicToWesternNumbers('${metrics.daysIntoTreatment}')}${context.t('of_180')}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.92,
                        children: [
                          _buildStatCard(
                            context,
                            label: context.t('adherence_30d'),
                            value: convertArabicToWesternNumbers('${metrics.adherence30dPercent}%'),
                            icon: Icons.insights_outlined,
                            color: Colors.blue,
                          ),
                          _buildStatCard(
                            context,
                            label: context.t('overall_adherence'),
                            value: convertArabicToWesternNumbers('${metrics.overallAdherencePercent}%'),
                            icon: Icons.show_chart_outlined,
                            color: Colors.teal,
                          ),
                          _buildStatCard(
                            context,
                            label: context.t('current_streak'),
                            value: convertArabicToWesternNumbers('${metrics.currentStreak}') + ' ${context.t('days')}',
                            icon: Icons.local_fire_department_outlined,
                            color: Colors.orange,
                          ),
                          _buildStatCard(
                            context,
                            label: context.t('missed_doses_30d'),
                            value: convertArabicToWesternNumbers('${metrics.missedDoses30d}'),
                            icon: Icons.event_busy_outlined,
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.t('phase_progress'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildPhaseProgressCard(
                        context,
                        phaseName: context.t('intensive_phase'),
                        completed: metrics.daysIntoTreatment,
                        total: 60,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 12),
                      _buildPhaseProgressCard(
                        context,
                        phaseName: context.t('continuation_phase'),
                        completed: (metrics.daysIntoTreatment - 60).clamp(
                          0,
                          120,
                        ),
                        total: 120,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  _InsightsMetrics _computeMetrics({
    required DateTime? treatmentStartDate,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    final today = _normalizeDate(DateTime.now());
    final normalizedStart = treatmentStartDate == null
        ? today
        : _normalizeDate(treatmentStartDate);
    final effectiveStart = normalizedStart.isAfter(today)
        ? today
        : normalizedStart;

    final doseStatusByDate = <String, bool>{};
    for (final doc in docs) {
      final data = doc.data();
      final date = data['date'] as String?;
      if (date == null || date.isEmpty) {
        continue;
      }
      doseStatusByDate[date] = data['taken'] == true;
    }

    final thirtyDayWindowStart = today.subtract(const Duration(days: 29));
    final effective30dStart = effectiveStart.isAfter(thirtyDayWindowStart)
        ? effectiveStart
        : thirtyDayWindowStart;

    int taken30d = 0;
    int missed30d = 0;
    for (
      DateTime day = effective30dStart;
      !day.isAfter(today);
      day = day.add(const Duration(days: 1))
    ) {
      final status = doseStatusByDate[DateFormat('yyyy-MM-dd').format(day)];
      if (status == true) {
        taken30d++;
      } else {
        missed30d++;
      }
    }

    int takenOverall = 0;
    for (
      DateTime day = effectiveStart;
      !day.isAfter(today);
      day = day.add(const Duration(days: 1))
    ) {
      final status = doseStatusByDate[DateFormat('yyyy-MM-dd').format(day)];
      if (status == true) {
        takenOverall++;
      }
    }

    final streak = _calculateStreakFromLogs(docs);

    final total30dDays = _inclusiveDaysBetween(effective30dStart, today);
    final totalTreatmentDays = _inclusiveDaysBetween(effectiveStart, today);

    return _InsightsMetrics(
      adherence30dPercent: total30dDays > 0
          ? ((taken30d / total30dDays) * 100).round()
          : 0,
      overallAdherencePercent: totalTreatmentDays > 0
          ? ((takenOverall / totalTreatmentDays) * 100).round()
          : 0,
      currentStreak: streak,
      missedDoses30d: missed30d,
      daysIntoTreatment: totalTreatmentDays,
    );
  }

  int _calculateStreakFromLogs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sortedDocs =
        docs.where((doc) {
          final date = doc.data()['date'] as String?;
          return date != null && date.isNotEmpty;
        }).toList()
          ..sort((a, b) {
            final aDate = a.data()['date'] as String? ?? '';
            final bDate = b.data()['date'] as String? ?? '';
            return bDate.compareTo(aDate);
          });

    int streak = 0;
    for (final doc in sortedDocs) {
      final taken = doc.data()['taken'] == true;
      if (taken) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseProgressCard(
    BuildContext context, {
    required String phaseName,
    required int completed,
    required int total,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayedCompleted = completed.clamp(0, total);
    final progress = total == 0 ? 0.0 : displayedCompleted / total;
    final progressPercent = (progress * 100).toStringAsFixed(0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.timelapse_outlined, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phaseName,
                        maxLines: 2,
                        softWrap: true,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$displayedCompleted / $total ${context.t('days')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$progressPercent%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _inclusiveDaysBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      return 0;
    }
    return end.difference(start).inDays + 1;
  }
}

class _InsightsMetrics {
  const _InsightsMetrics({
    required this.adherence30dPercent,
    required this.overallAdherencePercent,
    required this.currentStreak,
    required this.missedDoses30d,
    required this.daysIntoTreatment,
  });

  final int adherence30dPercent;
  final int overallAdherencePercent;
  final int currentStreak;
  final int missedDoses30d;
  final int daysIntoTreatment;
}
