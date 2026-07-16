import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final _dateFormat = DateFormat('d MMM yyyy', 'id_ID');
final _shortDateFormat = DateFormat('EEE, d MMM', 'id_ID');
final _timeFormat = DateFormat('HH:mm', 'id_ID');
tz.Location? _jakarta;

void initializeJakartaTimezone() {
  tz_data.initializeTimeZones();
  _jakarta = tz.getLocation('Asia/Jakarta');
  tz.setLocalLocation(_jakarta!);
}

tz.Location get _jakartaLocation {
  if (_jakarta == null) initializeJakartaTimezone();
  return _jakarta!;
}

DateTime jakartaNow() => tz.TZDateTime.now(_jakartaLocation);

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) {
    if (value.isUtc) return tz.TZDateTime.from(value, _jakartaLocation);
    return tz.TZDateTime(
      _jakartaLocation,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  final raw = value.toString().trim();
  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (dateOnly != null) {
    return tz.TZDateTime(
      _jakartaLocation,
      int.parse(dateOnly.group(1)!),
      int.parse(dateOnly.group(2)!),
      int.parse(dateOnly.group(3)!),
    );
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return tz.TZDateTime.from(parsed.toUtc(), _jakartaLocation);
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
  final hour = jakartaNow().hour;
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}
