import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('trackingStepLabel', () {
    test(
      'DEPART — fr',
      () => expect(trackingStepLabel(fr, 'DEPART'), 'Départ'),
    );
    test(
      'DEPART — en',
      () => expect(trackingStepLabel(en, 'DEPART'), 'Departure'),
    );
    test(
      'TRANSIT — fr',
      () => expect(trackingStepLabel(fr, 'TRANSIT'), 'Transit'),
    );
    test(
      'TRANSIT — en',
      () => expect(trackingStepLabel(en, 'TRANSIT'), 'Transit'),
    );
    test(
      'ARRIVEE — fr',
      () => expect(trackingStepLabel(fr, 'ARRIVEE'), 'Arrivée'),
    );
    test(
      'ARRIVEE — en',
      () => expect(trackingStepLabel(en, 'ARRIVEE'), 'Arrival'),
    );

    test('code inconnu — rendu tel quel (fr)', () {
      expect(trackingStepLabel(fr, 'AUTRE'), 'AUTRE');
    });
    test('code inconnu — rendu tel quel (en)', () {
      expect(trackingStepLabel(en, 'AUTRE'), 'AUTRE');
    });
  });

  group('scanRelativeTime', () {
    test('30 s — fr', () {
      expect(
        scanRelativeTime(fr, const Duration(seconds: 30)),
        'il y a < 1 min',
      );
    });
    test('30 s — en', () {
      expect(scanRelativeTime(en, const Duration(seconds: 30)), '< 1 min ago');
    });
    test('5 min — fr', () {
      expect(scanRelativeTime(fr, const Duration(minutes: 5)), 'il y a 5 min');
    });
    test('5 min — en', () {
      expect(scanRelativeTime(en, const Duration(minutes: 5)), '5 min ago');
    });
    test('3 h — fr', () {
      expect(scanRelativeTime(fr, const Duration(hours: 3)), 'il y a 3h');
    });
    test('3 h — en', () {
      expect(scanRelativeTime(en, const Duration(hours: 3)), '3h ago');
    });
  });

  group('scanPendingSync', () {
    // Ancien code : ternaire sur `> 1`, donc 0 ET 1 restent au singulier
    // (comme le pluriel ICU français, qui range 0 dans la branche `one`).
    test('0 — fr (égal à l\'ancien code)', () {
      expect(fr.scanPendingSync(0), '0 lecture en attente de synchro');
    });
    test('1 — fr', () {
      expect(fr.scanPendingSync(1), '1 lecture en attente de synchro');
    });
    test('3 — fr (égal à l\'ancien code)', () {
      expect(fr.scanPendingSync(3), '3 lectures en attente de synchro');
    });
  });

  group('scanOfflineCount', () {
    test('0 — fr (égal à l\'ancien code)', () {
      expect(fr.scanOfflineCount(0), '0 lecture hors-ligne');
    });
    test('1 — fr', () {
      expect(fr.scanOfflineCount(1), '1 lecture hors-ligne');
    });
    test('3 — fr (égal à l\'ancien code)', () {
      expect(fr.scanOfflineCount(3), '3 lectures hors-ligne');
    });
  });

  group('scanQueueSafe', () {
    test('1 — fr (nouveau rendu, accord corrigé)', () {
      expect(
        fr.scanQueueSafe(1),
        '1 lecture en attente. On l\'enverra dès que vous récupérez du réseau.',
      );
    });
    test('3 — fr (égal à l\'ancien code)', () {
      expect(
        fr.scanQueueSafe(3),
        '3 lectures en attente. On les enverra dès que vous récupérez du réseau.',
      );
    });
  });
}
