import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/currency_onboarding_cubit.dart';
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

const _cadPrefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'CAD',
  pickupRadiusKm: 10,
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

const _unsupportedPrefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'JPY',
  pickupRadiusKm: 10,
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

void main() {
  late MockBusinessPrefsRepository repository;
  late MockBox prefs;
  late MockAnalyticsService analytics;

  CurrencyOnboardingCubit build() =>
      CurrencyOnboardingCubit(repository, prefs, analytics);

  setUpAll(() {
    registerFallbackValue(FakeUserBusinessPrefsDto());
  });

  setUp(() {
    repository = MockBusinessPrefsRepository();
    prefs = MockBox();
    analytics = MockAnalyticsService();

    when(() => repository.fetchPrefs()).thenAnswer((_) async => _prefs);
    when(() => repository.updatePrefs(any())).thenAnswer((_) async {});
    when(() => prefs.put(any(), any())).thenAnswer((_) async {});
    when(() => analytics.logEvent(any())).thenAnswer((_) async {});
  });

  blocTest<CurrencyOnboardingCubit, CurrencyOnboardingState>(
    'sélection réussie : persiste serveur puis Hive, émet succès et trace sans valeur sensible',
    build: build,
    act: (cubit) => cubit.select('XOF'),
    expect: () => const [
      CurrencyOnboardingSaving('XOF'),
      CurrencyOnboardingSuccess(),
    ],
    verify: (_) {
      verifyInOrder([
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(
          any(
            that: isA<UserBusinessPrefsDto>()
                .having((dto) => dto.currencyCode, 'currencyCode', 'XOF')
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
        () => prefs.put(HiveService.kCurrencyCode, 'XOF'),
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSelected),
      ]);
    },
  );

  blocTest<CurrencyOnboardingCubit, CurrencyOnboardingState>(
    'échec backend : n’écrit pas Hive, n’émet pas succès et permet une nouvelle tentative',
    setUp: () {
      when(() => repository.fetchPrefs()).thenThrow(Exception('offline'));
    },
    build: build,
    act: (cubit) => cubit.select('XAF'),
    expect: () => const [
      CurrencyOnboardingSaving('XAF'),
      CurrencyOnboardingError('Impossible d’enregistrer la devise. Réessayez.'),
    ],
    verify: (_) {
      verifyNever(() => prefs.put(any(), any()));
      verifyNever(() => analytics.logEvent(any()));
    },
  );

  blocTest<CurrencyOnboardingCubit, CurrencyOnboardingState>(
    'passer : refuse une devise backend inconnue sans marquer l’onboarding vu',
    setUp: () {
      when(() => repository.fetchPrefs())
          .thenAnswer((_) async => _unsupportedPrefs);
    },
    build: build,
    act: (cubit) => cubit.skip(),
    expect: () => const [
      CurrencyOnboardingSaving(null),
      CurrencyOnboardingError('Impossible d’enregistrer ce choix. Réessayez.'),
    ],
    verify: (_) {
      verifyNever(() => prefs.put(HiveService.kCurrencyCode, any()));
      verifyNever(() => prefs.put(HiveService.kCurrencyOnboardingSeen, true));
      verifyNever(() => analytics.logEvent(AnalyticsEvents.currencyOnboardingSkipped));
    },
  );

  test(
    'échec Hive sur la devise : émet erreur sans flag ni succès et permet retry',
    () async {
      var currencyWriteAttempts = 0;
      when(() => prefs.put(HiveService.kCurrencyCode, 'XOF')).thenAnswer((
        _,
      ) async {
        currencyWriteAttempts += 1;
        if (currencyWriteAttempts == 1) {
          throw StateError('hive unavailable');
        }
      });
      final cubit = build();
      addTearDown(cubit.close);
      final failedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CurrencyOnboardingSaving('XOF'),
          CurrencyOnboardingError(
            'Impossible d’enregistrer la devise. Réessayez.',
          ),
        ]),
      );

      await cubit.select('XOF');

      await failedStates;

      expect(
        cubit.state,
        const CurrencyOnboardingError(
          'Impossible d’enregistrer la devise. Réessayez.',
        ),
      );
      verifyNever(() => prefs.put(HiveService.kCurrencyOnboardingSeen, true));
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSelected),
      );

      final retriedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CurrencyOnboardingSaving('XOF'),
          CurrencyOnboardingSuccess(),
        ]),
      );
      await cubit.select('XOF');

      await retriedStates;

      expect(cubit.state, const CurrencyOnboardingSuccess());
      expect(currencyWriteAttempts, 2);
      verifyInOrder([
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(any()),
        () => prefs.put(HiveService.kCurrencyCode, 'XOF'),
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(any()),
        () => prefs.put(HiveService.kCurrencyCode, 'XOF'),
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSelected),
      ]);
    },
  );

  test(
    'échec Hive sur le flag vu : émet erreur sans succès et permet retry',
    () async {
      var currencyWriteAttempts = 0;
      var seenWriteAttempts = 0;
      when(() => prefs.put(HiveService.kCurrencyCode, 'XAF')).thenAnswer((
        _,
      ) async {
        currencyWriteAttempts += 1;
      });
      when(
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
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
          CurrencyOnboardingSaving('XAF'),
          CurrencyOnboardingError(
            'Impossible d’enregistrer la devise. Réessayez.',
          ),
        ]),
      );

      await cubit.select('XAF');

      await failedStates;

      expect(
        cubit.state,
        const CurrencyOnboardingError(
          'Impossible d’enregistrer la devise. Réessayez.',
        ),
      );
      expect(currencyWriteAttempts, 1);
      expect(seenWriteAttempts, 1);
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSelected),
      );

      final retriedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CurrencyOnboardingSaving('XAF'),
          CurrencyOnboardingSuccess(),
        ]),
      );
      await cubit.select('XAF');

      await retriedStates;

      expect(cubit.state, const CurrencyOnboardingSuccess());
      expect(currencyWriteAttempts, 2);
      expect(seenWriteAttempts, 2);
      verifyInOrder([
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(any()),
        () => prefs.put(HiveService.kCurrencyCode, 'XAF'),
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(any()),
        () => prefs.put(HiveService.kCurrencyCode, 'XAF'),
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSelected),
      ]);
    },
  );

  blocTest<CurrencyOnboardingCubit, CurrencyOnboardingState>(
    'passer : relit la devise serveur puis la met en cache avant le flag vu',
    setUp: () {
      when(() => repository.fetchPrefs()).thenAnswer((_) async => _cadPrefs);
    },
    build: build,
    act: (cubit) => cubit.skip(),
    expect: () => const [
      CurrencyOnboardingSaving(null),
      CurrencyOnboardingSuccess(),
    ],
    verify: (_) {
      verifyNever(() => repository.updatePrefs(any()));
      verifyInOrder([
        () => repository.fetchPrefs(),
        () => prefs.put(HiveService.kCurrencyCode, 'CAD'),
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSkipped),
      ]);
    },
  );

  test(
    'échec Hive du skip : émet erreur sans succès et permet retry',
    () async {
      var seenWriteAttempts = 0;
      when(
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
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
          CurrencyOnboardingSaving(null),
          CurrencyOnboardingError(
            'Impossible d’enregistrer ce choix. Réessayez.',
          ),
        ]),
      );

      await cubit.skip();

      await failedStates;

      expect(
        cubit.state,
        const CurrencyOnboardingError(
          'Impossible d’enregistrer ce choix. Réessayez.',
        ),
      );
      verifyNever(() => repository.updatePrefs(any()));
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSkipped),
      );

      final retriedStates = expectLater(
        cubit.stream.take(2),
        emitsInOrder(const [
          CurrencyOnboardingSaving(null),
          CurrencyOnboardingSuccess(),
        ]),
      );
      await cubit.skip();

      await retriedStates;

      expect(cubit.state, const CurrencyOnboardingSuccess());
      expect(seenWriteAttempts, 2);
      verifyInOrder([
        () => repository.fetchPrefs(),
        () => prefs.put(HiveService.kCurrencyCode, 'EUR'),
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
        () => repository.fetchPrefs(),
        () => prefs.put(HiveService.kCurrencyCode, 'EUR'),
        () => prefs.put(HiveService.kCurrencyOnboardingSeen, true),
        () => analytics.logEvent(AnalyticsEvents.currencyOnboardingSkipped),
      ]);
    },
  );

  test('ignore le second tap pendant la sauvegarde', () async {
    final fetchCompleter = Completer<UserBusinessPrefsDto>();
    when(
      () => repository.fetchPrefs(),
    ).thenAnswer((_) => fetchCompleter.future);
    final cubit = build();
    addTearDown(cubit.close);

    final first = cubit.select('EUR');
    await Future<void>.delayed(Duration.zero);
    final second = cubit.select('XOF');
    fetchCompleter.complete(_prefs);
    await Future.wait([first, second]);

    verify(() => repository.fetchPrefs()).called(1);
    verify(() => repository.updatePrefs(any())).called(1);
    verify(() => prefs.put(HiveService.kCurrencyCode, 'EUR')).called(1);
  });
}
