import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockReferralRepo extends Mock implements ReferralRepository {}

ReferralInfo _fakeReferralInfo() => const ReferralInfo(
  code: 'TEST-CODE',
  shareUrl: 'https://dony.app/invite/TEST-CODE',
  totalInvited: 0,
  signedUp: 0,
  rewarded: 0,
  hasBeenReferred: false,
  activeVoucherCount: 0,
  voucherFactor: 0.5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the share_plus platform channel so Share.share() doesn't throw.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => null,
        );
  });

  late _MockReferralRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockReferralRepo();
    backend = MockAnalyticsBackend();
  });

  ReferralBloc makeBloc({bool enabled = true}) {
    final a = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    a.onConfigured();
    return ReferralBloc(repo, a);
  }

  test(
    'referral_shared fires on ReferralShared when state is loaded',
    () async {
      // First load the referral to set state to ReferralLoaded
      when(
        () => repo.getMyReferral(),
      ).thenAnswer((_) async => _fakeReferralInfo());
      final bloc = makeBloc();
      bloc.add(const ReferralLoadRequested());
      await bloc.stream.firstWhere((s) => s is ReferralLoaded);
      clearInteractions(backend);

      // Now share
      bloc.add(const ReferralShared('test message'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(
        () => backend.capture(AnalyticsEvents.referralShared, any()),
      ).called(1);
    },
  );

  test('no event when disabled', () async {
    when(
      () => repo.getMyReferral(),
    ).thenAnswer((_) async => _fakeReferralInfo());
    final bloc = makeBloc(enabled: false);
    bloc.add(const ReferralLoadRequested());
    await bloc.stream.firstWhere((s) => s is ReferralLoaded);
    bloc.add(const ReferralShared('test message'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    verifyNever(() => backend.capture(any(), any()));
  });

  group('inscription (fromSignup)', () {
    test('code accepté : referral_signup_applied, sans propriété', () async {
      when(() => repo.redeemCode(any())).thenAnswer((_) async {});
      final bloc = makeBloc();
      bloc.add(const ReferralRedeemRequested('AMINA05', fromSignup: true));
      await bloc.stream.firstWhere((s) => s is ReferralRedeemed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final captured = verify(
        () => backend.capture(
          AnalyticsEvents.referralSignupApplied,
          captureAny(),
        ),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.single.toString(), isNot(contains('AMINA05')));
    });

    test(
      'code refusé : referral_signup_rejected avec error_code seul',
      () async {
        when(() => repo.redeemCode(any())).thenThrow(
          const ValidationException(
            'AMINA05 inconnu',
            code: 'referral-code-not-found',
          ),
        );
        final bloc = makeBloc();
        bloc.add(const ReferralRedeemRequested('AMINA05', fromSignup: true));
        await bloc.stream.firstWhere((s) => s is ReferralRedeemError);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final captured = verify(
          () => backend.capture(
            AnalyticsEvents.referralSignupRejected,
            captureAny(),
          ),
        ).captured;
        expect(captured.single, {'error_code': 'referral-code-not-found'});
      },
    );

    test(
      'hors inscription (profil) : aucun événement referral_signup_*',
      () async {
        when(() => repo.redeemCode(any())).thenAnswer((_) async {});
        final bloc = makeBloc();
        bloc.add(const ReferralRedeemRequested('AMINA05'));
        await bloc.stream.firstWhere((s) => s is ReferralRedeemed);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        verifyNever(() => backend.capture(any(), any()));
      },
    );
  });
}
