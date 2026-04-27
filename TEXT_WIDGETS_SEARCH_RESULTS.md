# Text Widgets Displaying Dates or Numbers - Search Results

## Summary
Found Text widgets displaying dates, day counts, dose numbers, and other numeric values across patient-facing screens in the TB Life application.

---

## 1. **treatment_page.dart** - Treatment Calendar & Protocol Pages

### Day Count & Number Display:
| Line | Description | Widget |
|------|-------------|--------|
| 391 | **Day number display** | `Text(value, ...)` in `_buildSummaryMetric()` - displays `$daysIntoTreatment` |
| 399 | **Label for day count** | `Text(label, style: theme.textTheme.bodyMedium)` - displays "day" label |
| 468 | **Day of week formatting** | `Text(dayOfWeek, ...)` - formatted via `DateFormat('EEE', locale).format(date)` |
| 475 | **Day of month (date)** | `Text(dayOfMonth, ...)` - formatted via `DateFormat('d', locale).format(date)` |
| 490 | **Day number in calendar** | `Text('${_tr('day')} $dayNumber', ...)` - displays "Day 1", "Day 2", etc. |
| 514 | **"Today" indicator** | `Text(_tr('today'), ...)` - status badge for current day |

### Timeline Dates:
| Line | Description | Widget |
|------|-------------|--------|
| 660 | **Treatment start date** | `_formatDate(_treatmentStartDate)` via `_buildTimelineRow()` |
| 665 | **Phase 2 start date** | `_formatDate(_getPhase2StartDate())` via `_buildTimelineRow()` |
| 670 | **Expected end date** | `_formatDate(_getTreatmentEndDate())` via `_buildTimelineRow()` |

### Date Formatting Functions:
| Line | Function | Details |
|------|----------|---------|
| 865-870 | `_formatDate(DateTime? date)` | Formats dates as `'MMM d, yyyy'` using `DateFormat()` with locale |
| 231 | `_isMedicationTaken(DateTime date)` | Uses `DateFormat('yyyy-MM-dd').format(date)` to format dates for lookup |
| 421-422 | Calendar loop formatting | Uses `DateFormat('EEE', locale)` and `DateFormat('d', locale)` |

---

## 2. **tracking_page.dart** - Patient Home/Tracking Screen

### Day & Appointment Metrics:
| Line | Description | Widget |
|------|-------------|--------|
| 747-754 | **Days into treatment** | `Text(_getDaysIntoTreatment())` - displays current day number |
| 789-796 | **Days remaining** | `Text(_getDaysLeft())` - displays remaining days |
| 1039-1047 | **Todays dose completion** | `Text('${_getCompletedMedications()}/${_getTotalMedications()}')` - e.g., "1/1" |
| 1090-1097 | **Current streak** | `Text('$_streak' + 'd')` - displays streak in days, e.g., "5d" |

### Appointment Date/Time Display:
| Line | Description | Widget |
|------|-------------|--------|
| 436 | **Appointment title** | `Text(appointment.title, ...)` |
| **436-437** | **Appointment date-time** | `Text(_formatAppointmentDate(appointment.dateTime), ...)` |
| 1343 | **Appointment date-time** | `Text(_formatAppointmentDate(appointment.dateTime), ...)` - formatted via `DateFormat.yMMMd(locale).add_jm()` |

### Medication Count Display:
| Line | Description | Widget |
|------|-------------|--------|
| 1125 | **Active medications count** | `Text("${_todayMedications.length} ${singular/plural}", ...)` - e.g., "1 medication scheduled" |
| 1335 | **Appointments count** | `Text("${_appointments.length} ${singular/plural}", ...)` - e.g., "2 appointments available" |

### Date Formatting Functions:
| Line | Function | Details |
|------|----------|---------|
| 1039+ | `_formatAppointmentDate()` | Uses `DateFormat.yMMMd(locale).add_jm()` to format date-time |
| 1009 | `_getTodayDate()` | Returns `DateFormat('EEEE, MMMM d, yyyy', locale).format(DateTime.now())` |
| 596+ | `DateFormat('yyyy-MM-dd')` | Used for dose log date storage |

---

## 3. **insights_page.dart** - Analytics & Progress Page

### Day Count & Percentages:
| Line | Description | Widget |
|------|-------------|--------|
| 70 | **Days into treatment** | `Text("${context.t('day')} ${metrics.daysIntoTreatment}${context.t('of_180')}")` - e.g., "Day 45 of 180" |
| 116 | **Adherence percentage (30d)** | `Text('${metrics.adherence30dPercent}%', ...)` |
| 116 | **Overall adherence percentage** | `Text('${metrics.overallAdherencePercent}%', ...)` |
| 264 | **Current streak** | `Text('${metrics.currentStreak} ${context.t('days')}', ...)` - e.g., "12 days" |
| 272 | **Missed doses (30d)** | `Text('${metrics.missedDoses30d}', ...)` - numeric count |

