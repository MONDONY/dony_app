import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyAccountRepository extends Mock
    implements MobileMoneyAccountRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockMobileMoneyAccountRepository repository;
  late MockAnalyticsService analytics;

  const notConfigured = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.notConfigured,
  );
  const active = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.active,
    msisdnMasked: '+221 •• •• •• 67',
    providerLabel: 'Orange Money',
    country: 'SN',
    currency: 'XOF',
  );
  const disabled = MobileMoneyAccount(
    status: MobileMoneyAccountStatus.disabled,
    providerLabel: 'Orange Money',
    country: 'SN',
    currency: 'XOF',
  );
  const catalog = MobileMoneyProviderCatalog(
    country: 'CI',
    currency: 'XOF',
    msisdnMasked: '+225 •••• 36',
    detected: 'ORANGE_CIV',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_CIV',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave'),
    ],
  );

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

  group('MobileMoneyAccountRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'émet Loading puis Loaded avec le compte reçu',
      build: () {
        when(() => repository.get()).thenAnswer((_) async => active);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountRequested()),
      expect: () => [
        const MobileMoneyAccountLoading(),
        const MobileMoneyAccountLoaded(active),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'émet Loading puis Error sans compte si le chargement échoue',
      build: () {
        when(() => repository.get()).thenThrow(const OfflineException());
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountRequested()),
      expect: () => [
        const MobileMoneyAccountLoading(),
        isA<MobileMoneyAccountError>()
            .having((s) => s.error, 'error', isA<OfflineException>())
            .having((s) => s.account, 'account', isNull),
      ],
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );
  });

  group('MobileMoneyAccountActivateRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'sans compte courant : Updating(notConfigured) puis Loaded(nouveau), '
      'analytics avec provider et currency',
      build: () {
        when(() => repository.activate()).thenAnswer((_) async => active);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountActivateRequested()),
      expect: () => [
        const MobileMoneyAccountUpdating(notConfigured),
        const MobileMoneyAccountLoaded(active),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyAccountActivated,
            properties: {
              'provider': 'Orange Money',
              'providers_count': 0,
              'currency': 'XOF',
            },
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'avec un compte déjà chargé (désactivé) : Updating conserve ce compte, '
      'pas le compte par défaut',
      build: () {
        when(() => repository.get()).thenAnswer((_) async => disabled);
        when(() => repository.activate()).thenAnswer((_) async => active);
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyAccountRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyAccountActivateRequested());
      },
      skip: 2, // Loading, Loaded(disabled)
      expect: () => [
        const MobileMoneyAccountUpdating(disabled),
        const MobileMoneyAccountLoaded(active),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'une erreur précédente qui portait un compte sert de compte courant '
      'pour une nouvelle tentative',
      build: () {
        when(() => repository.activate()).thenAnswer((_) async => active);
        return bloc();
      },
      seed: () =>
          const MobileMoneyAccountError(OfflineException(), account: disabled),
      act: (b) => b.add(const MobileMoneyAccountActivateRequested()),
      expect: () => [
        const MobileMoneyAccountUpdating(disabled),
        const MobileMoneyAccountLoaded(active),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'provider et currency absents : propriétés "inconnu" et vide',
      build: () {
        when(() => repository.activate()).thenAnswer(
          (_) async =>
              const MobileMoneyAccount(status: MobileMoneyAccountStatus.active),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountActivateRequested()),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyAccountActivated,
            properties: {
              'provider': 'inconnu',
              'providers_count': 0,
              'currency': '',
            },
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      '422 mobile-money-disabled : Error garde le compte courant et le code '
      'intact, sans appel analytics',
      build: () {
        when(() => repository.activate()).thenThrow(
          const ValidationException(
            'Le mobile money est désactivé pour ce pays',
            code: 'mobile-money-disabled',
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountActivateRequested()),
      expect: () => [
        const MobileMoneyAccountUpdating(notConfigured),
        isA<MobileMoneyAccountError>()
            .having(
              (s) => s.error,
              'error',
              isA<ValidationException>().having(
                (e) => e.code,
                'code',
                'mobile-money-disabled',
              ),
            )
            .having((s) => s.account, 'account', notConfigured),
      ],
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );

    // ── Numéro de versement (compte Firebase sans téléphone) ──────────────

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'un numéro fourni dans l\'event est transmis tel quel au repository',
      build: () {
        when(
          () => repository.activate(phoneNumber: any(named: 'phoneNumber')),
        ).thenAnswer((_) async => active);
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyAccountActivateRequested(phoneNumber: '+221773456789'),
      ),
      verify: (_) {
        verify(
          () => repository.activate(phoneNumber: '+221773456789'),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      '422 mobile-money-phone-required : émet PhoneRequired (jamais Error), '
      'compte courant conservé, sans appel analytics',
      build: () {
        when(() => repository.activate()).thenThrow(
          const ValidationException(
            'Aucun numéro de téléphone disponible',
            code: 'mobile-money-phone-required',
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountActivateRequested()),
      expect: () => [
        const MobileMoneyAccountUpdating(notConfigured),
        const MobileMoneyAccountPhoneRequired(notConfigured),
      ],
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'un PhoneRequired précédent sert de compte courant pour la nouvelle '
      'tentative (avec numéro cette fois)',
      build: () {
        when(
          () => repository.activate(phoneNumber: any(named: 'phoneNumber')),
        ).thenAnswer((_) async => active);
        return bloc();
      },
      seed: () => const MobileMoneyAccountPhoneRequired(notConfigured),
      act: (b) => b.add(
        const MobileMoneyAccountActivateRequested(phoneNumber: '+221773456789'),
      ),
      expect: () => [
        const MobileMoneyAccountUpdating(notConfigured),
        const MobileMoneyAccountLoaded(active),
      ],
    );

    // ── Round 1 : editingNumber survit à un échec (Ruling A5) ─────────────
    // Une erreur pendant un changement de numéro (depuis la vue active) ne
    // doit jamais éjecter l'écran vers la vue active : PhoneRequired et Error
    // portent editingNumber pour que le formulaire reste affiché.

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'échec mobile-money-phone-required pendant un changement de numéro : '
      'PhoneRequired garde editingNumber true',
      build: () {
        when(
          () => repository.activate(phoneNumber: any(named: 'phoneNumber')),
        ).thenThrow(
          const ValidationException(
            'Aucun numéro de téléphone disponible',
            code: 'mobile-money-phone-required',
          ),
        );
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(active, editingNumber: true),
      act: (b) => b.add(
        const MobileMoneyAccountActivateRequested(phoneNumber: '+221773456789'),
      ),
      expect: () => [
        const MobileMoneyAccountUpdating(active, editingNumber: true),
        const MobileMoneyAccountPhoneRequired(active, editingNumber: true),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'échec réseau pendant un changement de numéro : Error garde '
      'editingNumber true (le formulaire reste affiché, pas la vue active)',
      build: () {
        when(
          () => repository.activate(phoneNumber: any(named: 'phoneNumber')),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(active, editingNumber: true),
      act: (b) => b.add(
        const MobileMoneyAccountActivateRequested(phoneNumber: '+221773456789'),
      ),
      expect: () => [
        const MobileMoneyAccountUpdating(active, editingNumber: true),
        isA<MobileMoneyAccountError>()
            .having((s) => s.account, 'account', active)
            .having((s) => s.editingNumber, 'editingNumber', isTrue),
      ],
    );
  });

  group('MobileMoneyAccountDisableRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'sans compte courant : Updating(notConfigured) puis Loaded(nouveau), '
      'analytics avec provider et currency',
      build: () {
        when(() => repository.disable()).thenAnswer((_) async => disabled);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyAccountDisableRequested()),
      expect: () => [
        const MobileMoneyAccountUpdating(notConfigured),
        const MobileMoneyAccountLoaded(disabled),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyAccountDisabled,
            properties: {'provider': 'Orange Money', 'currency': 'XOF'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'avec un compte actif déjà chargé : Updating conserve ce compte',
      build: () {
        when(() => repository.get()).thenAnswer((_) async => active);
        when(() => repository.disable()).thenAnswer((_) async => disabled);
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyAccountRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyAccountDisableRequested());
      },
      skip: 2, // Loading, Loaded(active)
      expect: () => [
        const MobileMoneyAccountUpdating(active),
        const MobileMoneyAccountLoaded(disabled),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'erreur réseau : Error garde le compte courant, sans appel analytics',
      build: () {
        when(() => repository.get()).thenAnswer((_) async => active);
        when(() => repository.disable()).thenThrow(const OfflineException());
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyAccountRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyAccountDisableRequested());
      },
      skip: 2, // Loading, Loaded(active)
      expect: () => [
        const MobileMoneyAccountUpdating(active),
        isA<MobileMoneyAccountError>()
            .having((s) => s.error, 'error', isA<OfflineException>())
            .having((s) => s.account, 'account', active),
      ],
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        );
      },
    );
  });

  group('MobileMoneyAccountProvidersRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'émet ProvidersLoading puis ProvidersLoaded, compte courant conservé',
      build: () {
        when(
          () => repository.providers(phoneNumber: '+225070809'),
        ).thenAnswer((_) async => catalog);
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(notConfigured),
      act: (b) => b.add(
        const MobileMoneyAccountProvidersRequested(phoneNumber: '+225070809'),
      ),
      expect: () => [
        const MobileMoneyAccountProvidersLoading(notConfigured),
        const MobileMoneyAccountProvidersLoaded(notConfigured, catalog),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'sans numéro (feuille) : interroge le numéro enregistré',
      build: () {
        when(() => repository.providers()).thenAnswer((_) async => catalog);
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(active),
      act: (b) => b.add(const MobileMoneyAccountProvidersRequested()),
      expect: () => [
        const MobileMoneyAccountProvidersLoading(active),
        const MobileMoneyAccountProvidersLoaded(active, catalog),
      ],
      verify: (_) => verify(() => repository.providers()).called(1),
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'échec : ProvidersError avec l\'erreur déballée, jamais Error (pas de snackbar)',
      build: () {
        when(
          () => repository.providers(phoneNumber: '+33612'),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(notConfigured),
      act: (b) => b.add(
        const MobileMoneyAccountProvidersRequested(phoneNumber: '+33612'),
      ),
      expect: () => [
        const MobileMoneyAccountProvidersLoading(notConfigured),
        isA<MobileMoneyAccountProvidersError>()
            .having((s) => s.error, 'error', isA<OfflineException>())
            .having((s) => s.account, 'account', notConfigured),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'conserve editingNumber pendant le catalogue',
      build: () {
        when(
          () => repository.providers(phoneNumber: '+225070809'),
        ).thenAnswer((_) async => catalog);
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(active, editingNumber: true),
      act: (b) => b.add(
        const MobileMoneyAccountProvidersRequested(phoneNumber: '+225070809'),
      ),
      expect: () => [
        const MobileMoneyAccountProvidersLoading(active, editingNumber: true),
        const MobileMoneyAccountProvidersLoaded(
          active,
          catalog,
          editingNumber: true,
        ),
      ],
    );
  });

  group('MobileMoneyAccountProvidersCleared', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'revient à Loaded avec le compte courant',
      build: bloc,
      seed: () =>
          const MobileMoneyAccountProvidersLoaded(notConfigured, catalog),
      act: (b) => b.add(const MobileMoneyAccountProvidersCleared()),
      expect: () => [const MobileMoneyAccountLoaded(notConfigured)],
    );
  });

  group('MobileMoneyAccountActivateRequested avec réseaux', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'transmet numéro et réseaux au repository, émet Updating puis Loaded sans édition',
      build: () {
        when(
          () => repository.activate(
            phoneNumber: '+225070809',
            providers: ['ORANGE_CIV', 'WAVE_CIV'],
          ),
        ).thenAnswer((_) async => active);
        return bloc();
      },
      seed: () => const MobileMoneyAccountProvidersLoaded(
        notConfigured,
        catalog,
        editingNumber: true,
      ),
      act: (b) => b.add(
        const MobileMoneyAccountActivateRequested(
          phoneNumber: '+225070809',
          providers: ['ORANGE_CIV', 'WAVE_CIV'],
        ),
      ),
      expect: () => [
        const MobileMoneyAccountUpdating(notConfigured, editingNumber: true),
        const MobileMoneyAccountLoaded(active),
      ],
    );
  });

  group('MobileMoneyAccountProvidersUpdateRequested', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'émet Updating puis Loaded avec le compte renvoyé',
      build: () {
        when(
          () => repository.updateProviders(['WAVE_CIV']),
        ).thenAnswer((_) async => active);
        return bloc();
      },
      seed: () => const MobileMoneyAccountProvidersLoaded(active, catalog),
      act: (b) =>
          b.add(const MobileMoneyAccountProvidersUpdateRequested(['WAVE_CIV'])),
      expect: () => [
        const MobileMoneyAccountUpdating(active),
        const MobileMoneyAccountLoaded(active),
      ],
    );

    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'échec : Error avec le compte conservé',
      build: () {
        when(
          () => repository.updateProviders(['WAVE_CIV']),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      seed: () => const MobileMoneyAccountLoaded(active),
      act: (b) =>
          b.add(const MobileMoneyAccountProvidersUpdateRequested(['WAVE_CIV'])),
      expect: () => [
        const MobileMoneyAccountUpdating(active),
        isA<MobileMoneyAccountError>().having(
          (s) => s.account,
          'account',
          active,
        ),
      ],
    );
  });

  group('changement de numéro', () {
    blocTest<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      'ChangeNumberRequested passe en édition, ChangeNumberCancelled en sort',
      build: bloc,
      seed: () => const MobileMoneyAccountLoaded(active),
      act: (b) => b
        ..add(const MobileMoneyAccountChangeNumberRequested())
        ..add(const MobileMoneyAccountChangeNumberCancelled()),
      expect: () => [
        const MobileMoneyAccountLoaded(active, editingNumber: true),
        const MobileMoneyAccountLoaded(active),
      ],
    );
  });
}
