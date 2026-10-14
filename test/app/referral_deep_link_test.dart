import 'package:dony/app/referral_deep_link.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_analytics_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveReferralCodeDeepLink', () {
    test('yadony://referral?code=XXX rend le code normalisé', () {
      expect(
        resolveReferralCodeDeepLink(
          Uri.parse('yadony://referral?code=abou1890'),
        ),
        'ABOU1890',
      );
    });

    test('rejette les formes inattendues', () {
      for (final link in [
        'yadony://referral',
        'yadony://referral?code=AB',
        'yadony://referral?code=..%2Fadmin',
        'yadony://referral/extra?code=ABOU1890',
        'yadony://profile/referral?code=ABOU1890',
        'https://yadony.com/r/ABOU1890',
      ]) {
        expect(
          resolveReferralCodeDeepLink(Uri.parse(link)),
          isNull,
          reason: link,
        );
      }
    });
  });

  group('handleReferralDeepLink', () {
    late PendingReferralCodeStore store;
    late MockAnalyticsBackend backend;
    final dispatched = <String>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = PendingReferralCodeStore();
      await store.ready;
      backend = MockAnalyticsBackend();
      dispatched.clear();
    });

    bool handle(String link, {required bool signedIn}) {
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return handleReferralDeepLink(
        Uri.parse(link),
        store: store,
        analytics: analytics,
        signedIn: signedIn,
        dispatch: dispatched.add,
      );
    }

    test(
      'sans compte : code gardé pour l\'inscription, aucune navigation',
      () async {
        expect(
          handle('yadony://referral?code=ABOU1890', signedIn: false),
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);

        expect(store.current, 'ABOU1890');
        expect(dispatched, isEmpty);
        verify(
          () => backend.capture(AnalyticsEvents.referralLinkOpened, {
            'signed_in': false,
          }),
        ).called(1);

        // L'inscription relit le code après un redémarrage.
        final reloaded = PendingReferralCodeStore();
        await reloaded.ready;
        expect(reloaded.current, 'ABOU1890');
      },
    );

    test('connecté : ouvre Parrainage avec le code, sans l\'appliquer', () {
      expect(handle('yadony://referral?code=ABOU1890', signedIn: true), isTrue);

      expect(dispatched, ['/profile/referral?code=ABOU1890']);
      expect(store.current, 'ABOU1890');
    });

    test('autre lien : non traité', () {
      expect(handle('yadony://annonce/x', signedIn: true), isFalse);
      expect(dispatched, isEmpty);
      expect(store.current, isNull);
    });
  });
}
