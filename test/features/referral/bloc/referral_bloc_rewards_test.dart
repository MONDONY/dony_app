import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements ReferralRepository {}

class _MockLauncher extends Mock implements ContactLinkLauncher {}

const _info = ReferralInfo(
  code: 'ABOU1890',
  shareUrl: 'https://yadony.com/r/ABOU1890',
  totalInvited: 3,
  signedUp: 3,
  rewarded: 1,
  hasBeenReferred: false,
  activeVoucherCount: 0,
);

const _available = Referee(
  invitationId: 'inv-1',
  displayName: 'Fatou D.',
  status: RefereeStatus.firstDelivery,
  rewardStatus: RewardStatus.available,
);

const _signedUp = Referee(invitationId: 'inv-2', displayName: 'Awa S.');

RefereePage _page(List<Referee> items, {int page = 0, bool last = true}) =>
    RefereePage(content: items, page: page, last: last);

DioException _dio(AppException error) =>
    DioException(requestOptions: RequestOptions(), error: error);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late _MockLauncher launcher;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(RewardChoice.walletCredit);
    registerFallbackValue(Uri());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  setUp(() {
    repo = _MockRepo();
    launcher = _MockLauncher();
    backend = MockAnalyticsBackend();
    when(() => repo.getMyReferral()).thenAnswer((_) async => _info);
  });

  ReferralBloc build() {
    final analytics = makeEnabledAnalytics(backend)..onConfigured();
    return ReferralBloc(repo, analytics, linkLauncher: launcher);
  }

  group('chargement des filleuls', () {
    blocTest<ReferralBloc, ReferralState>(
      'includeReferees : infos et filleuls dans un seul état chargé',
      setUp: () => when(
        () => repo.getReferees(),
      ).thenAnswer((_) async => _page([_available, _signedUp], last: false)),
      build: build,
      act: (bloc) =>
          bloc.add(const ReferralLoadRequested(includeReferees: true)),
      expect: () => [
        isA<ReferralLoading>(),
        isA<ReferralLoaded>()
            .having((s) => s.refereesStatus, 'status', RefereesStatus.loaded)
            .having((s) => s.referees, 'referees', hasLength(2))
            .having((s) => s.refereesLast, 'last', isFalse)
            .having((s) => s.availableRewards, 'available', [_available]),
      ],
    );

    blocTest<ReferralBloc, ReferralState>(
      'ancien back (404 sur les filleuls) : section indisponible, écran chargé',
      setUp: () => when(
        () => repo.getReferees(),
      ).thenThrow(_dio(const NotFoundException())),
      build: build,
      act: (bloc) =>
          bloc.add(const ReferralLoadRequested(includeReferees: true)),
      expect: () => [
        isA<ReferralLoading>(),
        isA<ReferralLoaded>()
            .having(
              (s) => s.refereesStatus,
              'status',
              RefereesStatus.unavailable,
            )
            .having((s) => s.info.code, 'code', 'ABOU1890'),
      ],
    );

    blocTest<ReferralBloc, ReferralState>(
      'erreur réseau sur les filleuls : statut error, puis relecture',
      setUp: () {
        var calls = 0;
        when(() => repo.getReferees()).thenAnswer((_) async {
          calls++;
          if (calls == 1) throw _dio(const OfflineException());
          return _page([_signedUp]);
        });
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ReferralLoadRequested(includeReferees: true));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ReferralRefereesRequested(reset: true));
      },
      expect: () => [
        isA<ReferralLoading>(),
        isA<ReferralLoaded>().having(
          (s) => s.refereesStatus,
          'status',
          RefereesStatus.error,
        ),
        isA<ReferralLoaded>().having(
          (s) => s.refereesStatus,
          'status',
          RefereesStatus.loading,
        ),
        isA<ReferralLoaded>()
            .having((s) => s.refereesStatus, 'status', RefereesStatus.loaded)
            .having((s) => s.referees, 'referees', [_signedUp]),
      ],
    );

    blocTest<ReferralBloc, ReferralState>(
      'page suivante : les filleuls s\'ajoutent',
      setUp: () => when(
        () => repo.getReferees(page: 1),
      ).thenAnswer((_) async => _page([_signedUp], page: 1)),
      build: build,
      seed: () => const ReferralLoaded(
        _info,
        referees: [_available],
        refereesStatus: RefereesStatus.loaded,
        refereesLast: false,
      ),
      act: (bloc) => bloc.add(const ReferralRefereesRequested()),
      expect: () => [
        isA<ReferralLoaded>().having(
          (s) => s.loadingMoreReferees,
          'loadingMore',
          isTrue,
        ),
        isA<ReferralLoaded>()
            .having((s) => s.referees, 'referees', [_available, _signedUp])
            .having((s) => s.refereesPage, 'page', 1)
            .having((s) => s.refereesLast, 'last', isTrue)
            .having((s) => s.loadingMoreReferees, 'loadingMore', isFalse),
      ],
    );

    blocTest<ReferralBloc, ReferralState>(
      'rafraîchissement raté : l\'écran déjà chargé reste affiché',
      setUp: () => when(
        () => repo.getMyReferral(),
      ).thenThrow(_dio(const OfflineException())),
      build: build,
      seed: () => const ReferralLoaded(_info),
      act: (bloc) => bloc.add(const ReferralLoadRequested()),
      expect: () => <ReferralState>[],
    );
  });

  group('choix de la récompense', () {
    const chosenWallet = Referee(
      invitationId: 'inv-1',
      displayName: 'Fatou D.',
      status: RefereeStatus.rewarded,
      rewardStatus: RewardStatus.chosen,
      rewardChoice: RewardChoice.walletCredit,
      walletAmount: 5,
      walletCurrency: 'EUR',
    );
    const chosenCode = Referee(
      invitationId: 'inv-1',
      status: RefereeStatus.rewarded,
      rewardStatus: RewardStatus.chosen,
      rewardChoice: RewardChoice.discountCode,
      discountCode: RefereeDiscountCode(code: 'MERCI-7K2F', percent: 5),
    );
    const seeded = ReferralLoaded(
      _info,
      referees: [_available, _signedUp],
      refereesStatus: RefereesStatus.loaded,
    );

    blocTest<ReferralBloc, ReferralState>(
      'WALLET_CREDIT : envoi, filleul remplacé, analytics, compteurs relus',
      setUp: () => when(
        () => repo.chooseReward('inv-1', RewardChoice.walletCredit),
      ).thenAnswer((_) async => chosenWallet),
      build: build,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        const ReferralRewardChosen('inv-1', RewardChoice.walletCredit),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<ReferralLoaded>().having(
          (s) => s.choosingInvitationId,
          'choosing',
          'inv-1',
        ),
        isA<ReferralLoaded>()
            .having((s) => s.choosingInvitationId, 'choosing', isNull)
            .having((s) => s.rewardResult, 'result', chosenWallet)
            .having((s) => s.availableRewards, 'available', isEmpty)
            .having((s) => s.earnedWalletAmount, 'earned', 5.0),
        // Relecture silencieuse des compteurs : le résultat ponctuel n'est
        // pas reporté, la liste reste en place.
        isA<ReferralLoaded>()
            .having((s) => s.rewardResult, 'result', isNull)
            .having((s) => s.referees.first, 'first', chosenWallet),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.referralRewardChosen, {
            'choice': 'WALLET_CREDIT',
          }),
        ).called(1);
      },
    );

    blocTest<ReferralBloc, ReferralState>(
      'DISCOUNT_CODE : le code revient dans le résultat',
      setUp: () => when(
        () => repo.chooseReward('inv-1', RewardChoice.discountCode),
      ).thenAnswer((_) async => chosenCode),
      build: build,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        const ReferralRewardChosen('inv-1', RewardChoice.discountCode),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        verify(
          () => backend.capture(AnalyticsEvents.referralRewardChosen, {
            'choice': 'DISCOUNT_CODE',
          }),
        ).called(1);
        final state = bloc.state as ReferralLoaded;
        expect(state.referees.first.discountCode?.code, 'MERCI-7K2F');
      },
    );

    blocTest<ReferralBloc, ReferralState>(
      '409 referral-reward-already-chosen : erreur ponctuelle puis relecture',
      setUp: () {
        when(() => repo.chooseReward(any(), any())).thenThrow(
          _dio(
            const ConflictException(
              'x',
              code: 'referral-reward-already-chosen',
            ),
          ),
        );
        when(
          () => repo.getReferees(),
        ).thenAnswer((_) async => _page([chosenWallet, _signedUp]));
      },
      build: build,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        const ReferralRewardChosen('inv-1', RewardChoice.walletCredit),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<ReferralLoaded>().having(
          (s) => s.isChoosingReward,
          'choosing',
          isTrue,
        ),
        isA<ReferralLoaded>()
            .having((s) => s.isChoosingReward, 'choosing', isFalse)
            .having(
              (s) => s.rewardError?.code,
              'error',
              'referral-reward-already-chosen',
            ),
        isA<ReferralLoaded>()
            .having((s) => s.rewardError, 'error', isNull)
            .having((s) => s.refereesStatus, 'status', RefereesStatus.loading),
        isA<ReferralLoaded>().having(
          (s) => s.availableRewards,
          'available',
          isEmpty,
        ),
      ],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.referralRewardChosen, any()),
      ),
    );

    blocTest<ReferralBloc, ReferralState>(
      '404 referral-invitation-not-found : erreur et liste relue',
      setUp: () {
        when(() => repo.chooseReward(any(), any())).thenThrow(
          _dio(
            const NotFoundException(apiCode: 'referral-invitation-not-found'),
          ),
        );
        when(
          () => repo.getReferees(),
        ).thenAnswer((_) async => _page([_signedUp]));
      },
      build: build,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        const ReferralRewardChosen('inv-1', RewardChoice.discountCode),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        verify(() => repo.getReferees()).called(1);
        expect((bloc.state as ReferralLoaded).referees, [_signedUp]);
      },
    );

    blocTest<ReferralBloc, ReferralState>(
      'un second choix pendant l\'envoi est ignoré',
      setUp: () => when(
        () => repo.chooseReward(any(), any()),
      ).thenAnswer((_) async => chosenWallet),
      build: build,
      seed: () => seeded.copyWith(choosingInvitationId: 'inv-1'),
      act: (bloc) => bloc.add(
        const ReferralRewardChosen('inv-1', RewardChoice.walletCredit),
      ),
      expect: () => <ReferralState>[],
      verify: (_) => verifyNever(() => repo.chooseReward(any(), any())),
    );
  });

  group('partage', () {
    blocTest<ReferralBloc, ReferralState>(
      'WhatsApp ouvert : channel whatsapp, pas de feuille système',
      setUp: () =>
          when(() => launcher.open(any())).thenAnswer((_) async => true),
      build: build,
      seed: () => const ReferralLoaded(_info),
      act: (bloc) => bloc.add(
        const ReferralShared('msg', channel: ReferralShareChannel.whatsapp),
      ),
      verify: (_) {
        final uri =
            verify(() => launcher.open(captureAny())).captured.single as Uri;
        expect(uri.host, 'wa.me');
        expect(uri.queryParameters['text'], 'msg');
        verify(
          () => backend.capture(AnalyticsEvents.referralShared, {
            'channel': 'whatsapp',
          }),
        ).called(1);
      },
    );

    blocTest<ReferralBloc, ReferralState>(
      'WhatsApp absent : repli sur la feuille de partage',
      setUp: () =>
          when(() => launcher.open(any())).thenAnswer((_) async => false),
      build: build,
      seed: () => const ReferralLoaded(_info),
      act: (bloc) => bloc.add(
        const ReferralShared('msg', channel: ReferralShareChannel.whatsapp),
      ),
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.referralShared, {
          'channel': 'share_sheet',
        }),
      ).called(1),
    );

    blocTest<ReferralBloc, ReferralState>(
      'copie du lien : presse-papiers et channel copy_link',
      build: build,
      seed: () => const ReferralLoaded(_info),
      act: (bloc) => bloc.add(const ReferralLinkCopied()),
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.referralShared, {
          'channel': 'copy_link',
        }),
      ).called(1),
    );
  });
}
