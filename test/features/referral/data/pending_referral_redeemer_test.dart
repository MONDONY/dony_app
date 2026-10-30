import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:dony/features/referral/data/pending_referral_redeemer.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements ReferralRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PendingReferralCodeStore store;
  late _MockRepo repo;
  late MockAnalyticsBackend backend;
  late PendingReferralRedeemer redeemer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PendingReferralCodeStore();
    await store.ready;
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    redeemer = PendingReferralRedeemer(store, repo, analytics);
  });

  test('aucun code : none, aucun appel serveur, aucun événement', () async {
    expect(await redeemer.apply(), PendingReferralOutcome.none);
    verifyZeroInteractions(repo);
    verifyNever(() => backend.capture(any(), any()));
  });

  test('succès : applied, code effacé, événement sans le code', () async {
    await store.save('ABOU1890');
    when(() => repo.redeemCode('ABOU1890')).thenAnswer((_) async {});

    expect(await redeemer.apply(), PendingReferralOutcome.applied);
    expect(store.current, isNull);
    verify(
      () => backend.capture(
        AnalyticsEvents.referralAutoApplied,
        {'outcome': 'applied'},
      ),
    ).called(1);
  });

  for (final error in <Object>[
    Exception('404'),
    Exception('409 already-referred'),
    Exception('network'),
    StateError('boom'),
  ]) {
    test('échec ($error) : rejected, code effacé, ne lève pas', () async {
      await store.save('ABOU1890');
      when(() => repo.redeemCode(any())).thenThrow(error);

      expect(await redeemer.apply(), PendingReferralOutcome.rejected);
      expect(store.current, isNull);
      verify(
        () => backend.capture(
          AnalyticsEvents.referralAutoApplied,
          {'outcome': 'rejected'},
        ),
      ).called(1);
    });
  }
}
