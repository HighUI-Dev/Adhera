import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhera/services/arabic_localizations.dart';
import 'package:adhera/services/demo_access_service.dart';
import 'package:adhera/services/localization_service.dart';

class SymptomsPage extends StatefulWidget {
  const SymptomsPage({super.key});

  @override
  State<SymptomsPage> createState() => _SymptomsPageState();
}

class _SymptomsPageState extends State<SymptomsPage> {
  bool _isArabicLocale(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: user == null
            ? Center(child: Text(context.t('please_log_in')))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('symptomLogs')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final logs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: logs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: _isArabicLocale(context)
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                context.t('symptoms'),
                                textAlign: _isArabicLocale(context)
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${logs.length} ${logs.length == 1 ? context.t('entry') : context.t('entries')}',
                                textAlign: _isArabicLocale(context)
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final doc = logs[index - 1];
                      final docId = doc.id;
                      final data = doc.data();
                      final date = (data['date'] as Timestamp).toDate();
                      final symptoms = List<String>.from(data['symptoms'] ?? []);
                      final severity = (data['severity'] ?? 5).toInt();
                      final notes = data['notes'] ?? '';

                      return _buildSymptomCard(
                        context,
                        docId,
                        date,
                        symptoms,
                        severity,
                        notes,
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEntryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                context.t('symptoms'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.t('no_entries_yet'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.health_and_safety_outlined,
                          size: 32,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t('no_symptoms_logged_yet'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('tap_add_to_record_symptoms'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomCard(
    BuildContext context,
    String docId,
    DateTime date,
    List<String> symptoms,
    int severity,
    String notes,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = convertArabicToWesternNumbers(
      DateFormat(
        'MMM d, yyyy',
        Localizations.localeOf(context).toString(),
      ).format(date),
    );
    final severityColor = _getSeverityColor(severity);
    final severityLabel = _getSeverityLabel(severity);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.favorite_outline, color: severityColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${symptoms.length} ${context.t('symptoms_logged')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(docId),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                convertArabicToWesternNumbers('$severity/10 - $severityLabel'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: severityColor,
                ),
              ),
            ),
            if (symptoms.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: symptoms
                    .map(
                      (symptom) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.t(_normalizeSymptomKey(symptom)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('notes'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(notes, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(int severity) {
    if (severity <= 3) return Colors.green;
    if (severity <= 6) return Colors.orange;
    return Colors.red;
  }

  String _getSeverityLabel(int severity) {
    if (severity <= 3) return context.t('mild');
    if (severity <= 6) return context.t('moderate');
    return context.t('severe');
  }

  String _normalizeSymptomKey(String symptom) {
    final normalized = symptom.trim().toLowerCase();
    const map = <String, String>{
      'nausea': 'nausea',
      'cough': 'cough',
      'vomiting': 'vomiting',
      'fever': 'fever',
      'fatigue': 'fatigue',
      'chest pain': 'chest_pain',
      'shortness of breath': 'shortness_of_breath',
      'night sweats': 'night_sweats',
      'chest_pain': 'chest_pain',
      'shortness_of_breath': 'shortness_of_breath',
      'night_sweats': 'night_sweats',
    };
    return map[normalized] ?? symptom;
  }

  void _showEntryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SymptomEntryDialog(),
    );
  }

  void _showDeleteConfirmation(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('delete_entry')),
        content: Text(
          context.t('delete_symptom_message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSymptomLog(docId);
            },
            child: Text(
              context.t('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSymptomLog(String docId) async {
    if (DemoAccessService.isCurrentUserDemo()) {
      if (mounted) {
        DemoAccessService.showReadOnlyMessage(context);
      }
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('symptomLogs')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('symptom_log_deleted'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text("${context.t('error_deleting_log')}: $e")),
        );
      }
    }
  }
}

class SymptomEntryDialog extends StatefulWidget {
  const SymptomEntryDialog({super.key});

  @override
  State<SymptomEntryDialog> createState() => _SymptomEntryDialogState();
}

class _SymptomEntryDialogState extends State<SymptomEntryDialog> {
  static const List<String> availableSymptoms = [
    'nausea',
    'cough',
    'vomiting',
    'fever',
    'fatigue',
    'chest_pain',
    'shortness_of_breath',
    'night_sweats',
  ];

  late DateTime selectedDate;
  Set<String> selectedSymptoms = {};
  int severity = 5;
  String notes = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        context.t('log_symptoms'),
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      convertArabicToWesternNumbers(DateFormat(
                        'MMM d, yyyy',
                        Localizations.localeOf(context).toString(),
                      ).format(selectedDate)),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('select_symptoms'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSymptoms
                  .map(
                    (symptom) => ChoiceChip(
                      label: Text(context.t(symptom)),
                      selected: selectedSymptoms.contains(symptom),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      selectedColor: colorScheme.primaryContainer,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedSymptoms.add(symptom);
                          } else {
                            selectedSymptoms.remove(symptom);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('severity'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(convertArabicToWesternNumbers('$severity/10')),
                    Text(
                      _getSeverityLabel(severity),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _getSeverityColor(severity),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: severity.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) {
                    setState(() {
                      severity = value.toInt();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.t('notes_optional'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: context.t('add_notes'),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
              onChanged: (value) {
                notes = value;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('cancel')),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveSymptomLog,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.t('save')),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _saveSymptomLog() async {
    if (DemoAccessService.isCurrentUserDemo()) {
      if (mounted) {
        DemoAccessService.showReadOnlyMessage(context);
      }
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('user_not_logged_in'))));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final entryDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
        now.microsecond,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('symptomLogs')
          .add({
            'date': Timestamp.fromDate(entryDate),
            'loggedForDate': DateFormat('yyyy-MM-dd').format(selectedDate),
            'symptoms': selectedSymptoms.toList(),
            'severity': severity,
            'notes': notes,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('symptom_log_saved'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text("${context.t('error_saving_log')}: $e")),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getSeverityColor(int severity) {
    if (severity <= 3) return Colors.green;
    if (severity <= 6) return Colors.orange;
    return Colors.red;
  }

  String _getSeverityLabel(int severity) {
    if (severity <= 3) return context.t('mild');
    if (severity <= 6) return context.t('moderate');
    return context.t('severe');
  }
}
