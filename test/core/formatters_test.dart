import 'package:flutter_test/flutter_test.dart';

import 'package:dojo/core/formatters.dart';

void main() {
  setUpAll(initializeJakartaTimezone);

  test('converts UTC timestamps to Asia Jakarta time', () {
    final value = parseDate('2026-07-16T00:30:00Z');

    expect(value, isNotNull);
    expect(value!.hour, 7);
    expect(value.minute, 30);
  });

  test('keeps date-only values on the same Jakarta calendar date', () {
    final value = parseDate('2026-07-16');

    expect(value, isNotNull);
    expect(value!.year, 2026);
    expect(value.month, 7);
    expect(value.day, 16);
  });
}
