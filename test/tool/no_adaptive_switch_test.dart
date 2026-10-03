import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FLUTTER-A1/A2 : la version iOS de `Switch.adaptive` /
/// `SwitchListTile.adaptive` plantait au dessin pendant une animation
/// d'entrée (null check dans `_SwitchPainter.paint`). L'app n'utilise que
/// l'interrupteur standard ; ce garde-fou empêche le retour de l'adaptatif.
void main() {
  test('aucun interrupteur .adaptive dans lib/', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => RegExp(
            r'\b(SwitchListTile|Switch)\.adaptive\(',
          ).hasMatch(f.readAsStringSync()),
        )
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
