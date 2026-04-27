import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adhera/services/arabic_localizations.dart';
import 'package:adhera/services/localization_service.dart';
import 'models.dart';

class PatientDetailPage extends StatefulWidget {
  final String patientUid;

  const PatientDetailPage({super.key, required this.patientUid});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}
class _PatientDetailPageState extends State<PatientDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _patientTreatmentStart;
  String? _patientPhoneNumber;

  String _formatLocalizedAppointmentDate(DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    return convertArabicToWesternNumbers(
      DateFormat.yMMMd(locale).add_jm().format(dateTime),
    );
  }

  Future<void> _callPatient() async {
    if (_patientPhoneNumber == null || _patientPhoneNumber!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro de téléphone indisponible')),
        );
      }
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: _patientPhoneNumber,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d’ouvrir l’application téléphone')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Détails du patient',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_patientPhoneNumber != null && _patientPhoneNumber!.isNotEmpty)
            IconButton(
              tooltip: 'Appeler le patient',
              onPressed: _callPatient,
              icon: const FaIcon(FontAwesomeIcons.phone, size: 20),
            ),
          IconButton(
            tooltip: 'Ajouter un rendez-vous',
            onPressed: _showAddAppointmentDialog,
            icon: const FaIcon(FontAwesomeIcons.calendarPlus, size: 20),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('users').doc(widget.patientUid).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Patient introuvable'));
          }

          final patientData = PatientData.fromMap(
            widget.patientUid,
            snapshot.data!.data() as Map<String, dynamic>,
          );

          // Store treatment start date and phone number for later use
          _patientTreatmentStart = patientData.treatmentStartDate;
          _patientPhoneNumber = patientData.phoneNumber;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with patient info
                _buildPatientHeader(patientData),
                const SizedBox(height: 24),

                // Key metrics
                _buildKeyMetrics(patientData),
                const SizedBox(height: 24),

                // Weight changes
                _buildRecentWeightChangesSection(),
                const SizedBox(height: 24),

                // Missed doses calendar (180 days)
                _buildMissedDosesCalendar(patientData),
                const SizedBox(height: 24),

                // Medications
                _buildMedicationsSection(),
                const SizedBox(height: 24),

                // Appointments
                _buildAppointmentsSection(),
                const SizedBox(height: 24),

                // Symptom entries
                _buildSymptomsSection(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientHeader(PatientData patient) {
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
              CircleAvatar(
                radius: 30,
                backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.08),
                child: Text(
                  patient.name[0].toUpperCase(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID patient : ${patient.id}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.78),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Téléphone : ${patient.phoneNumber?.isNotEmpty ?? false ? patient.phoneNumber : 'Indisponible'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Phase',
                  patient.currentPhase.toUpperCase(),
                  patient.currentPhase == 'intensive' ? Colors.amber : Colors.blue,
                  isHero: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricBox(
                  'Jours de traitement',
                  convertArabicToWesternNumbers('${DateTime.now().difference(patient.treatmentStartDate).inDays}'),
                  Colors.green,
                  isHero: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    Color color, {
    bool isHero = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHero ? colorScheme.surface.withOpacity(0.45) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isHero
                  ? colorScheme.onPrimaryContainer.withOpacity(0.78)
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHero ? colorScheme.onPrimaryContainer : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(PatientData patient) {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('users')
          .doc(widget.patientUid)
          .collection('doseLogs')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Compute metrics from doseLogs
        final doseLogs = snapshot.data?.docs
                .map((doc) => DoseLogData.fromMap(doc.data() as Map<String, dynamic>))
                .toList() ??
            [];

        final adherence = PatientData.computeAdherence(doseLogs);
        final streak = PatientData.computeStreak(doseLogs);
        final totalMissed = PatientData.computeTotalMissedDoses(doseLogs);
        final missedThisWeek = PatientData.computeMissedDosesThisWeek(doseLogs);

        final adherenceColor = adherence >= 80 ? Colors.green : Colors.orange;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indicateurs clés',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Observance',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            convertArabicToWesternNumbers('${adherence.toStringAsFixed(1)}%'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: adherenceColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: adherence / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(adherenceColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Série actuelle',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            convertArabicToWesternNumbers('$streak'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'jours',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doses manquées au total',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            convertArabicToWesternNumbers('$totalMissed'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manquées cette semaine',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            convertArabicToWesternNumbers('$missedThisWeek'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: missedThisWeek > 0 ? Colors.red : Colors.green,
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

  Widget _buildMissedDosesCalendar(PatientData patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suivi des doses - 180 jours',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.patientUid)
                  .collection('doseLogs')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final doseLogs = snapshot.data?.docs
                        .map((doc) => DoseLogData.fromMap(doc.data() as Map<String, dynamic>))
                        .toList() ??
                    [];

                return _build180DayCalendar(doseLogs);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildDoseLegendItem(
              color: Colors.green,
              label: 'Dose prise',
            ),
            _buildDoseLegendItem(
              color: Colors.red,
              label: 'Dose manquée',
            ),
            _buildDoseLegendItem(
              color: Colors.grey,
              label: 'Pas encore',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoseLegendItem({
    required Color color,
    required String label,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWeightChangesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('recent_weight_changes'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.patientUid)
                  .collection('weightLogs')
                  .orderBy('recordedAt', descending: true)
                  .limit(8)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final entries = snapshot.data?.docs
                        .map((doc) => WeightLogEntry.fromMap(doc.id, doc.data()))
                        .where((entry) => entry.weight > 0)
                        .toList() ??
                    [];

                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        context.t('no_weight_logs'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }

                return Column(
                  children: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final hasPrevious = index < entries.length - 1;
                    final delta = hasPrevious ? item.weight - entries[index + 1].weight : null;
                    final deltaColor = delta == null
                        ? Colors.grey[600]
                        : delta > 0
                            ? Colors.green[700]
                            : delta < 0
                                ? Colors.red[700]
                                : Colors.grey[700];

                    return Padding(
                      padding: EdgeInsets.only(bottom: index == entries.length - 1 ? 0 : 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  convertArabicToWesternNumbers(DateFormat('dd MMM yyyy').format(item.recordedAt)),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (delta != null)
                                  Text(
                                    delta == 0
                                        ? context.t('no_change')
                                        : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${context.t('kg_unit')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: deltaColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${_formatWeightValue(item.weight)} ${context.t('kg_unit')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatWeightValue(double weight) {
    return weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);
  }

  Widget _build180DayCalendar(List<DoseLogData> doseLogs) {
    final treatmentStart = _patientTreatmentStart;
    if (treatmentStart == null) {
      return const Center(child: Text('Date de début du traitement indisponible'));
    }

    final today = DateTime.now();
    final daysToShow = 180;
    const cellSize = 18.0;
    const columnsPerRow = 20;

    // Create a map for quick lookup
    final doseLogMap = <String, bool>{};
    for (var log in doseLogs) {
      doseLogMap[log.date] = log.taken;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: List.generate(
          (daysToShow / columnsPerRow).ceil(),
          (weekIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: List.generate(
                  columnsPerRow,
                  (dayInWeek) {
                    final dayIndex = weekIndex * columnsPerRow + dayInWeek;
                    if (dayIndex >= daysToShow) {
                      return const SizedBox(width: cellSize);
                    }

                    // Calculate the date: treatment start + dayIndex
                    final date = treatmentStart.add(Duration(days: dayIndex));
                    final dateString = DateFormat('yyyy-MM-dd').format(date);
                    final todayString = DateFormat('yyyy-MM-dd').format(today);

                    Color squareColor;
                    
                    // If the date is in the future (after today), show grey
                    if (dateString.compareTo(todayString) > 0) {
                      squareColor = Colors.grey[300]!;
                    } else {
                      // Past or today: check doseLogs
                      if (doseLogMap.containsKey(dateString)) {
                        // Has a dose log entry
                        if (doseLogMap[dateString] == true) {
                          squareColor = Colors.green[300]!;
                        } else {
                          squareColor = Colors.red[300]!;
                        }
                      } else {
                        // No dose log entry for this past/today date - likely missed
                        squareColor = Colors.grey[300]!;
                      }
                    }

                    return Container(
                      width: cellSize,
                      height: cellSize,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: squareColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMedicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Médicaments en cours',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit),
              iconSize: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () {
                _showMedicationEditDialog();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .doc(widget.patientUid)
              .collection('medications')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aucun médicament',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            // Filter medications that are currently active
            final now = DateTime.now();
            final activeMeds = snapshot.data!.docs.where((doc) {
              final medication = Medication.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              return now.isAfter(medication.startDate) &&
                  (medication.endDate == null || now.isBefore(medication.endDate!));
            }).toList();

            if (activeMeds.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aucun médicament actif sur cette période',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            return Column(
              children: activeMeds.map((doc) {
                final medication = Medication.fromMap(doc.id, doc.data() as Map<String, dynamic>);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
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
                                    medication.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    medication.dosage,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                medication.frequency,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (medication.notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Notes : ${medication.notes}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Début : ${convertArabicToWesternNumbers(DateFormat('MMM dd, yyyy').format(medication.startDate))}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        if (medication.endDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Fin : ${convertArabicToWesternNumbers(DateFormat('MMM dd, yyyy').format(medication.endDate!))}',
                              style: TextStyle(fontSize: 11, color: Colors.orange[600]),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSymptomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Entrées de symptômes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .doc(widget.patientUid)
              .collection('symptomLogs')
              .orderBy('date', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aucune entrée de symptôme',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final symptom = SymptomEntry.fromMap(doc.data() as Map<String, dynamic>);
                final severityColor = _getSeverityColor(symptom.severity);
                final severityLabel = _getSeverityLabel(symptom.severity);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              convertArabicToWesternNumbers(DateFormat('dd MMM yyyy').format(symptom.date).toString()),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: severityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                convertArabicToWesternNumbers('${symptom.severity}/10 - $severityLabel'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: severityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: symptom.symptoms.map((s) {
                            return Chip(
                              label: Text(
                                _translateSymptomName(s),
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.grey[200],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }).toList(),
                        ),
                        if (symptom.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notes : ${symptom.notes}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rendez-vous',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('users')
              .doc(widget.patientUid)
              .collection('appointments')
              .orderBy('dateTime')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aucun rendez-vous prévu',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            final now = DateTime.now();
            final appointments = snapshot.data!.docs
                .map((doc) => AppointmentData.fromMap(doc.id, doc.data()))
                .toList();

            return Column(
              children: appointments.map((appointment) {
                final isPast = appointment.dateTime.isBefore(now);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                appointment.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isPast
                                    ? Colors.grey.withOpacity(0.12)
                                    : appointment.addedToCalendar
                                        ? Colors.green.withOpacity(0.12)
                                        : Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isPast
                                    ? 'Passé'
                                    : appointment.addedToCalendar
                                        ? 'Dans le calendrier'
                                        : 'En attente dans le calendrier',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPast
                                      ? Colors.grey[700]
                                      : appointment.addedToCalendar
                                          ? Colors.green[700]
                                          : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatLocalizedAppointmentDate(appointment.dateTime),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        if (appointment.notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            appointment.notes.trim(),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showMedicationEditDialog() {
    showDialog(
      context: context,
      builder: (context) => MedicationEditDialog(
        patientUid: widget.patientUid,
        firestore: _firestore,
      ),
    );
  }

  void _showAddAppointmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAppointmentDialog(
        patientUid: widget.patientUid,
        firestore: _firestore,
      ),
    );
  }

  Color _getSeverityColor(int severity) {
    if (severity <= 3) return Colors.green;
    if (severity <= 6) return Colors.orange;
    return Colors.red;
  }

  String _getSeverityLabel(int severity) {
    if (severity <= 3) return 'Léger';
    if (severity <= 6) return 'Modéré';
    return 'Sévère';
  }

  String _translateSymptomName(String symptom) {
    final normalized = symptom.trim().toLowerCase();
    const mapping = <String, String>{
      'nausea': 'nausea',
      'cough': 'cough',
      'vomiting': 'vomiting',
      'fever': 'fever',
      'fatigue': 'fatigue',
      'chest pain': 'chest_pain',
      'shortness of breath': 'shortness_of_breath',
      'night sweats': 'night_sweats',
      'غثيان': 'nausea',
      'سعال': 'cough',
      'قيء': 'vomiting',
      'حمى': 'fever',
      'إرهاق': 'fatigue',
      'ألم في الصدر': 'chest_pain',
      'ضيق في التنفس': 'shortness_of_breath',
      'تعرق ليلي': 'night_sweats',
      'nausée': 'nausea',
      'toux': 'cough',
      'vomissement': 'vomiting',
      'fièvre': 'fever',
      'douleur thoracique': 'chest_pain',
      'essoufflement': 'shortness_of_breath',
      'sueurs nocturnes': 'night_sweats',
    };

    final key = mapping[normalized] ?? normalized.replaceAll(' ', '_');
    final translated = context.t(key);
    return translated == key ? symptom : translated;
  }
}

class AddAppointmentDialog extends StatefulWidget {
  final String patientUid;
  final FirebaseFirestore firestore;

  const AddAppointmentDialog({
    super.key,
    required this.patientUid,
    required this.firestore,
  });

  @override
  State<AddAppointmentDialog> createState() => _AddAppointmentDialogState();
}

class _AddAppointmentDialogState extends State<AddAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  bool _isSaving = false;

  String _formatLocalizedAppointmentDate(DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    return convertArabicToWesternNumbers(
      DateFormat.yMMMd(locale).add_jm().format(dateTime),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date et une heure futures')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final appointment = AppointmentData(
        id: '',
        title: _titleController.text.trim(),
        dateTime: _selectedDateTime,
        notes: _notesController.text.trim(),
        addedToCalendar: false,
      );

      await widget.firestore
          .collection('users')
          .doc(widget.patientUid)
          .collection('appointments')
          .add(appointment.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rendez-vous ajouté')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l’ajout du rendez-vous : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajouter un rendez-vous',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Le titre est requis' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date et heure',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatLocalizedAppointmentDate(_selectedDateTime)),
                      const Icon(Icons.calendar_today_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveAppointment,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MedicationEditDialog extends StatefulWidget {
  final String patientUid;
  final FirebaseFirestore firestore;

  const MedicationEditDialog({
    super.key,
    required this.patientUid,
    required this.firestore,
  });

  @override
  State<MedicationEditDialog> createState() => _MedicationEditDialogState();
}

class _MedicationEditDialogState extends State<MedicationEditDialog> {
  late Future<List<Medication>> _medicationsFuture;

  @override
  void initState() {
    super.initState();
    _medicationsFuture = _loadMedications();
  }

  Future<List<Medication>> _loadMedications() async {
    final snapshot = await widget.firestore
        .collection('users')
        .doc(widget.patientUid)
        .collection('medications')
        .get();

    return snapshot.docs
        .map((doc) => Medication.fromMap(doc.id, doc.data()))
        .toList();
  }

  void _showAddMedicationDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMedicationDialog(
        patientUid: widget.patientUid,
        firestore: widget.firestore,
        onMedicationAdded: () {
          setState(() {
            _medicationsFuture = _loadMedications();
          });
        },
      ),
    );
  }

  void _showEditMedicationDialog(Medication medication) {
    showDialog(
      context: context,
      builder: (context) => EditMedicationDialog(
        patientUid: widget.patientUid,
        firestore: widget.firestore,
        medication: medication,
        onMedicationUpdated: () {
          setState(() {
            _medicationsFuture = _loadMedications();
          });
        },
      ),
    );
  }

  void _deleteMedication(String medicationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Supprimer le médicament'),
        content: const Text('Voulez-vous vraiment supprimer ce médicament ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              await widget.firestore
                  .collection('users')
                  .doc(widget.patientUid)
                  .collection('medications')
                  .doc(medicationId)
                  .delete();
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  _medicationsFuture = _loadMedications();
                });
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Modifier les médicaments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Medication>>(
                future: _medicationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun médicament',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  final medications = snapshot.data!;

                  return ListView.builder(
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final medication = medications[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(medication.name),
                          subtitle: Text(
                            '${medication.dosage} • ${medication.frequency}',
                          ),
                          trailing: SizedBox(
                            width: 100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showEditMedicationDialog(medication),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _deleteMedication(medication.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddMedicationDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un médicament'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddMedicationDialog extends StatefulWidget {
  final String patientUid;
  final FirebaseFirestore firestore;
  final VoidCallback onMedicationAdded;

  const AddMedicationDialog({
    super.key,
    required this.patientUid,
    required this.firestore,
    required this.onMedicationAdded,
  });

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveMedication() async {
      if (_nameController.text.isEmpty ||
        _dosageController.text.isEmpty ||
        _frequencyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
      );
      return;
    }

    final medication = Medication(
      id: '',
      name: _nameController.text,
      dosage: _dosageController.text,
      frequency: _frequencyController.text,
      notes: _notesController.text,
      startDate: _startDate,
      endDate: _endDate,
      isActive: true,
    );

    try {
      await widget.firestore
          .collection('users')
          .doc(widget.patientUid)
          .collection('medications')
          .add(medication.toMap());

      if (mounted) {
        Navigator.pop(context);
        widget.onMedicationAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ajouter un médicament',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du médicament *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage *',
                  hintText: 'ex. 250 mg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _frequencyController,
                decoration: const InputDecoration(
                  labelText: 'Fréquence *',
                  hintText: 'ex. deux fois par jour',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date de début : ${convertArabicToWesternNumbers(DateFormat('MMM dd, yyyy').format(_startDate))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _startDate = date);
                            }
                          },
                          child: const Text('Modifier'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date de fin : ${_endDate == null ? 'Aucune' : convertArabicToWesternNumbers(DateFormat('MMM dd, yyyy').format(_endDate!))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: _startDate,
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() => _endDate = date);
                            }
                          },
                          child: const Text('Définir'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveMedication,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditMedicationDialog extends StatefulWidget {
  final String patientUid;
  final FirebaseFirestore firestore;
  final Medication medication;
  final VoidCallback onMedicationUpdated;

  const EditMedicationDialog({
    super.key,
    required this.patientUid,
    required this.firestore,
    required this.medication,
    required this.onMedicationUpdated,
  });

  @override
  State<EditMedicationDialog> createState() => _EditMedicationDialogState();
}

class _EditMedicationDialogState extends State<EditMedicationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _frequencyController;
  late TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication.name);
    _dosageController = TextEditingController(text: widget.medication.dosage);
    _frequencyController =
        TextEditingController(text: widget.medication.frequency);
    _notesController = TextEditingController(text: widget.medication.notes);
    _startDate = widget.medication.startDate;
    _endDate = widget.medication.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateMedication() async {
    if (_nameController.text.isEmpty ||
        _dosageController.text.isEmpty ||
        _frequencyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
      );
      return;
    }

    final medication = Medication(
      id: widget.medication.id,
      name: _nameController.text,
      dosage: _dosageController.text,
      frequency: _frequencyController.text,
      notes: _notesController.text,
      startDate: _startDate,
      endDate: _endDate,
      isActive: widget.medication.isActive,
    );

    try {
      await widget.firestore
          .collection('users')
          .doc(widget.patientUid)
          .collection('medications')
          .doc(widget.medication.id)
          .update(medication.toMap());

      if (mounted) {
        Navigator.pop(context);
        widget.onMedicationUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Modifier le médicament',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du médicament *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage *',
                  hintText: 'ex. 250 mg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _frequencyController,
                decoration: const InputDecoration(
                  labelText: 'Fréquence *',
                  hintText: 'ex. deux fois par jour',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date de début : ${convertArabicToWesternNumbers(DateFormat('MMM dd, yyyy').format(_startDate))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _startDate = date);
                            }
                          },
                          child: const Text('Modifier'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date de fin : ${_endDate == null ? 'Aucune' : convertArabicToWesternNumbers(DateFormat('MMM dd, yyyy').format(_endDate!))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: _startDate,
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() => _endDate = date);
                            }
                          },
                          child: const Text('Définir'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _updateMedication,
                    child: const Text('Mettre à jour'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
