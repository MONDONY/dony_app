import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les fenêtres de permission et la visibilité du service de reconnaissance
/// ne se voient ni dans `flutter analyze` ni dans les tests Dart : ce test lit
/// les fichiers natifs pour qu'un oubli casse la CI plutôt que la recette.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Info.plist déclare le micro et la reconnaissance vocale', () {
    final plist = read('ios/Runner/Info.plist');
    expect(plist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(plist, contains('<key>NSSpeechRecognitionUsageDescription</key>'));
  });

  test('les InfoPlist.strings FR et EN expliquent la dictée', () {
    for (final lang in ['fr', 'en']) {
      final strings = read('ios/Runner/$lang.lproj/InfoPlist.strings');
      expect(
        strings,
        contains('"NSSpeechRecognitionUsageDescription"'),
        reason: lang,
      );
      final mic = RegExp(
        r'"NSMicrophoneUsageDescription" = "([^"]*)"',
      ).firstMatch(strings)!.group(1)!;
      expect(mic, contains(lang == 'fr' ? 'dicter' : 'dictate'), reason: lang);
    }
  });

  test('AndroidManifest : micro et service de reconnaissance visibles', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(
      manifest,
      contains('<action android:name="android.speech.RecognitionService"/>'),
    );
  });

  test('speech_to_text figé en 7.4.0 (la 7.5 exige le Kotlin intégré)', () {
    expect(
      read('pubspec.yaml'),
      contains(RegExp(r'^  speech_to_text: 7\.4\.0$', multiLine: true)),
    );
  });
}
