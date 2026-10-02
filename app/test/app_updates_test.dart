import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/app_updates.dart';

void main() {
  final metadata = {'versionName': '1.1.1', 'versionCode': 3, 'apk': 'app.apk'};
  Map<String, dynamic> release(String url) => {
    'assets': [
      {'name': 'app.apk', 'browser_download_url': url},
    ],
    'body': 'Cambios',
  };
  test('reads stable APK metadata and increasing build number', () {
    final update = AvailableUpdate.parse(
      release('${releasePrefix}v1.1.1/app.apk'),
      metadata,
    );
    expect(update.code, greaterThan(2));
    expect(update.version, '1.1.1');
  });
  test('rejects external download and prerelease', () {
    expect(
      () => AvailableUpdate.parse(
        release('https://example.com/app.apk'),
        metadata,
      ),
      throwsFormatException,
    );
    expect(
      () => AvailableUpdate.parse({
        ...release('${releasePrefix}v1/app.apk'),
        'prerelease': true,
      }, metadata),
      throwsFormatException,
    );
  });
}
