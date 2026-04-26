import 'package:cloud_firestore/cloud_firestore.dart';

class PatientData {
  final String uid;
  final String name;
  final String id; // Patient ID
  final String currentPhase; // 'intensive' or 'continuation'
  final DateTime treatmentStartDate;
  final int? age;
  final String? sex;
  final double? weight;
  final String? phoneNumber;

  // Computed fields (calculated from doseLogs)
  late final double adherencePercentage;
  late final int streak;
  late final int totalMissedDoses;
  late final int missedDosesThisWeek;

  PatientData({
    required this.uid,
    required this.name,
    required this.id,
    required this.currentPhase,
    required this.treatmentStartDate,
    this.age,
    this.sex,
    this.weight,
    this.phoneNumber,
  });

  factory PatientData.fromMap(String uid, Map<String, dynamic> data) {
    return PatientData(
      uid: uid,
      name: data['name'] ?? 'Unknown',
      id: data['patientId'] ?? uid.substring(0, 8),
      currentPhase: data['currentPhase'] ?? 'intensive',
      treatmentStartDate: data['tbTreatmentStart'] != null
          ? (data['tbTreatmentStart'] as dynamic).toDate()
          : DateTime.now(),
      age: data['age'] as int?,
      sex: data['sex'] as String?,
      weight: (data['weight'] as num?)?.toDouble(),
      phoneNumber: data['phoneNumber'] as String?,
    );
  }

  // Helper methods to compute metrics from doseLogs
  static double computeAdherence(List<DoseLogData> doseLogs) {
    if (doseLogs.isEmpty) return 0;
    final taken = doseLogs.where((log) => log.taken).length;
    return (taken / doseLogs.length) * 100;
  }

  static int computeStreak(List<DoseLogData> doseLogs) {
    if (doseLogs.isEmpty) return 0;

    // Sort by date descending (most recent first)
    final sorted = List<DoseLogData>.from(doseLogs);
    sorted.sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    for (var log in sorted) {
      if (log.taken) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static int computeTotalMissedDoses(List<DoseLogData> doseLogs) {
    return doseLogs.where((log) => !log.taken).length;
  }

  static int computeMissedDosesThisWeek(List<DoseLogData> doseLogs) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return doseLogs
        .where((log) {
          try {
            final logDate = DateTime.parse(log.date);
            return logDate.isAfter(weekAgo) && !log.taken;
          } catch (e) {
            return false;
          }
        })
        .length;
  }
}

class Medication {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final String notes;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.notes,
    required this.startDate,
    this.endDate,
    required this.isActive,
  });

  factory Medication.fromMap(String id, Map<String, dynamic> data) {
    return Medication(
      id: id,
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      frequency: data['frequency'] ?? '',
      notes: data['notes'] ?? '',
      startDate: data['startDate'] != null
          ? (data['startDate'] as dynamic).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null ? (data['endDate'] as dynamic).toDate() : null,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'notes': notes,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive,
    };
  }
}

class DoseLogData {
  final String date;
  final bool taken;
  final DateTime? missedTime;

  DoseLogData({
    required this.date,
    required this.taken,
    this.missedTime,
  });

  factory DoseLogData.fromMap(Map<String, dynamic> data) {
    return DoseLogData(
      date: data['date'] ?? '',
      taken: data['taken'] ?? false,
      missedTime: data['missedTime'] != null
          ? (data['missedTime'] as dynamic).toDate()
          : null,
    );
  }
}

class WeightLogEntry {
  final String id;
  final double weight;
  final DateTime recordedAt;

  WeightLogEntry({
    required this.id,
    required this.weight,
    required this.recordedAt,
  });

  factory WeightLogEntry.fromMap(String id, Map<String, dynamic> data) {
    final rawRecordedAt = data['recordedAt'];
    final rawCreatedAt = data['createdAt'];

    DateTime recordedAt = DateTime.now();
    if (rawRecordedAt is Timestamp) {
      recordedAt = rawRecordedAt.toDate();
    } else if (rawCreatedAt is Timestamp) {
      recordedAt = rawCreatedAt.toDate();
    }

    return WeightLogEntry(
      id: id,
      weight: (data['weight'] as num?)?.toDouble() ?? 0,
      recordedAt: recordedAt,
    );
  }
}

class SymptomEntry {
  final DateTime date;
  final List<String> symptoms;
  final int severity;
  final String notes;

  SymptomEntry({
    required this.date,
    required this.symptoms,
    required this.severity,
    required this.notes,
  });

  factory SymptomEntry.fromMap(Map<String, dynamic> data) {
    final rawDate = data['date'];

    return SymptomEntry(
      date: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
      symptoms: List<String>.from(data['symptoms'] ?? []),
      severity: (data['severity'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String? ?? '',
    );
  }
}

class AlertData {
  final String patientUid;
  final String patientName;
  final String alertType; // 'low_adherence', 'missed_doses'
  final String message;
  final double? value; // adherence percentage or number of missed doses
  final DateTime timestamp;

  AlertData({
    required this.patientUid,
    required this.patientName,
    required this.alertType,
    required this.message,
    this.value,
    required this.timestamp,
  });
}

class AppointmentData {
  final String id;
  final String title;
  final DateTime dateTime;
  final String notes;
  final bool addedToCalendar;
  final DateTime? createdAt;

  AppointmentData({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.notes,
    required this.addedToCalendar,
    this.createdAt,
  });

  factory AppointmentData.fromMap(String id, Map<String, dynamic> data) {
    final rawDateTime = data['dateTime'];
    final rawCreatedAt = data['createdAt'];

    return AppointmentData(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Appointment',
      dateTime: rawDateTime is Timestamp ? rawDateTime.toDate() : DateTime.now(),
      notes: (data['notes'] as String?)?.trim() ?? '',
      addedToCalendar: data['addedToCalendar'] == true,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'notes': notes,
      'addedToCalendar': addedToCalendar,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
    };
  }
}
