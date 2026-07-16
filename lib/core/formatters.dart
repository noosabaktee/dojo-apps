import 'package:intl/intl.dart';

final _dateFormat = DateFormat('d MMM yyyy', 'id_ID');
final _shortDateFormat = DateFormat('EEE, d MMM', 'id_ID');
final _timeFormat = DateFormat('HH:mm', 'id_ID');

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

String formatDate(dynamic value, {String fallback = '-'}) {
  final date = parseDate(value);
  return date == null ? fallback : _dateFormat.format(date);
}

String formatShortDate(dynamic value, {String fallback = '-'}) {
  final date = parseDate(value);
  return date == null ? fallback : _shortDateFormat.format(date);
}

String formatTime(dynamic value, {String fallback = '--:--'}) {
  final date = parseDate(value);
  return date == null ? fallback : _timeFormat.format(date);
}

double asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String compactNumber(dynamic value) => NumberFormat.compact(
  locale: 'id_ID',
).format(value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0);

String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}
