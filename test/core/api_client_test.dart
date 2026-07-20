import 'package:dojo/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a public storage URL for a profile photo path', () {
    final url = ApiClient.publicFileUrl('profile-photos/avatar.png');

    expect(Uri.parse(url!).path, '/storage/profile-photos/avatar.png');
  });

  test('keeps an absolute profile photo URL unchanged', () {
    const url = 'https://cdn.example.com/profile/avatar.webp';

    expect(ApiClient.publicFileUrl(url), url);
  });

  test('returns null for an empty profile photo path', () {
    expect(ApiClient.publicFileUrl('  '), isNull);
  });
}
