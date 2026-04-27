import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// Converts Arabic-Indic and Eastern Arabic-Indic digits to Western digits.
String convertArabicToWesternNumbers(String input) {
  const arabicDigits = [
    '\u0660',
    '\u0661',
    '\u0662',
    '\u0663',
    '\u0664',
    '\u0665',
    '\u0666',
    '\u0667',
    '\u0668',
    '\u0669',
  ];
  const easternArabicDigits = [
    '\u06F0',
    '\u06F1',
    '\u06F2',
    '\u06F3',
    '\u06F4',
    '\u06F5',
    '\u06F6',
    '\u06F7',
    '\u06F8',
    '\u06F9',
  ];

  var output = input;
  for (var i = 0; i < arabicDigits.length; i++) {
    output = output.replaceAll(arabicDigits[i], i.toString());
    output = output.replaceAll(easternArabicDigits[i], i.toString());
  }
  return output;
}

/// Formats a date and keeps the digits western.
String formatDateWithWesternNumerals(
  DateTime date,
  String pattern, {
  String? locale,
}) {
  try {
    final formatter = DateFormat(pattern, locale);
    return convertArabicToWesternNumbers(formatter.format(date));
  } catch (_) {
    return convertArabicToWesternNumbers(date.toString());
  }
}

/// Formats a number and keeps the digits western.
String formatNumberWithWesternNumerals(dynamic number) {
  return convertArabicToWesternNumbers(number.toString());
}

/// Custom Text widget that automatically converts Arabic numerals to Western numerals.
class ArabicNumeralText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final double? textScaleFactor;

  const ArabicNumeralText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.textScaleFactor,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = convertArabicToWesternNumbers(text);
    return Text(
      displayText,
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      textScaleFactor: textScaleFactor,
    );
  }
}

/// Custom Localization Delegate for Arabic Material.
///
/// This keeps the Arabic UI but lets the app normalize any shaped digits that
/// come from Material-localized strings.
class ArabicMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const ArabicMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return GlobalMaterialLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(ArabicMaterialLocalizationsDelegate old) => false;
}