### Phase Progress Display:
| Line | Description | Widget |
|------|-------------|--------|
| 321 | **Phase name** | `Text(phaseName, ...)` - "Intensive Phase" or "Continuation Phase" |
| 327 | **Phase progress** | `Text('$displayedCompleted / $total ${context.t('days')}')` - e.g., "30 / 60 days" |
| 336 | **Progress percentage** | `Text('$progressPercent%', ...)` - calculated as `(progress * 100).toStringAsFixed(0)` |

### Metrics Calculation:
| Function | Calculations |
|----------|--------------|
| `_computeMetrics()` | Calculates adherence percentages, streaks, missed doses, days into treatment from dose logs |
| `_normalizeDate()` | Normalizes DateTime to date-only format |
| `_inclusiveDaysBetween()` | Calculates inclusive day count between dates |

---

## 4. **symptoms_page.dart** - Symptom Tracking Page

### Severity Number Display:
| Line | Description | Widget |
|------|-------------|--------|
| 533 | **Severity rating** | `Text('$severity/10', ...)` - displays symptom severity as fraction, e.g., "7/10" |

---

## 5. **profile_page.dart** - User Profile Page

### Treatment Progress Display:
| Line | Description | Widget |
|------|-------------|--------|
| 552 | **Days into treatment** | `Text("${context.t('day')} $day${context.t('of_180')}")` - e.g., "Day 45 of 180" |
| 552 | **Not started indicator** | `Text(context.t('not_started'), ...)` - fallback if treatment not started |

---

## 6. **tracking_simple_mode.dart** - Simplified Patient Tracking

### Medication & Streak Counts:
| Line | Description | Widget |
|------|-------------|--------|
| 457 | **Medications count** | `Text("${_todayMedications.length} ${singular/plural}", ...)` |
| 526 | **Streak display** | `Text("${context.t('current_streak')}: $_streak ${context.t('days')}")` |

---

## Date Formatting Patterns Found

### DateFormat Usage:
1. **'MMM d, yyyy'** - Full date format (e.g., "Apr 27, 2026")
2. **'EEEE, MMMM d, yyyy'** - Day name + full date (e.g., "Sunday, April 27, 2026")
3. **'EEE'** - Day abbreviation (e.g., "Sun", "Mon")
4. **'d'** - Day of month (e.g., "27")
5. **'yyyy-MM-dd'** - ISO format for data storage (e.g., "2026-04-27")
6. **'yMMMd'** + `.add_jm()` - Date + time (e.g., "Apr 27, 2026 3:45 PM")

### Locale-Aware Formatting:
- Uses `Localizations.localeOf(context).toString()` to get device locale
- Supports internationalization for date display

---

## Text Widgets with Dynamic Numbers Summary

| Category | Count | Primary Locations |
|----------|-------|------------------|
| Day counts | 8+ | treatment_page.dart, tracking_page.dart, insights_page.dart |
| Dates formatted | 7+ | treatment_page.dart (timeline), tracking_page.dart (appointments) |
| Percentages | 3+ | insights_page.dart (adherence, progress) |
| Dose/streak counts | 4+ | tracking_page.dart, insights_page.dart, symptoms_page.dart |
| Appointment/medication counts | 2+ | tracking_page.dart |

---

## Key Files Affected
1. ✅ [lib/screens/patient/treatment_page.dart](lib/screens/patient/treatment_page.dart) - **HIGH** - 12+ date/number widgets
2. ✅ [lib/screens/patient/tracking_page.dart](lib/screens/patient/tracking_page.dart) - **HIGH** - 10+ date/number widgets
3. ✅ [lib/screens/patient/insights_page.dart](lib/screens/patient/insights_page.dart) - **MEDIUM** - 6+ date/number widgets
4. ✅ [lib/screens/patient/symptoms_page.dart](lib/screens/patient/symptoms_page.dart) - **LOW** - 1 number widget
5. ✅ [lib/screens/patient/profile_page.dart](lib/screens/patient/profile_page.dart) - **LOW** - 1 date/number widget
6. ✅ [lib/screens/patient/tracking_simple_mode.dart](lib/screens/patient/tracking_simple_mode.dart) - **LOW** - 2+ number widgets

---

## Notes
- **No treatment_calendar.dart file found** - Timeline and calendar functionality is integrated into `treatment_page.dart`
- All date formatting uses the `intl` package (`DateFormat`)
- Localization is consistently applied across all date displays
- Numbers are generally interpolated directly into Text widgets using `$variable` syntax
