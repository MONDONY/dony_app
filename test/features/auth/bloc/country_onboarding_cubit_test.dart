import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/country_onboarding_cubit.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessPrefsRepository extends Mock
    implements BusinessPrefsRepository {}

class MockBox extends Mock implements Box<dynamic> {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class FakeUserBusinessPrefsDto extends Fake implements UserBusinessPrefsDto {}

const _prefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'EUR',
  pickupRadiusKm: 10,
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

void main() {
  late MockBusinessPrefsRepository repository;
  late MockBox prefs;
  late MockAnalyticsService analytics;

  CountryOnboardingCubit build() =>
      CountryOnboardingCubit(repository, prefs, analytics);

  setUpAll(() {
    registerFallbackValue(FakeUserBusinessPrefsDto());
  });

  setUp(() {
    repository = MockBusinessPrefsRepository();
    prefs = MockBox();
    analytics = MockAnalyticsService();

    when(() => repository.fetchPrefs()).thenAnswer((_) async => _prefs);
    when(() => repository.updatePrefs(any())).thenAnswer((_) async => _prefs);
    when(() => prefs.put(any(), any())).thenAnswer((_) async {});
    when(() => analytics.logEvent(any())).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<CountryOnboardingCubit, CountryOnboardingState>(
    'select enregistre le pays et memorise le passage',
    build: build,
    act: (cubit) => cubit.select('CA'),
    expect: () => const [
      CountryOnboardingSaving('CA'),
      CountryOnboardingSuccess(),
    ],
    verify: (_) {
      verifyInOrder([
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(
          any(
            that: isA<UserBusinessPrefsDto>().having(
              (dto) => dto.country,
              'country',
              'CA',
            ),
          ),
        ),
        () => prefs.put(HiveService.kCountryCode, 'CA'),
        () => prefs.put(HiveService.kCurrencyCode, 'EUR'),
        () => prefs.put(HiveService.kCountryOnboardingSeen, true),
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSelected),
      ]);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.onboardingStepCompleted,
          properties: {'step': 'country'},
        ),
      ).called(1);
    },
  );

  blocTest<CountryOnboardingCubit, CountryOnboardingState>(
    'select met en cache la devise renvoyée par le serveur, pas celle du catalogue local',
    setUp: () {
      // Le catalogue local associerait CAD au Canada : si le cubit dérivait la
      // devise côté client, cette valeur serveur (volontairement différente)
      // ne serait jamais écrite.
      when(() => repository.updatePrefs(any())).thenAnswer(
        (_) async => _prefs.copyWith(currencyCode: 'XOF', country: 'CA'),
      );
    },
    build: build,
    act: (cubit) => cubit.select('CA'),
    verify: (_) {
      verify(() => prefs.put(HiveService.kCurrencyCode, 'XOF')).called(1);
      verifyNever(() => prefs.put(HiveService.kCurrencyCode, 'CAD'));
    },
  );

  blocTest<CountryOnboardingCubit, CountryOnboardingState>(
    'select conserve les autres champs des préférences via copyWith',
    build: build,
    act: (cubit) => cubit.select('SN'),
    verify: (_) {
      verify(
        () => repository.updatePrefs(
          any(
            that: isA<UserBusinessPrefsDto>()
                .having((dto) => dto.country, 'country', 'SN')
                .having(
                  (dto) => dto.weightUnit,
                  'weightUnit',
                  _prefs.weightUnit,
                )
                .having(
                  (dto) => dto.pickupRadiusKm,
                  'pickupRadiusKm',
                  _prefs.pickupRadiusKm,
                ),
          ),
        ),
      ).called(1);
    },
  );

