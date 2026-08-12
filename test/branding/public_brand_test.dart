import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les manifestes exposent Yadony comme nom public', () {
    final android =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final web = File('web/index.html').readAsStringSync();

    expect(android, contains('android:label="Yadony"'));
    expect(ios, contains('<string>Yadony</string>'));
    expect(web, contains('<title>Yadony</title>'));
  });

  test('les assets canoniques de marque existent', () {
    expect(File('assets/logos/logo-yadony.png').existsSync(), isTrue);
    expect(File('assets/mascotte/travel.png').existsSync(), isTrue);
  });
}
