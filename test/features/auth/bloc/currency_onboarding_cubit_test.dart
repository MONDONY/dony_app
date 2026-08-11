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
    'passer : écrit uniquement le flag vu puis émet succès et trace le skip',
    build: build,
    act: (cubit) => cubit.skip(),
    expect: () => const [
      CurrencyOnboardingSaving(null),
      CurrencyOnboardingSuccess(),
    ],
    verify: (_) {
      verifyNever(() => repository.fetchPrefs());
      verifyNever(() => repository.updatePrefs(any()));
      verifyNever(() => prefs.put(HiveService.kCurrencyCode, any()));
      verifyInOrder([
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
