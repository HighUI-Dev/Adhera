import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhera/services/localization_service.dart';

class TreatmentPage extends StatefulWidget {
  const TreatmentPage({super.key});

  @override
  State<TreatmentPage> createState() => _TreatmentPageState();
}

class _TreatmentPageState extends State<TreatmentPage>
    with SingleTickerProviderStateMixin {
  static const int _totalTreatmentDays = 180;

  late TabController _tabController;
  final GlobalKey _todayCardKey = GlobalKey();
  DateTime? _treatmentStartDate;
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _doseLogs = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _doseLogsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchTreatmentStartDate();
  }

  @override
  void dispose() {
    _doseLogsSubscription?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 0 && !_tabController.indexIsChanging) {
      _scrollToToday();
    }
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
            _treatmentStartDate =
                (userDoc['tbTreatmentStart'] as Timestamp).toDate();
          });
          _listenToDoseLogs();
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
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

  void _listenToDoseLogs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    _doseLogsSubscription?.cancel();
    _doseLogsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('doseLogs')
        .snapshots()
        .listen(
      (logsSnapshot) {
        final logs = <String, Map<String, dynamic>>{};
        for (final doc in logsSnapshot.docs) {
          final data = doc.data();
          final date = data['date'];
          if (date is String) {
            logs[date] = {
              'taken': data['taken'] ?? false,
              'timestamp': data['timestamp'],
            };
          }
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _doseLogs = logs;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
      },
      onError: (Object error) {
        print('Error listening to dose logs: $error');
      },
    );
  }

  int _getDaysIntoTreatment() {
    if (_treatmentStartDate == null) {
      return 0;
    }
    final today = _dateOnly(DateTime.now());
    final startDate = _dateOnly(_treatmentStartDate!);
    return today.difference(startDate).inDays + 1;
  }

  bool _isIntensivePhase(int dayNumber) {
    return dayNumber <= 60;
  }

  String _getMedicationName(int dayNumber) {
    return _isIntensivePhase(dayNumber)
        ? context.t('erip_k4')
        : context.t('riniazide');
  }

  bool _isMedicationTaken(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    return _doseLogs[dateString]?['taken'] ?? false;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _getPhase2StartDate() {
    if (_treatmentStartDate == null) {
      return DateTime.now();
    }
    return _treatmentStartDate!.add(const Duration(days: 60));
  }

  DateTime _getTreatmentEndDate() {
    if (_treatmentStartDate == null) {
      return DateTime.now();
    }
    return _treatmentStartDate!
        .add(const Duration(days: _totalTreatmentDays - 1));
  }

  void _scrollToToday() {
    final context = _todayCardKey.currentContext;
    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          context.t('treatment'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.t('calendar')),
            Tab(text: context.t('protocol')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarPage(),
                _buildProtocolPage(),
              ],
            ),
    );
  }

  Widget _buildCalendarPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendarSummaryCard(),
          const SizedBox(height: 16),
          _buildCalendarDays(),
        ],
      ),
    );
  }

  Widget _buildCalendarSummaryCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final daysIntoTreatment = _getDaysIntoTreatment().clamp(0, _totalTreatmentDays);
    final daysRemaining = (_totalTreatmentDays - daysIntoTreatment).clamp(
      0,
      _totalTreatmentDays,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('treatment_calendar'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('track_treatment_journey'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    context,
                    label: context.t('day'),
                    value: '$daysIntoTreatment',
                    icon: Icons.today_outlined,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryMetric(
                    context,
                    label: context.t('remaining'),
                    value: '$daysRemaining',
                    icon: Icons.timelapse_outlined,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildCalendarDays() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_treatmentStartDate == null) {
      return const SizedBox.shrink();
    }

    final List<Widget> dayCards = [];
    final startDate = _dateOnly(_treatmentStartDate!);
    final today = _dateOnly(DateTime.now());

    for (int i = 0; i < _totalTreatmentDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dayNumber = i + 1;
      final dayOfWeek = DateFormat('EEE').format(date);
      final dayOfMonth = DateFormat('d').format(date);
      final medicationName = _getMedicationName(dayNumber);
      final isTaken = _isMedicationTaken(date);
      final isToday = _dateOnly(date) == today;
      final isFutureDay = date.isAfter(today);

      final statusIcon = isFutureDay
          ? Icons.radio_button_unchecked
          : isTaken
              ? Icons.check_circle_rounded
              : Icons.close_rounded;
      final statusColor = isFutureDay
          ? Colors.grey
          : isTaken
              ? Colors.green
              : Colors.red;

      dayCards.add(
        Card(
          key: isToday ? _todayCardKey : null,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: isToday
              ? const Color(0xfffff1c9)
              : colorScheme.surfaceContainerHighest.withOpacity(0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isToday ? Colors.amber.shade300 : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isFutureDay ? 0.10 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayOfWeek,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        dayOfMonth,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.t('day')} $dayNumber',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicationName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.t('today'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('daily_timeline'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...dayCards,
      ],
    );
  }

  Widget _buildProtocolPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineContainer(),
          const SizedBox(height: 16),
          _buildEducationalPhaseCard(
            title: context.t('phase_1_intensive'),
            goal: context.t('phase_1_goal'),
            accentColor: Colors.amber,
            backgroundColor: const Color(0xfffceed9),
            sections: [
              (
                context.t('what_this_means_for_you'),
                [
                  context.t('phase_1_feel_better'),
                  context.t('phase_1_symptoms_improve'),
                  context.t('phase_1_treatment_must_continue'),
                ],
              ),
              (
                context.t('why_multiple_medications'),
                [
                  context.t('phase_1_kill_faster'),
                  context.t('phase_1_prevent_resistance'),
                  context.t('phase_1_complete_recovery'),
                ],
              ),
              (
                context.t('what_you_may_notice'),
                [
                  context.t('phase_1_improvement_in_symptoms'),
                  context.t('phase_1_possible_side_effects'),
                ],
              ),
            ],
            importantNote: context.t('phase_1_important_note'),
          ),
          const SizedBox(height: 16),
          _buildEducationalPhaseCard(
            title: context.t('phase_2_continuation'),
            goal: context.t('phase_2_goal'),
            accentColor: Colors.green,
            backgroundColor: const Color(0xffd4f4dd),
            sections: [
              (
                context.t('what_this_means_for_you'),
                [
                  context.t('phase_2_feel_better'),
                  context.t('phase_2_fewer_medications'),
                  context.t('phase_2_complete_cure'),
                ],
              ),
              (
                context.t('why_continue_treatment'),
                [
                  context.t('phase_2_bacteria_remain'),
                  context.t('phase_2_harder_to_kill'),
                  context.t('phase_2_relapse_if_stop_early'),
                ],
              ),
              (
                context.t('what_you_may_notice'),
                [
                  context.t('phase_2_symptoms_mostly_gone'),
                  context.t('phase_2_routine_feels_easier'),
                ],
              ),
            ],
            importantNote: context.t('phase_2_important_note'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContainer() {
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
            Text(
              context.t('your_treatment_timeline'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineRow(
              context.t('start_date'),
              _formatDate(_treatmentStartDate),
            ),
            const SizedBox(height: 12),
            _buildTimelineRow(
              context.t('phase_2_begins'),
              _formatDate(_getPhase2StartDate()),
            ),
            const SizedBox(height: 12),
            _buildTimelineRow(
              context.t('expected_end'),
              _formatDate(_getTreatmentEndDate()),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _getDaysIntoTreatment().clamp(0, _totalTreatmentDays) /
                    _totalTreatmentDays,
                minHeight: 12,
                backgroundColor: colorScheme.primary.withOpacity(0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalPhaseCard({
    required String title,
    required String goal,
    required Color backgroundColor,
    required Color accentColor,
    required List<(String, List<String>)> sections,
    required String importantNote,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildEducationBlock(
              title: context.t('goal'),
              items: [goal],
              accentColor: accentColor,
            ),
            const SizedBox(height: 16),
            ...sections.expand(
              (section) => [
                _buildEducationBlock(
                  title: section.$1,
                  items: section.$2,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 16),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('important'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          importantNote,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationBlock({
    required String title,
    required List<String> items,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_outlined, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return context.t('not_set');
    }
    return DateFormat('MMM d, yyyy').format(date);
  }
}
