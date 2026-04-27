import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhera/screens/doctor/models.dart';
import 'package:adhera/services/arabic_localizations.dart';
import 'package:adhera/services/localization_service.dart';
import 'package:adhera/services/notification_service.dart';
import 'patient_home.dart';

class TrackingSimpleMode extends StatefulWidget {
  const TrackingSimpleMode({super.key});

  @override
  State<TrackingSimpleMode> createState() => _TrackingSimpleModeState();
}

class _TrackingSimpleModeState extends State<TrackingSimpleMode> {
  List<Medication> _todayMedications = [];
  bool _isLoading = true;
  bool? _doseLogTaken;
  String? _todayLogId;
  int _streak = 0;
  String _patientFirstName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _patientFirstName = _extractFirstName(userDoc['name'] as String?);
          });
        }

        await Future.wait([
          _fetchTodayMedications(),
          _fetchTodayDoseLog(),
          _calculateStreakFromLogs(),
        ]);
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _extractFirstName(String? fullName) {
    if (fullName == null) {
      return '';
    }

    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      return '';
    }

    return trimmedName.split(RegExp(r'\s+')).first;
  }

  Future<void> _fetchTodayMedications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .where('isActive', isEqualTo: true)
          .get();

      final medications =
          snapshot.docs
              .map((doc) => Medication.fromMap(doc.id, doc.data()))
              .where((medication) {
                final start = DateTime(
                  medication.startDate.year,
                  medication.startDate.month,
                  medication.startDate.day,
                );
                final end = medication.endDate == null
                    ? null
                    : DateTime(
                        medication.endDate!.year,
                        medication.endDate!.month,
                        medication.endDate!.day,
                      );

                final started = !today.isBefore(start);
                final notEnded = end == null || !today.isAfter(end);
                return started && notEnded;
              })
              .toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));

      if (mounted) {
        setState(() {
          _todayMedications = medications;
        });
      }
    } catch (e) {
      print('Error fetching today\'s medications: $e');
    }
  }

  Future<void> _fetchTodayDoseLog() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());

        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('doseLogs')
            .where('date', isEqualTo: todayString)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            _todayLogId = querySnapshot.docs.first.id;
            _doseLogTaken = querySnapshot.docs.first['taken'] ?? false;
          });
        } else {
          setState(() {
            _doseLogTaken = null;
            _todayLogId = null;
          });
        }
      }
    } catch (e) {
      print('Error fetching today\'s dose log: $e');
    }
  }

  Future<void> _calculateStreakFromLogs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final logsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('doseLogs')
            .orderBy('date', descending: true)
            .get();

        int streak = 0;
        for (final doc in logsSnapshot.docs) {
          final taken = doc['taken'] ?? false;
          if (taken) {
            streak++;
          } else {
            break;
          }
        }

        if (mounted) {
          setState(() {
            _streak = streak;
          });
        }
      }
    } catch (e) {
      print('Error calculating streak: $e');
    }
  }

  Future<void> _saveDoseLog(bool taken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());

        if (_todayLogId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('doseLogs')
              .doc(_todayLogId)
              .update({'taken': taken});
        } else {
          final newDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('doseLogs')
              .add({
                'date': todayString,
                'taken': taken,
                'timestamp': FieldValue.serverTimestamp(),
              });

          setState(() {
            _todayLogId = newDoc.id;
          });
        }

        setState(() {
          _doseLogTaken = taken;
        });

        await _calculateStreakFromLogs();
        await NotificationService.instance.syncForCurrentUser();
      }
    } catch (e) {
      print('Error saving dose log: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${context.t('error_saving_dose_log')}: $e")),
        );
      }
    }
  }

  Future<void> _revertChoice() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _todayLogId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('doseLogs')
            .doc(_todayLogId)
            .delete();

        setState(() {
          _doseLogTaken = null;
          _todayLogId = null;
        });

        await _calculateStreakFromLogs();
        await NotificationService.instance.syncForCurrentUser();
      }
    } catch (e) {
      print('Error reverting choice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${context.t('error_reverting_choice')}: $e")),
        );
      }
    }
  }

  Future<void> _exitSimpleMode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'useSimpleMode': false});
      }
    } catch (e) {
      print('Error exiting simple mode: $e');
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PatientHome()),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final suffix = _patientFirstName.isEmpty ? '' : ' $_patientFirstName';

    if (hour >= 5 && hour < 12) {
      return "${context.t('good_morning')}$suffix";
    }
    if (hour >= 12 && hour < 17) {
      return "${context.t('good_afternoon')}$suffix";
    }
    return "${context.t('good_evening')}$suffix";
  }

  String _getTodayDate() {
    final locale = Localizations.localeOf(context).toString();
    return convertArabicToWesternNumbers(
      DateFormat('EEEE, MMMM d, yyyy', locale).format(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getTodayDate(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _getGreeting(),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _exitSimpleMode,
                          icon: const Icon(Icons.close),
                          tooltip: context.t('exit_simple_mode'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildHeroCard(context),
                    const SizedBox(height: 16),
                    _buildMedicationCard(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.onPrimaryContainer.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.health_and_safety_outlined,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('simple_mode'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.t('todays_medication'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('todays_medication'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _todayMedications.isEmpty
                            ? context.t('no_active_medications_scheduled_today')
                            : "${_todayMedications.length} ${_todayMedications.length == 1 ? context.t('medication_scheduled_singular') : context.t('medication_scheduled_plural')}",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: colorScheme.onSurfaceVariant.withOpacity(0.12)),
            const SizedBox(height: 8),
            if (_todayMedications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.t('no_active_medications_for_today'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: _todayMedications.map(_buildMedicationItem).toList(),
              ),
            const SizedBox(height: 18),
            if (_doseLogTaken == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _saveDoseLog(true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(context.t('mark_taken'), style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else if (_doseLogTaken == true)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('marked_as_taken_for_today'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${context.t('current_streak')}: $_streak ${context.t('days')}",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _revertChoice,
                      icon: const Icon(Icons.undo),
                      label: Text(context.t('revert_choice')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationItem(Medication medication) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasNotes = medication.notes.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.primary.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medication.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${medication.dosage} • ${medication.frequency}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasNotes) ...[
              const SizedBox(height: 6),
              Text(
                medication.notes.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
