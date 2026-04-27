import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gpassword/gpassword.dart';
import 'package:adhera/services/arabic_localizations.dart';
import 'models.dart';
import 'patient_detail.dart';

class PatientListPage extends StatefulWidget {
  const PatientListPage({super.key});

  @override
  State<PatientListPage> createState() => _PatientListPageState();
}
class _PatientListPageState extends State<PatientListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Patients attribués',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildPatientList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientDialog(),
        tooltip: 'Ajouter un patient',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPatientList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.people_rounded,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun patient attribué',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final patients = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: patients.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        'Aperçu des patients',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${convertArabicToWesternNumbers('${patients.length}')} patient${patients.length == 1 ? '' : 's'} actuellement attribué${patients.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final patientDoc = patients[index - 1];
            final patientData = PatientData.fromMap(
              patientDoc.id,
              patientDoc.data(),
            );

            return _PatientCard(
              patientUid: patientData.uid,
              patient: patientData,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PatientDetailPage(patientUid: patientData.uid),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddPatientDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddPatientDialog(),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient ajouté avec succès')),
        );
      }
    });
  }
}

class _PatientCard extends StatelessWidget {
  final String patientUid;
  final PatientData patient;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patientUid,
    required this.patient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<QuerySnapshot>(
      future: firestore
          .collection('users')
          .doc(patientUid)
          .collection('doseLogs')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                height: 100,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        // Compute metrics from doseLogs
        final doseLogs =
            snapshot.data?.docs
                .map(
                  (doc) =>
                      DoseLogData.fromMap(doc.data() as Map<String, dynamic>),
                )
                .toList() ??
            [];

        final adherence = PatientData.computeAdherence(doseLogs);
        final streak = PatientData.computeStreak(doseLogs);
        final adherenceColor = adherence >= 80 ? Colors.green : Colors.orange;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            patient.name.isNotEmpty
                                ? patient.name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${patient.id}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: patient.currentPhase == 'intensive'
                              ? Colors.amber.withOpacity(0.16)
                              : Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          patient.currentPhase.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: patient.currentPhase == 'intensive'
                                ? Colors.amber[900]
                                : Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Observance',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              convertArabicToWesternNumbers('${adherence.toStringAsFixed(0)}%'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  adherenceColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Série',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${convertArabicToWesternNumbers('$streak')} jours',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AddPatientDialog extends StatefulWidget {
  const AddPatientDialog({super.key});

  @override
  State<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<AddPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _phoneController;

  String _selectedSex = 'Homme';
  DateTime _selectedStartDate = DateTime.now();
  List<Medication> _medications = [];
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final gpassword = GPassword();
    final newPassword = gpassword.generate(
      passwordLength: 8,
      includeUppercase: true,
      includeLowercase: true,
      includeNumbers: true,
      includeSymbols: false,
    );
    setState(() {
      _passwordController.text = newPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajouter un nouveau patient',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'E-mail requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              tooltip: _showPassword
                                  ? 'Masquer le mot de passe'
                                  : 'Afficher le mot de passe',
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _generatePassword,
                              tooltip: 'Générer un mot de passe à 8 chiffres',
                            ),
                          ],
                        ),
                      ),
                      obscureText: !_showPassword,
                      validator: (value) =>
                          (value?.length ?? 0) < 6 ? '6 caractères minimum' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom complet',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        hintText: '+1234567890',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            decoration: InputDecoration(
                              labelText: 'Âge',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSex,
                            decoration: InputDecoration(
                              labelText: 'Sexe',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            items: ['Homme', 'Femme']
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedSex = value ?? 'Homme'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _weightController,
                      decoration: InputDecoration(
                        labelText: 'Poids (kg)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.45),
                      title: const Text('Date de début du traitement'),
                      subtitle: Text(_selectedStartDate.toString().split(' ')[0]),
                      onTap: () => _selectDate(),
                      trailing: const Icon(Icons.calendar_today_outlined),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Médicaments',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () => _showAddMedicationDialog(),
                        ),
                      ],
                    ),
                    if (_medications.isNotEmpty)
                      Column(
                        children: _medications.asMap().entries.map((entry) {
                          int idx = entry.key;
                          Medication med = entry.value;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              title: Text(med.name),
                              subtitle: Text(
                                '${med.dosage} - ${med.frequency}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _medications.removeAt(idx)),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Aucun médicament ajouté pour le moment',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _addPatient,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ajouter un patient'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedStartDate = picked);
    }
  }

  void _showAddMedicationDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMedicationDialog(
        onAdd: (medication) {
          setState(() => _medications.add(medication));
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _addPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = userCredential.user!.uid;

      // Create user document in Firestore
      await _firestore.collection('users').doc(uid).set({
        'role': 'patient',
        'name': _nameController.text,
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'age': int.tryParse(_ageController.text),
        'sex': _selectedSex,
        'weight': double.tryParse(_weightController.text),
        'tbTreatmentStart': Timestamp.fromDate(_selectedStartDate),
        'currentPhase': 'intensive',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add medications
      if (_medications.isNotEmpty) {
        final medicationsRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('medications');
        for (var med in _medications) {
          await medicationsRef.add(med.toMap());
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class AddMedicationDialog extends StatefulWidget {
  final Function(Medication) onAdd;

  const AddMedicationDialog({super.key, required this.onAdd});

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _frequencyController;
  late TextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();
    _frequencyController = TextEditingController();
    _notesController = TextEditingController();
    _selectedStartDate = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajouter un médicament',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    FormField<String>(
                      initialValue: _nameController.text,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Nom du médicament requis'
                          : null,
                      builder: (FormFieldState<String> field) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Autocomplete<String>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }

                                    const medications = [
                                      'ERIP K4',
                                      'RINIAZIDE',
                                      'Cortancyl',
                                    ];
                                    return medications.where(
                                      (med) => med.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                    );
                                  },
                              onSelected: (String selection) {
                                setState(
                                  () => _nameController.text = selection,
                                );
                                field.didChange(selection);
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    controller.value = _nameController.value;
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Nom du médicament',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        errorText: field.errorText,
                                      ),
                                      onChanged: (value) {
                                        _nameController.value = controller.value;
                                        field.didChange(
                                          value,
                                        );
                                      },
                                    );
                                  },
                            ),
                            if (field.errorText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  field.errorText!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dosageController,
                      decoration:  InputDecoration(
                        labelText: 'Dosage (ex. 300 mg)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Dosage requis' : null,
                    ),
                    const SizedBox(height: 12),
                    FormField<String>(
                      initialValue: _frequencyController.text,
                      validator: (value) => _frequencyController.text.isEmpty
                          ? 'Fréquence requise'
                          : null,
                      builder: (FormFieldState<String> field) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<String>.empty();
                                }

                                final input = textEditingValue.text
                                    .toLowerCase();
                                const commonFrequencies = [
                                  '1 fois/jour',
                                  '2 fois/jour',
                                  '3 fois/jour',
                                  '4 fois/jour',
                                  'Une fois par jour',
                                  'Deux fois par jour',
                                  'Trois fois par jour',
                                ];

                                // If input is a number, suggest number + x/day
                                if (RegExp(r'^\d+$').hasMatch(input)) {
                                  return ['${input} fois/jour'];
                                }

                                // Otherwise filter common frequencies
                                return commonFrequencies.where(
                                  (freq) => freq.toLowerCase().contains(input),
                                );
                              },
                              onSelected: (String selection) {
                                setState(
                                  () => _frequencyController.text = selection,
                                );
                                field.didChange(selection);
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    controller.value =
                                        _frequencyController.value;
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Fréquence (ex. 1 fois/jour)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        errorText: field.errorText,
                                      ),
                                      onChanged: (value) {
                                        _frequencyController.value =
                                            controller.value;
                                        field.didChange(value);
                                      },
                                    );
                                  },
                            ),
                            if (field.errorText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  field.errorText!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (facultatives)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.45),
                      title: const Text('Date de début'),
                      subtitle: Text(
                        _selectedStartDate != null
                            ? _selectedStartDate.toString().split(' ')[0]
                            : 'Aucune date sélectionnée',
                      ),
                      onTap: _selectStartDate,
                      trailing: const Icon(Icons.calendar_today),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.45),
                      title: const Text('Date de fin (facultative)'),
                      subtitle: Text(
                        _selectedEndDate != null
                            ? _selectedEndDate.toString().split(' ')[0]
                            : 'Aucune date de fin',
                      ),
                      onTap: _selectEndDate,
                      trailing: const Icon(Icons.calendar_today),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _addMedication,
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addMedication() {
    if (!_formKey.currentState!.validate()) return;

    final medication = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      dosage: _dosageController.text,
      frequency: _frequencyController.text,
      notes: _notesController.text,
      startDate: _selectedStartDate ?? DateTime.now(),
      endDate: _selectedEndDate,
      isActive: true,
    );

    widget.onAdd(medication);
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedStartDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedEndDate = picked);
    }
  }
}