  blocTest<CountryOnboardingCubit, CountryOnboardingState>(
    'échec backend : n’écrit pas Hive, n’émet pas succès et permet une nouvelle tentative',
    setUp: () {
      when(() => repository.fetchPrefs()).thenThrow(Exception('offline'));
    },
    build: build,
    act: (cubit) => cubit.select('CI'),
    expect: () => const [
      CountryOnboardingSaving('CI'),
      CountryOnboardingError('Impossible d’enregistrer le pays. Réessayez.'),
    ],
    verify: (_) {
      verifyNever(() => repository.updatePrefs(any()));
      verifyNever(() => prefs.put(any(), any()));
      verifyNever(() => analytics.logEvent(any()));
    },
  );

  test(
    'échec Hive sur le pays : émet erreur sans flag ni succès et permet retry',
    () async {
      var countryWriteAttempts = 0;
      when(() => prefs.put(HiveService.kCountryCode, 'CA')).thenAnswer((
        _,
      ) async {
        countryWriteAttempts += 1;
        if (countryWriteAttempts == 1) {
          throw StateError('hive unavailable');
        }
      });
      final cubit = build();
      addTearDown(cubit.close);
      final failedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CountryOnboardingSaving('CA'),
          CountryOnboardingError(
            'Impossible d’enregistrer le pays. Réessayez.',
          ),
        ]),
      );

      await cubit.select('CA');

      await failedStates;

      expect(
        cubit.state,
        const CountryOnboardingError(
          'Impossible d’enregistrer le pays. Réessayez.',
        ),
      );
      verifyNever(() => prefs.put(HiveService.kCountryOnboardingSeen, true));
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSelected),
      );

      final retriedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CountryOnboardingSaving('CA'),
          CountryOnboardingSuccess(),
        ]),
      );
      await cubit.select('CA');

      await retriedStates;

      expect(cubit.state, const CountryOnboardingSuccess());
      expect(countryWriteAttempts, 2);
      verify(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSelected),
      ).called(1);
    },
  );

  test(
    'échec Hive sur le flag vu : émet erreur sans succès et permet retry',
    () async {
      var seenWriteAttempts = 0;
      when(
        () => prefs.put(HiveService.kCountryOnboardingSeen, true),
      ).thenAnswer((_) async {
        seenWriteAttempts += 1;
        if (seenWriteAttempts == 1) {
          throw StateError('hive unavailable');
        }
      });
      final cubit = build();
      addTearDown(cubit.close);
      final failedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CountryOnboardingSaving('CM'),
          CountryOnboardingError(
            'Impossible d’enregistrer le pays. Réessayez.',
          ),
        ]),
      );

      await cubit.select('CM');

      await failedStates;

      expect(seenWriteAttempts, 1);
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSelected),
      );

      final retriedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CountryOnboardingSaving('CM'),
          CountryOnboardingSuccess(),
        ]),
      );
      await cubit.select('CM');

      await retriedStates;

      expect(cubit.state, const CountryOnboardingSuccess());
      expect(seenWriteAttempts, 2);
      verify(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSelected),
      ).called(1);
    },
  );

  test('select ignore le second tap pendant la sauvegarde', () async {
    final fetchCompleter = Completer<UserBusinessPrefsDto>();
    when(
      () => repository.fetchPrefs(),
    ).thenAnswer((_) => fetchCompleter.future);
    final cubit = build();
    addTearDown(cubit.close);

    final first = cubit.select('FR');
    await Future<void>.delayed(Duration.zero);
    final second = cubit.select('CA');
    fetchCompleter.complete(_prefs);
    await Future.wait([first, second]);

    verify(() => repository.fetchPrefs()).called(1);
    verify(() => repository.updatePrefs(any())).called(1);
    verify(() => prefs.put(HiveService.kCountryCode, 'FR')).called(1);
  });

  blocTest<CountryOnboardingCubit, CountryOnboardingState>(
    'skip memorise le passage sans ecrire de pays',
    build: build,
    act: (cubit) => cubit.skip(),
    expect: () => const [
      CountryOnboardingSaving(null),
      CountryOnboardingSuccess(),
    ],
    verify: (_) {
      // Le pays reste vide, mais la devise par défaut du serveur est mise en
      // cache : sans elle, tous les plafonds de prix retomberaient sur EUR.
      verify(() => repository.fetchPrefs()).called(1);
      verifyNever(() => repository.updatePrefs(any()));
      verifyNever(() => prefs.put(HiveService.kCountryCode, any()));
      verify(() => prefs.put(HiveService.kCurrencyCode, 'EUR')).called(1);
      verify(
        () => prefs.put(HiveService.kCountryOnboardingSeen, true),
      ).called(1);
      verify(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.onboardingStepSkipped,
          properties: {'step': 'country'},
        ),
      ).called(1);
    },
  );

  blocTest<CountryOnboardingCubit, CountryOnboardingState>(
    'continueAsSenderOnly memorise le passage et bloque le parcours voyageur',
    build: build,
    act: (cubit) => cubit.continueAsSenderOnly(),
    expect: () => const [
      CountryOnboardingSaving(null),
      CountryOnboardingSuccess(),
    ],
    verify: (_) {
      verifyNever(() => repository.updatePrefs(any()));
      verifyNever(() => prefs.put(HiveService.kCountryCode, any()));
      verify(
        () => prefs.put(HiveService.kTravelerCountryUnsupported, true),
      ).called(1);
      verify(
        () => prefs.put(HiveService.kCountryOnboardingSeen, true),
      ).called(1);
      verify(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.onboardingStepSkipped,
          properties: {'step': 'country'},
        ),
      ).called(1);
    },
  );

  blocTest<CountryOnboardingCubit, CountryOnboardingState>(
    'skip tolère un échec réseau : le passage est mémorisé quand même',
    setUp: () {
      when(() => repository.fetchPrefs()).thenThrow(Exception('offline'));
    },
    build: build,
    act: (cubit) => cubit.skip(),
    expect: () => const [
      CountryOnboardingSaving(null),
      CountryOnboardingSuccess(),
    ],
    verify: (_) {
      verifyNever(() => prefs.put(HiveService.kCurrencyCode, any()));
      verify(
        () => prefs.put(HiveService.kCountryOnboardingSeen, true),
      ).called(1);
    },
  );

  test(
    'échec Hive du skip : émet erreur sans succès et permet retry',
    () async {
      var seenWriteAttempts = 0;
      when(
        () => prefs.put(HiveService.kCountryOnboardingSeen, true),
      ).thenAnswer((_) async {
        seenWriteAttempts += 1;
        if (seenWriteAttempts == 1) {
          throw StateError('hive unavailable');
        }
      });
      final cubit = build();
      addTearDown(cubit.close);
      final failedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CountryOnboardingSaving(null),
          CountryOnboardingError(
            'Impossible d’enregistrer ce choix. Réessayez.',
          ),
        ]),
      );

      await cubit.skip();

      await failedStates;

      expect(
        cubit.state,
        const CountryOnboardingError(
          'Impossible d’enregistrer ce choix. Réessayez.',
        ),
      );
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped),
      );

      final retriedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CountryOnboardingSaving(null),
          CountryOnboardingSuccess(),
        ]),
      );
      await cubit.skip();

      await retriedStates;

      expect(cubit.state, const CountryOnboardingSuccess());
      expect(seenWriteAttempts, 2);
      verify(
        () => analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped),
      ).called(1);
    },
  );

  test('skip ignore le second tap pendant la sauvegarde', () async {
    final putCompleter = Completer<void>();
    when(
      () => prefs.put(HiveService.kCountryOnboardingSeen, true),
    ).thenAnswer((_) => putCompleter.future);
    final cubit = build();
    addTearDown(cubit.close);

    final first = cubit.skip();
    await Future<void>.delayed(Duration.zero);
    final second = cubit.skip();
    putCompleter.complete();
    await Future.wait([first, second]);

    verify(() => prefs.put(HiveService.kCountryOnboardingSeen, true)).called(1);
    verify(
      () => analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped),
    ).called(1);
  });
}
