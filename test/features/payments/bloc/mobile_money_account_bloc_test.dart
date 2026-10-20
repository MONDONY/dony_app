import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyAccountRepository extends Mock
    implements MobileMoneyAccountRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockMobileMoneyAccountRepository repository;
  late MockAnalyticsService analytics;

  const orangeCi = MobileMoneyPayoutAccount(
    id: 'a1',
    provider: 'ORANGE_CIV',
    providerLabel: 'Orange Money CI',
    brand: 'ORANGE',
    country: 'CI',
    currency: 'XOF',
    msisdnMasked: '+225 •• •• •• 36',
  );
  const orangeSn = MobileMoneyPayoutAccount(
    id: 'a2',
    provider: 'ORANGE_SEN',
    providerLabel: 'Orange Money SN',
    brand: 'ORANGE',
    country: 'SN',
    currency: 'XOF',
    msisdnMasked: '+221 •• •• •• 67',
  );
  const one = MobileMoneyPayoutAccounts(accounts: [orangeCi]);
  const two = MobileMoneyPayoutAccounts(accounts: [orangeCi, orangeSn]);
  const legacyOne = MobileMoneyPayoutAccounts(
    accounts: [orangeCi],
    legacy: true,
  );
  const locked = ConflictException(
    'colis en attente',
    code: 'mobile-money-account-locked',
  );

  setUpAll(() {
    registerFallbackValue(orangeCi);
  });

  setUp(() {
    repository = MockMobileMoneyAccountRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  MobileMoneyAccountBloc bloc() =>
      MobileMoneyAccountBloc(repository, analytics);

  test('état initial', () {
    expect(bloc().state, isA<MobileMoneyAccountInitial>());
  });

  group('MobileMoneyAccountsRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'émet Loading puis Loaded avec la liste du nouveau contrat',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => two);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountsRequested()),
      expect: () => [
        const MobileMoneyAccountLoading(),
        const MobileMoneyAccountLoaded(two),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'repli sur l\'ancien contrat : liste legacy servie telle quelle',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => legacyOne);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountsRequested()),
      expect: () => [
        const MobileMoneyAccountLoading(),
        const MobileMoneyAccountLoaded(legacyOne),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'échec : Loading puis Error avec l\'exception déballée',
      build: () {
        when(() => repository.accounts()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            error: const NetworkException('offline'),
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountsRequested()),
      expect: () => [
        const MobileMoneyAccountLoading(),
        const MobileMoneyAccountError(NetworkException('offline')),
      ],
    );
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'relecture d\'une liste affichée : pas de Loading, la liste reste '
      'jusqu\'à la nouvelle',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => two);
        return bloc();
      },
      seed: () => const MobileMoneyAccountActionFailed(
        one,
        ConflictException('bloqué', code: 'mobile-money-account-locked'),
      ),
      act: (b) => b.add(const MobileMoneyAccountsRequested()),
      expect: () => [const MobileMoneyAccountLoaded(two)],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'relecture d\'une liste affichée en échec : la liste reste (ActionFailed), '
      'sans Loading ni Error',
      build: () {
        when(
          () => repository.accounts(),
        ).thenThrow(const NetworkException('offline'));
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(one),
      act: (b) => b.add(const MobileMoneyAccountsRequested()),
      expect: () => [
        const MobileMoneyAccountActionFailed(one, NetworkException('offline')),
      ],
      verify: (b) => expect(b.state.data, one),
    );
  });

  group('MobileMoneyAccountAddRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'Loaded(submitting) puis ActionDone(added) avec la liste relue',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => two);
        when(
          () => repository.addAccount(
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) async {});
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(one),
      act: (b) => b.add(
        const MobileMoneyAccountAddRequested(
          phoneNumber: '+221770000067',
          provider: 'ORANGE_SEN',
        ),
      ),
      expect: () => [
        const MobileMoneyAccountLoaded(one, submitting: true),
        const MobileMoneyAccountActionDone(two, MobileMoneyAccountAction.added),
      ],
      verify: (_) {
        verify(
          () => repository.addAccount(
            phoneNumber: '+221770000067',
            provider: 'ORANGE_SEN',
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountAdded,
            properties: {'provider': 'ORANGE_SEN', 'accounts_count': 2},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'écriture refusée : ActionFailed avec la liste d\'avant, event d\'échec',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => one);
        when(
          () => repository.addAccount(
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenThrow(
          const ValidationException(
            'mauvais réseau',
            code: 'mobile-money-account-wrong-network',
          ),
        );
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(one),
      act: (b) => b.add(
        const MobileMoneyAccountAddRequested(
          phoneNumber: '+221770000067',
          provider: 'ORANGE_SEN',
        ),
      ),
      expect: () => [
        const MobileMoneyAccountLoaded(one, submitting: true),
        const MobileMoneyAccountActionFailed(
          one,
          ValidationException(
            'mauvais réseau',
            code: 'mobile-money-account-wrong-network',
          ),
        ),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountActionFailed,
            properties: {
              'action': 'added',
              'error_code': 'mobile-money-account-wrong-network',
            },
          ),
        ).called(1);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountAdded,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'erreur sans code : error_code vaut unknown',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => one);
        when(
          () => repository.addAccount(
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenThrow(const NetworkException('offline'));
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(one),
      act: (b) => b.add(
        const MobileMoneyAccountAddRequested(
          phoneNumber: '+221770000067',
          provider: 'ORANGE_SEN',
        ),
      ),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountActionFailed,
            properties: {'action': 'added', 'error_code': 'unknown'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'un second appui pendant l\'envoi est ignoré',
      build: bloc,
      seed: () => const MobileMoneyAccountLoaded(one, submitting: true),
      act: (b) => b.add(
        const MobileMoneyAccountAddRequested(
          phoneNumber: '+221770000067',
          provider: 'ORANGE_SEN',
        ),
      ),
      expect: () => <MobileMoneyAccountState>[],
      verify: (_) {
        verifyNever(() => repository.accounts());
        verifyNever(
          () => repository.addAccount(
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        );
      },
    );
  });

  group('relecture après une écriture réussie', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'ajout passé, relecture en échec : ActionDone sur la liste d\'avant '
      '(l\'écran d\'ajout se ferme)',
      build: () {
        when(
          () => repository.accounts(),
        ).thenThrow(const NetworkException('offline'));
        when(
          () => repository.addAccount(
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) async {});
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(one),
      act: (b) => b.add(
        const MobileMoneyAccountAddRequested(
          phoneNumber: '+221770000067',
          provider: 'ORANGE_SEN',
        ),
      ),
      expect: () => [
        const MobileMoneyAccountLoaded(one, submitting: true),
        const MobileMoneyAccountActionDone(one, MobileMoneyAccountAction.added),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountAdded,
            properties: {'provider': 'ORANGE_SEN'},
          ),
        ).called(1);
      },
    );
  });

  group('MobileMoneyAccountNumberChangeRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'change le numéro puis relit la liste, event number_changed',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => two);
        when(
          () => repository.changeNumber(
            account: any(named: 'account'),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        ).thenAnswer((_) async {});
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(two),
      act: (b) => b.add(
        const MobileMoneyAccountNumberChangeRequested(
          account: orangeSn,
          phoneNumber: '+221770000099',
        ),
      ),
      expect: () => [
        const MobileMoneyAccountLoaded(two, submitting: true),
        const MobileMoneyAccountActionDone(
          two,
          MobileMoneyAccountAction.numberChanged,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.changeNumber(
            account: orangeSn,
            phoneNumber: '+221770000099',
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountNumberChanged,
            properties: {'provider': 'ORANGE_SEN', 'accounts_count': 2},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      '409 verrouillé : ActionFailed et event d\'échec number_changed',
      build: () {
        when(
          () => repository.changeNumber(
            account: any(named: 'account'),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        ).thenThrow(locked);
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(two),
      act: (b) => b.add(
        const MobileMoneyAccountNumberChangeRequested(
          account: orangeSn,
          phoneNumber: '+221770000099',
        ),
      ),
      expect: () => [
        const MobileMoneyAccountLoaded(two, submitting: true),
        const MobileMoneyAccountActionFailed(two, locked),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountActionFailed,
            properties: {
              'action': 'number_changed',
              'error_code': 'mobile-money-account-locked',
            },
          ),
        ).called(1);
      },
    );
  });

  group('MobileMoneyAccountRemoveRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'retire le compte puis relit la liste, event removed',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => one);
        when(() => repository.removeAccount(any())).thenAnswer((_) async {});
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(two),
      act: (b) => b.add(const MobileMoneyAccountRemoveRequested(orangeSn)),
      expect: () => [
        const MobileMoneyAccountLoaded(two, submitting: true),
        const MobileMoneyAccountActionDone(
          one,
          MobileMoneyAccountAction.removed,
        ),
      ],
      verify: (_) {
        verify(() => repository.removeAccount(orangeSn)).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountRemoved,
            properties: {'provider': 'ORANGE_SEN', 'accounts_count': 1},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      '409 mobile-money-account-locked : ActionFailed et event d\'échec',
      build: () {
        when(() => repository.removeAccount(any())).thenThrow(locked);
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(two),
      act: (b) => b.add(const MobileMoneyAccountRemoveRequested(orangeSn)),
      expect: () => [
        const MobileMoneyAccountLoaded(two, submitting: true),
        const MobileMoneyAccountActionFailed(two, locked),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountActionFailed,
            properties: {
              'action': 'removed',
              'error_code': 'mobile-money-account-locked',
            },
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'liste illisible après un retrait réussi : ActionDone sur la liste '
      'd\'avant, event tout de même émis sans accounts_count',
      build: () {
        when(
          () => repository.accounts(),
        ).thenThrow(const NetworkException('offline'));
        when(() => repository.removeAccount(any())).thenAnswer((_) async {});
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(two),
      act: (b) => b.add(const MobileMoneyAccountRemoveRequested(orangeSn)),
      expect: () => [
        const MobileMoneyAccountLoaded(two, submitting: true),
        const MobileMoneyAccountActionDone(
          two,
          MobileMoneyAccountAction.removed,
        ),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyPayoutAccountRemoved,
            properties: {'provider': 'ORANGE_SEN'},
          ),
        ).called(1);
      },
    );
  });

  group('la liste est toujours lue avant une écriture', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'sans liste connue : accounts() part avant addAccount()',
      build: () {
        when(() => repository.accounts()).thenAnswer((_) async => two);
        when(
          () => repository.addAccount(
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) async {});
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyAccountAddRequested(
          phoneNumber: '+221770000067',
          provider: 'ORANGE_SEN',
        ),
      ),
      expect: () => [
        const MobileMoneyAccountLoaded(two, submitting: true),
        const MobileMoneyAccountActionDone(two, MobileMoneyAccountAction.added),
      ],
      verify: (_) {
        verifyInOrder([
          () => repository.accounts(),
          () => repository.addAccount(
            phoneNumber: '+221770000067',
            provider: 'ORANGE_SEN',
          ),
          () => repository.accounts(),
        ]);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'après un chargement en échec puis un réessai : la liste est relue '
      'avant l\'écriture',
      build: () {
        var reads = 0;
        when(() => repository.accounts()).thenAnswer((_) async {
          reads++;
          if (reads == 1) throw const NetworkException('offline');
          return two;
        });
        when(() => repository.removeAccount(any())).thenAnswer((_) async {});
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyAccountsRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyAccountRemoveRequested(orangeSn));
      },
      expect: () => [
        const MobileMoneyAccountLoading(),
        const MobileMoneyAccountError(NetworkException('offline')),
        const MobileMoneyAccountLoaded(two, submitting: true),
        const MobileMoneyAccountActionDone(
          two,
          MobileMoneyAccountAction.removed,
        ),
      ],
      verify: (_) {
        verifyInOrder([
          () => repository.accounts(),
          () => repository.accounts(),
          () => repository.removeAccount(orangeSn),
          () => repository.accounts(),
        ]);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'lecture préalable en échec : Error, aucune écriture envoyée',
      build: () {
        when(
          () => repository.accounts(),
        ).thenThrow(const NetworkException('offline'));
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyAccountAddRequested(
          phoneNumber: '+221770000067',
          provider: 'ORANGE_SEN',
        ),
      ),
      expect: () => [
        const MobileMoneyAccountError(NetworkException('offline')),
      ],
      verify: (_) {
        verifyNever(
          () => repository.addAccount(
            phoneNumber: any(named: 'phoneNumber'),
            provider: any(named: 'provider'),
          ),
        );
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );
  });

  group('états : égalité de valeur', () {
    test('Loaded compare la liste et submitting', () {
      expect(
        const MobileMoneyAccountLoaded(one),
        const MobileMoneyAccountLoaded(one),
      );
      expect(
        const MobileMoneyAccountLoaded(one),
        isNot(const MobileMoneyAccountLoaded(one, submitting: true)),
      );
      expect(
        const MobileMoneyAccountLoaded(one),
        isNot(const MobileMoneyAccountLoaded(two)),
      );
    });

    test('ActionDone et ActionFailed comparent liste, action et erreur', () {
      expect(
        const MobileMoneyAccountActionDone(one, MobileMoneyAccountAction.added),
        isNot(
          const MobileMoneyAccountActionDone(
            one,
            MobileMoneyAccountAction.removed,
          ),
        ),
      );
      expect(
        const MobileMoneyAccountActionFailed(one, locked),
        const MobileMoneyAccountActionFailed(one, locked),
      );
      expect(
        const MobileMoneyAccountActionFailed(one, locked),
        isNot(
          const MobileMoneyAccountActionFailed(
            one,
            NetworkException('offline'),
          ),
        ),
      );
    });

    test('data : absente hors des états qui portent la liste', () {
      expect(const MobileMoneyAccountInitial().data, isNull);
      expect(const MobileMoneyAccountLoading().data, isNull);
      expect(const MobileMoneyAccountError(locked).data, isNull);
      expect(const MobileMoneyAccountLoaded(one).data, one);
    });
  });
}
