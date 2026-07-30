import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dojo/core/api_client.dart';
import 'package:dojo/repositories/app_repository.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('submitWfh sends the selected request type', () async {
    final client = _RecordingApiClient();
    final repository = AppRepository(client);
    final attachment = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'surat-dokter.pdf',
      mimeType: 'application/pdf',
    );

    final message = await repository.submitWfh(
      type: 'Sakit',
      startDate: DateTime(2026, 7, 30),
      endDate: DateTime(2026, 7, 31),
      reason: 'Perlu beristirahat.',
      attachment: attachment,
    );

    expect(message, 'Pengajuan Sakit berhasil dibuat.');
    expect(client.lastPath, '/work-from-home');
    final form = client.lastData! as FormData;
    final fields = Map<String, String>.fromEntries(form.fields);
    expect(fields['type'], 'Sakit');
    expect(fields['start_date'], '2026-07-30');
    expect(fields['end_date'], '2026-07-31');
    expect(fields['reason'], 'Perlu beristirahat.');
    expect(form.files.single.key, 'attachment');
  });
}

class _RecordingApiClient extends ApiClient {
  String? lastPath;
  dynamic lastData;

  @override
  Future<ApiEnvelope> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    lastPath = path;
    lastData = data;
    return const ApiEnvelope(
      data: <String, dynamic>{},
      message: 'Pengajuan Sakit berhasil dibuat.',
    );
  }
}
