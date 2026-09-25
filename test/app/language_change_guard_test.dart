import 'package:dony/app/language_change_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanguageChangeGuard', () {
    test('déclenche au tout premier appel', () {
      final guard = LanguageChangeGuard();
      final received = <String>[];

      guard.notify('fr', received.add);

      expect(received, ['fr']);
    });

    test('ne redéclenche pas si la langue n\'a pas changé', () {
      final guard = LanguageChangeGuard();
      final received = <String>[];

      guard.notify('fr', received.add);
      // `MaterialApp.router.builder` est rebâti à chaque frame : simule
      // plusieurs reconstructions sans changement de langue.
      guard.notify('fr', received.add);
      guard.notify('fr', received.add);

      expect(received, ['fr']);
    });

    test('redéclenche quand la langue change réellement', () {
      final guard = LanguageChangeGuard();
      final received = <String>[];

      guard.notify('fr', received.add);
      guard.notify('en', received.add);
      guard.notify('en', received.add);
      guard.notify('fr', received.add);

      expect(received, ['fr', 'en', 'fr']);
    });
  });
}
