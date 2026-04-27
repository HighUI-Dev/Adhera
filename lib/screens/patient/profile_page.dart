import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhera/services/arabic_localizations.dart';
import 'package:adhera/services/localization_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSavingWeight = false;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          context.t('profile'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton(
              tooltip: context.t('track_weight'),
              onPressed: _isSavingWeight ? null : () => _showWeightEntryDialog(user.uid),
              child: const Icon(Icons.monitor_weight_outlined),
            ),
      body: user == null
          ? Center(child: Text(context.t('please_log_in')))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text(context.t('patient_profile_not_found')));
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
                        name: name ?? context.t('unknown_patient'),
                        email: email ?? user.email ?? context.t('no_email'),
                        currentPhase: currentPhase ?? 'intensive',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              context,
                              label: context.t('age'),
                              value: age?.toString() ?? context.t('not_set'),
                              icon: Icons.cake_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              context,
                              label: context.t('sex'),
                              value: _formatSex(context, sex),
                              icon: _sexIcon(sex),
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
                              label: context.t('weight'),
                              value: _formatWeight(context, weight),
                              icon: Icons.monitor_weight_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              context,
                              label: context.t('treatment_start'),
                              value: _formatDate(context, treatmentStart),
                              icon: Icons.event_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(context, context.t('treatment_overview')),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        context,
                        children: [
                          _buildDetailRow(
                            context.t('current_phase'),
                            _formatPhase(context, currentPhase),
                          ),
                          _buildDetailRow(
                            context.t('email'),
                            email ?? user.email ?? context.t('no_email'),
                          ),
                          _buildDetailRow(
                            context.t('day_in_treatment'),
                            _formatTreatmentDay(context, treatmentStart),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(context, context.t('recent_weight_changes')),
                      const SizedBox(height: 12),
                      _buildWeightHistory(user.uid),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showWeightEntryDialog(String uid) async {
    final weightController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? validationError;

    final result = await showDialog<_WeightEntryInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.t('log_weight')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.t('weight_value_kg'),
                      hintText: '70.5',
                      errorText: validationError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${context.t('recorded_on')}: ${convertArabicToWesternNumbers(DateFormat('MMM d, yyyy', Localizations.localeOf(context).toString()).format(selectedDate))}',
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Text(context.t('select_date')),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.t('cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(
                      weightController.text.trim().replaceAll(',', '.'),
                    );

                    if (parsed == null || parsed <= 0) {
                      setDialogState(() {
                        validationError = context.t('enter_valid_weight');
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _WeightEntryInput(weight: parsed, recordedAt: selectedDate),
                    );
                  },
                  child: Text(context.t('save_weight')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await _saveWeight(uid, result.weight, result.recordedAt);
  }

  Future<void> _saveWeight(String uid, double weight, DateTime recordedAt) async {
    setState(() {
      _isSavingWeight = true;
    });

    try {
      final userRef = _firestore.collection('users').doc(uid);
      final logRef = userRef.collection('weightLogs').doc();

      final batch = _firestore.batch();
      batch.set(
        userRef,
        {
          'weight': weight,
          'weightUpdatedAt': Timestamp.fromDate(recordedAt),
        },
        SetOptions(merge: true),
      );
      batch.set(logRef, {
        'weight': weight,
        'recordedAt': Timestamp.fromDate(recordedAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('weight_saved'))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('weight_save_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWeight = false;
        });
      }
    }
  }

  Widget _buildWeightHistory(String uid) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('users')
              .doc(uid)
              .collection('weightLogs')
              .orderBy('recordedAt', descending: true)
              .limit(6)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.t('no_weight_logs'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              );
            }

            final rows = docs
                .map((doc) => _WeightLogRow.fromMap(doc.data()))
                .whereType<_WeightLogRow>()
                .toList();

            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.t('no_weight_logs'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              );
            }

            return Column(
              children: rows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final isLast = index == rows.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          convertArabicToWesternNumbers(DateFormat(
                            'MMM d, yyyy',
                            Localizations.localeOf(context).toString(),
                          ).format(row.recordedAt)),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${_formatWeightValue(row.weight)} ${context.t('kg_unit')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
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
            label: Text(_formatPhase(context, currentPhase)),
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

  String _formatPhase(BuildContext context, String? phase) {
    if (phase == null || phase.isEmpty) return context.t('not_set');
    final normalized = phase.toLowerCase();
    if (normalized == 'intensive') return context.t('intensive_phase');
    if (normalized == 'continuation') return context.t('continuation_phase');
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String _formatWeight(BuildContext context, dynamic weight) {
    if (weight == null) return context.t('not_set');
    if (weight is num) return '${_formatWeightValue(weight.toDouble())} ${context.t('kg_unit')}';
    return '$weight ${context.t('kg_unit')}';
  }

  String _formatWeightValue(double value) {
    final hasFraction = value % 1 != 0;
    return convertArabicToWesternNumbers(
      hasFraction ? value.toStringAsFixed(1) : value.toInt().toString(),
    );
  }

  String _formatDate(BuildContext context, dynamic timestamp) {
    if (timestamp is Timestamp) {
      return convertArabicToWesternNumbers(DateFormat(
        'MMM d, yyyy',
        Localizations.localeOf(context).toString(),
      ).format(timestamp.toDate()));
    }
    return context.t('not_set');
  }

  String _formatTreatmentDay(BuildContext context, dynamic timestamp) {
    if (timestamp is! Timestamp) return context.t('not_started');
    final start = timestamp.toDate();
    final startDate = DateTime(start.year, start.month, start.day);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final day = todayDate.difference(startDate).inDays + 1;
    return day > 0
        ? convertArabicToWesternNumbers("${context.t('day')} $day${context.t('of_180')}")
        : context.t('not_started');
  }

  String _formatSex(BuildContext context, String? sex) {
    if (sex == null || sex.trim().isEmpty) return context.t('not_set');

    final normalized = sex.trim().toLowerCase();
    if (normalized == 'male' ||
        normalized == 'm' ||
        normalized == 'homme' ||
        normalized == 'ذكر') {
      return context.t('sex_male');
    }
    if (normalized == 'female' ||
        normalized == 'f' ||
        normalized == 'femme' ||
        normalized == 'أنثى') {
      return context.t('sex_female');
    }
    return sex;
  }

  IconData _sexIcon(String? sex) {
    if (sex == null || sex.trim().isEmpty) return Icons.wc_outlined;
    final normalized = sex.trim().toLowerCase();
    if (normalized == 'male' ||
        normalized == 'm' ||
        normalized == 'homme' ||
        normalized == 'ذكر') {
      return Icons.male_rounded;
    }
    if (normalized == 'female' ||
        normalized == 'f' ||
        normalized == 'femme' ||
        normalized == 'أنثى') {
      return Icons.female_rounded;
    }
    return Icons.wc_outlined;
  }
}

class _WeightEntryInput {
  final double weight;
  final DateTime recordedAt;

  const _WeightEntryInput({required this.weight, required this.recordedAt});
}

class _WeightLogRow {
  final double weight;
  final DateTime recordedAt;

  const _WeightLogRow({required this.weight, required this.recordedAt});

  static _WeightLogRow? fromMap(Map<String, dynamic> data) {
    final weightRaw = data['weight'];
    final recordedAtRaw = data['recordedAt'];

    final weight = (weightRaw as num?)?.toDouble();
    DateTime? recordedAt;

    if (recordedAtRaw is Timestamp) {
      recordedAt = recordedAtRaw.toDate();
    }

    if (weight == null || recordedAt == null) {
      return null;
    }

    return _WeightLogRow(weight: weight, recordedAt: recordedAt);
  }
}
