import 'package:add_2_calendar_new/add_2_calendar_new.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:adhera/screens/doctor/models.dart';
import 'package:adhera/services/notification_service.dart';

import 'settings_page.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  bool? _doseLogTaken;
  String? _todayLogId;
  String _patientFirstName = '';
  List<Medication> _todayMedications = [];
  int _streak = 0;
  DateTime? _treatmentStartDate;
  List<AppointmentData> _appointments = [];
  bool _isLoading = true;
  bool _yesterdayDialogShown = false;
  bool _appointmentDialogShown = false;

  @override
  void initState() {
    super.initState();
    _fetchTreatmentStartDate();
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

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchTreatmentStartDate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc['tbTreatmentStart'] != null) {
          setState(() {
            _treatmentStartDate = (userDoc['tbTreatmentStart'] as Timestamp)
                .toDate();
            _patientFirstName = _extractFirstName(userDoc['name'] as String?);
          });
          await _fetchTodayMedications();
          await _fetchTodayDoseLog();
          await _calculateStreakFromLogs();
          await _loadAppointments();
          await _checkYesterdayStatus();
          if (!_yesterdayDialogShown) {
            await _checkPendingAppointments();
          }
        }
      }
    } catch (e) {
      print('Error fetching treatment start date: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving dose log: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reverting choice: $e')));
      }
    }
  }

  Future<void> _checkYesterdayStatus() async {
    try {
      if (_yesterdayDialogShown) {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _treatmentStartDate != null) {
        final today = _dateOnly(DateTime.now());
        final treatmentStartDate = _dateOnly(_treatmentStartDate!);
        final yesterday = today.subtract(const Duration(days: 1));

        if (yesterday.isBefore(treatmentStartDate)) {
          return;
        }

        final yesterdayString = DateFormat('yyyy-MM-dd').format(yesterday);

        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('doseLogs')
            .where('date', isEqualTo: yesterdayString)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty ||
            querySnapshot.docs.first['taken'] != true) {
          if (mounted) {
            _showYesterdayDialog();
          }
        }
      }
    } catch (e) {
      print('Error checking yesterday status: $e');
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appointments')
          .orderBy('dateTime')
          .get();

      final appointments = snapshot.docs
          .map((doc) => AppointmentData.fromMap(doc.id, doc.data()))
          .toList();

      if (mounted) {
        setState(() {
          _appointments = appointments;
        });
      }
    } catch (e) {
      print('Error loading appointments: $e');
    }
  }

  Future<void> _checkPendingAppointments() async {
    if (_appointmentDialogShown) {
      return;
    }

    final now = DateTime.now();
    final nextAppointment = _appointments.cast<AppointmentData?>().firstWhere(
      (appointment) =>
          appointment != null &&
          !appointment.addedToCalendar &&
          appointment.dateTime.isAfter(now),
      orElse: () => null,
    );

    if (nextAppointment == null || !mounted) {
      return;
    }

    _appointmentDialogShown = true;
    _showAppointmentCalendarDialog(nextAppointment);
  }

  Future<void> _showAppointmentCalendarDialog(
    AppointmentData appointment,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Upcoming Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat(
                  'EEE, MMM d, yyyy • h:mm a',
                ).format(appointment.dateTime),
              ),
              if (appointment.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(appointment.notes.trim()),
              ],
              const SizedBox(height: 12),
              const Text(
                'Would you like to add this appointment to your phone calendar?',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _addAppointmentToCalendar(appointment);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    _appointmentDialogShown = false;
  }

  Future<void> _addAppointmentToCalendar(AppointmentData appointment) async {
    try {
      final event = Event(
        title: appointment.title,
        description: appointment.notes,
        startDate: appointment.dateTime,
        endDate: appointment.dateTime.add(const Duration(hours: 1)),
      );

      final added = await Add2Calendar.addEvent2Cal(event);

      if (!added) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment was not added to the calendar yet'),
            ),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('appointments')
            .doc(appointment.id)
            .update({'addedToCalendar': true});
      }

      await _loadAppointments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment sent to calendar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add appointment to calendar: $e')),
        );
      }
    }
  }

  void _showYesterdayDialog() {
    _yesterdayDialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Yesterday\'s Medication'),
          content: const Text(
            'Did you take your medication yesterday or did you miss it?',
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateYesterdayLog(true);
              },
              child: const Text('Taken'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateYesterdayLog(false);
              },
              child: const Text('Missed'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateYesterdayLog(bool taken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayString = DateFormat('yyyy-MM-dd').format(yesterday);

        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('doseLogs')
            .where('date', isEqualTo: yesterdayString)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('doseLogs')
              .doc(querySnapshot.docs.first.id)
              .update({'taken': taken});
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('doseLogs')
              .add({
                'date': yesterdayString,
                'taken': taken,
                'timestamp': FieldValue.serverTimestamp(),
              });
        }

        await _calculateStreakFromLogs();
        await _loadAppointments();
        await _checkPendingAppointments();
      }
    } catch (e) {
      print('Error updating yesterday log: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating yesterday log: $e')),
        );
      }
    }
  }

  int _getDaysIntoTreatment() {
    if (_treatmentStartDate == null) {
      return 0;
    }
    return DateTime.now().difference(_treatmentStartDate!).inDays + 1;
  }

  int _getDaysLeft() {
    if (_treatmentStartDate == null) {
      return 0;
    }
    final totalDays = 180;
    return (totalDays - _getDaysIntoTreatment()).clamp(0, totalDays);
  }

  bool _isIntensivePhase() {
    return _getDaysIntoTreatment() <= 60;
  }

  String _getPhaseName() {
    return _isIntensivePhase() ? 'Intensive Phase' : 'Continuation Phase';
  }

  String _getPhaseLabel() {
    return _isIntensivePhase() ? 'ERIP - 2 months' : 'RI - 4 months';
  }

  Color _getPhaseColor() {
    return _isIntensivePhase() ? Colors.amber : Colors.green;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final suffix = _patientFirstName.isEmpty ? '' : ' $_patientFirstName';

    if (hour >= 5 && hour < 12) {
      return 'Good morning$suffix';
    }
    if (hour >= 12 && hour < 17) {
      return 'Good afternoon$suffix';
    }
    return 'Good evening$suffix';
  }

  String _getTodayDate() {
    return DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await NotificationService.instance.cancelMedicationReminders();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    }
  }

  int _getCompletedMedications() {
    return _doseLogTaken == true ? 1 : 0;
  }

  int _getTotalMedications() {
    return 1;
  }

  String _formatAppointmentDate(DateTime dateTime) {
    return DateFormat('EEE, MMM d, yyyy • h:mm a').format(dateTime);
  }

  Widget _buildMedicationItem(Medication medication) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final details = <String>[
      medication.dosage,
      medication.frequency,
      if (medication.notes.trim().isNotEmpty) medication.notes.trim(),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _getPhaseColor().withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.medication_liquid_outlined,
              color: _getPhaseColor(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.join(' • '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        PopupMenuButton(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (value) {
                            if (value == 'settings') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            } else if (value == 'logout') {
                              _logout();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'settings',
                              child: Text('Settings'),
                            ),
                            PopupMenuItem(
                              value: 'logout',
                              child: Text('Logout'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildHeroCard(context),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            label: 'Today\'s Dose',
                            value:
                                '${_getCompletedMedications()}/${_getTotalMedications()}',
                            icon: Icons.check_circle_outline,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            label: 'Current Streak',
                            value: '${_streak}d',
                            icon: Icons.local_fire_department_outlined,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMedicationCard(context),
                    const SizedBox(height: 16),
                    _buildAppointmentsCard(context),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.local_hospital_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPhaseName(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getPhaseLabel(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  context,
                  label: 'Day',
                  value: '${_getDaysIntoTreatment()}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeroStat(
                  context,
                  label: 'Days Left',
                  value: '${_getDaysLeft()}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withOpacity(0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
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
            const SizedBox(height: 18),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
                    color: _getPhaseColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    color: _getPhaseColor(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Medication',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _todayMedications.isEmpty
                            ? 'No active medications scheduled today'
                            : '${_todayMedications.length} medication${_todayMedications.length == 1 ? '' : 's'} scheduled',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                /*Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getPhaseColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.fire,
                        size: 14,
                        color: _getPhaseColor(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_streak}d streak',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _getPhaseColor(),
                        ),
                      ),
                    ],
                  ),
                ),*/
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: colorScheme.onSurfaceVariant.withOpacity(0.12)),
            const SizedBox(height: 8),
            if (_todayMedications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No active medications for today.',
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
                  label: const Text('Mark as Taken'),
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
                          child: Text(
                            'Marked as taken for today',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
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
                      label: const Text('Revert Choice'),
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

  Widget _buildAppointmentsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

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
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.event_note_outlined,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointments',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _appointments.isEmpty
                            ? 'No appointments scheduled'
                            : '${_appointments.length} appointment${_appointments.length == 1 ? '' : 's'} available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_appointments.isEmpty)
              Text(
                'Your doctor has not added any appointments yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: _appointments.map((appointment) {
                  final isPast = appointment.dateTime.isBefore(now);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPast
                            ? colorScheme.surfaceContainerHighest.withOpacity(
                                0.35,
                              )
                            : Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  appointment.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!isPast)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appointment.addedToCalendar
                                        ? Colors.green.withOpacity(0.12)
                                        : Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    appointment.addedToCalendar
                                        ? 'In calendar'
                                        : 'Needs add',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: appointment.addedToCalendar
                                          ? Colors.green
                                          : Colors.orange[800],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatAppointmentDate(appointment.dateTime),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (appointment.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              appointment.notes.trim(),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          if (!isPast && !appointment.addedToCalendar) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _addAppointmentToCalendar(appointment),
                                icon: const Icon(
                                  Icons.event_available_outlined,
                                ),
                                label: const Text('Add to Calendar'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
