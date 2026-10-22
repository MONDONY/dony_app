import 'package:dony/app/open_deep_link.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_analytics_backend.dart';

void main() {
  const bid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

  group('openLinkType', () {
    test('lien universel https://yadony.com/ouvrir', () {
      expect(
        openLinkType(Uri.parse('https://yadony.com/ouvrir?type=BID_ACCEPTED')),
        'BID_ACCEPTED',
      );
      expect(
        openLinkType(Uri.parse('https://yadony.com/ouvrir/?type=BID_CREATED')),
        'BID_CREATED',
      );
    });

    test('lien yadony://open de la page de repli', () {
      expect(
        openLinkType(Uri.parse('yadony://open?type=PAYMENT_RELEASED')),
        'PAYMENT_RELEASED',
      );
    });

    test('rejette les autres formes', () {
      for (final link in [
        'https://yadony.com/ouvrir',
        'https://yadony.com/ouvrir?type=bid_accepted',
        'https://yadony.com/ouvrir?type=BID%26x',
        'https://yadony.com/autre?type=BID_ACCEPTED',
        'https://evil.example/ouvrir?type=BID_ACCEPTED',
        'https://yadony.com.evil.example/ouvrir?type=BID_ACCEPTED',
        'http://yadony.com/ouvrir?type=BID_ACCEPTED',
        'yadony://open/extra?type=BID_ACCEPTED',
        'yadony://opened?type=BID_ACCEPTED',
        'yadony://annonce/$bid',
      ]) {
        expect(openLinkType(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  group('resolveOpenDeepLink', () {
    test('même écran que le toucher du push', () {
      expect(
        resolveOpenDeepLink(
          Uri.parse('https://yadony.com/ouvrir?type=BID_ACCEPTED&bidId=$bid'),
        ),
        '/bids/$bid',
      );
      expect(
        resolveOpenDeepLink(
          Uri.parse('yadony://open?type=BID_CREATED&bidId=$bid'),
        ),
        '/demandes?bid=$bid',
      );
    });

    test('identifiant forgé ignoré : le résolveur valide chaque UUID', () {
      expect(
        resolveOpenDeepLink(
          Uri.parse(
            'https://yadony.com/ouvrir?type=BID_ACCEPTED&bidId=../admin',
          ),
        ),
        isNull,
      );
    });

    test('type sans écran propre ou lien étranger : aucune route', () {
      expect(
        resolveOpenDeepLink(
          Uri.parse('https://yadony.com/ouvrir?type=UNKNOWN_TYPE'),
        ),
        isNull,
      );
      expect(resolveOpenDeepLink(Uri.parse('https://yadony.com/cgu')), isNull);
    });
  });

  group('handleOpenDeepLink', () {
    late MockAnalyticsBackend backend;
    final dispatched = <String>[];

    setUp(() {
      backend = MockAnalyticsBackend();
      dispatched.clear();
    });

    bool handle(String link) {
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return handleOpenDeepLink(
        Uri.parse(link),
        analytics: analytics,
        dispatch: dispatched.add,
      );
    }

    test('ouvre l\'écran et mesure l\'ouverture', () async {
      expect(
        handle('https://yadony.com/ouvrir?type=BID_ACCEPTED&bidId=$bid'),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);

      expect(dispatched, ['/bids/$bid']);
      verify(
        () => backend.capture(AnalyticsEvents.emailLinkOpened, {
          'type': 'BID_ACCEPTED',
          'resolved': true,
        }),
      ).called(1);
    });

    test('lien reconnu sans écran : consommé, aucune navigation', () async {
      expect(handle('https://yadony.com/ouvrir?type=UNKNOWN_TYPE'), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(dispatched, isEmpty);
      verify(
        () => backend.capture(AnalyticsEvents.emailLinkOpened, {
          'type': 'UNKNOWN_TYPE',
          'resolved': false,
        }),
      ).called(1);
    });

    test('autre lien : non traité', () {
      expect(handle('https://yadony.com/cgu'), isFalse);
      expect(handle('yadony://annonce/$bid'), isFalse);
      expect(dispatched, isEmpty);
    });
  });
}
