import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessPrefsRepository extends Mock
    implements BusinessPrefsRepository {}

class MockBox extends Mock implements Box<dynamic> {}

const _defaultDto = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'EUR',
  pickupRadiusKm: 10,
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

void main() {
  late MockBusinessPrefsRepository mockRepo;
  late MockBox mockBox;

  setUpAll(() {
    registerFallbackValue(_defaultDto);
  });

  setUp(() {
    mockRepo = MockBusinessPrefsRepository();
    mockBox = MockBox();
    when(
      () => mockBox.get(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.get(any())).thenReturn(null);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockBox.delete(any())).thenAnswer((_) async {});
    when(() => mockRepo.updatePrefs(any())).thenAnswer((_) async {});
  });

  BusinessPrefsBloc build() => BusinessPrefsBloc(mockRepo, mockBox);

  // Depuis que `_putOrRollback` porte `isSyncing`, chaque réglage émet le même
  // cycle : valeur optimiste, début de synchro, fin de synchro (ou rollback).
  final syncStarted = isA<BusinessPrefsState>().having(
    (s) => s.isSyncing,
    'isSyncing',
    true,
  );
  final syncSettled = isA<BusinessPrefsState>().having(
    (s) => s.isSyncing,
    'isSyncing',
    false,
  );

  group('état initial', () {
    test('lit les 3 champs existants depuis Hive avec valeurs par défaut', () {
      final bloc = build();
      expect(bloc.state.weightUnit, 'kg');
      expect(bloc.state.currencyCode, 'EUR');
      expect(bloc.state.pickupRadiusKm, 10);
      bloc.close();
    });

    test('lit les nouveaux champs depuis Hive si présents', () {
      when(
        () => mockBox.get(
          HiveService.kDefaultPackageWeight,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(30);
      when(
        () => mockBox.get(
          HiveService.kMinBidPrice,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(10);
      when(() => mockBox.get(HiveService.kContactMode)).thenReturn('call');
      when(() => mockBox.get(HiveService.kResponseDelay)).thenReturn(2);
      final bloc = build();
      expect(bloc.state.defaultPackageWeightKg, 30);
      expect(bloc.state.minBidPriceEur, 10);
      expect(bloc.state.contactMode, 'call');
      expect(bloc.state.responseDelayHours, 2);
      bloc.close();
    });

    test('contactMode et responseDelayHours sont null si absents de Hive', () {
      final bloc = build();
      expect(bloc.state.contactMode, isNull);
      expect(bloc.state.responseDelayHours, isNull);
      bloc.close();
    });

    test('country est lu depuis Hive si présent, sinon null', () {
      final blocSansPays = build();
      expect(blocSansPays.state.country, isNull);
      blocSansPays.close();

      when(() => mockBox.get(HiveService.kCountryCode)).thenReturn('SN');
      final blocAvecPays = build();
      expect(blocAvecPays.state.country, 'SN');
      blocAvecPays.close();
    });
  });

  group('BusinessPrefsSyncRequested', () {
    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'émet isSyncing:true puis met à jour le state depuis API',
      setUp: () {
        when(() => mockRepo.fetchPrefs()).thenAnswer(
          (_) async => const UserBusinessPrefsDto(
            weightUnit: 'lbs',
            currencyCode: 'XOF',
            pickupRadiusKm: 20,
            defaultPackageWeightKg: 30,
            minBidPriceEur: 5,
            contactMode: 'both',
            responseDelayHours: 6,
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const BusinessPrefsSyncRequested()),
      expect: () => [
        isA<BusinessPrefsState>().having((s) => s.isSyncing, 'isSyncing', true),
        isA<BusinessPrefsState>()
            .having((s) => s.isSyncing, 'isSyncing', false)
            .having((s) => s.weightUnit, 'weightUnit', 'lbs')
            .having((s) => s.currencyCode, 'currencyCode', 'XOF')
            .having((s) => s.contactMode, 'contactMode', 'both')
            .having((s) => s.responseDelayHours, 'responseDelayHours', 6),
      ],
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'erreur API : conserve le state Hive existant, isSyncing:false',
      setUp: () {
        when(() => mockRepo.fetchPrefs()).thenThrow(Exception('network'));
      },
      build: build,
      act: (bloc) => bloc.add(const BusinessPrefsSyncRequested()),
      expect: () => [
        isA<BusinessPrefsState>().having((s) => s.isSyncing, 'isSyncing', true),
        isA<BusinessPrefsState>().having(
          (s) => s.isSyncing,
          'isSyncing',
          false,
        ),
      ],
    );
  });

  group('DefaultWeightChanged', () {
    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'met à jour le poids + écrit Hive + appelle PUT',
      build: build,
      act: (bloc) => bloc.add(const DefaultWeightChanged(30)),
      expect: () => [
        isA<BusinessPrefsState>().having(
          (s) => s.defaultPackageWeightKg,
          'kg',
          30,
        ),
        syncStarted,
        syncSettled,
      ],
      verify: (_) {
        verify(
          () => mockBox.put(HiveService.kDefaultPackageWeight, 30),
        ).called(1);
        verify(() => mockRepo.updatePrefs(any())).called(1);
      },
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'erreur PUT : rollback Hive + émet errorMessage',
      setUp: () {
        when(() => mockRepo.updatePrefs(any())).thenThrow(Exception('server'));
      },
      build: build,
      seed: () => const BusinessPrefsState(),
      act: (bloc) => bloc.add(const DefaultWeightChanged(30)),
      expect: () => [
        isA<BusinessPrefsState>().having(
          (s) => s.defaultPackageWeightKg,
          'kg',
          30,
        ),
        syncStarted,
        isA<BusinessPrefsState>()
            .having((s) => s.defaultPackageWeightKg, 'kg', 23)
            .having((s) => s.errorMessage, 'error', isNotNull),
      ],
    );
  });

  group('MinBidPriceChanged', () {
    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'met à jour le prix + écrit Hive',
      build: build,
      act: (bloc) => bloc.add(const MinBidPriceChanged(10)),
      expect: () => [
        isA<BusinessPrefsState>().having((s) => s.minBidPriceEur, 'eur', 10),
        syncStarted,
        syncSettled,
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kMinBidPrice, 10)).called(1),
    );
  });

  group('ContactModeChanged', () {
    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'mode "call" : écrit Hive + émet le state',
      build: build,
      act: (bloc) => bloc.add(const ContactModeChanged('call')),
      expect: () => [
        isA<BusinessPrefsState>().having((s) => s.contactMode, 'mode', 'call'),
        syncStarted,
        syncSettled,
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kContactMode, 'call')).called(1),
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'null : supprime la clé Hive + contactMode null',
      build: build,
      seed: () => const BusinessPrefsState(contactMode: 'call'),
      act: (bloc) => bloc.add(const ContactModeChanged(null)),
      expect: () => [
        isA<BusinessPrefsState>().having((s) => s.contactMode, 'mode', isNull),
        syncStarted,
        syncSettled,
      ],
      verify: (_) =>
          verify(() => mockBox.delete(HiveService.kContactMode)).called(1),
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'erreur PUT : rollback au mode précédent',
      setUp: () {
        when(() => mockRepo.updatePrefs(any())).thenThrow(Exception('server'));
      },
      build: build,
      seed: () => const BusinessPrefsState(contactMode: 'message'),
      act: (bloc) => bloc.add(const ContactModeChanged('call')),
      expect: () => [
        isA<BusinessPrefsState>().having((s) => s.contactMode, 'mode', 'call'),
        syncStarted,
        isA<BusinessPrefsState>()
            .having((s) => s.contactMode, 'mode', 'message')
            .having((s) => s.errorMessage, 'error', isNotNull),
      ],
    );
  });

  group('ResponseDelayChanged', () {
    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      '2h : écrit Hive',
      build: build,
      act: (bloc) => bloc.add(const ResponseDelayChanged(2)),
      expect: () => [
        isA<BusinessPrefsState>().having((s) => s.responseDelayHours, 'h', 2),
        syncStarted,
        syncSettled,
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kResponseDelay, 2)).called(1),
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'null : supprime la clé Hive',
      build: build,
      seed: () => const BusinessPrefsState(responseDelayHours: 6),
      act: (bloc) => bloc.add(const ResponseDelayChanged(null)),
      expect: () => [
        isA<BusinessPrefsState>().having(
          (s) => s.responseDelayHours,
          'h',
          isNull,
        ),
        syncStarted,
        syncSettled,
      ],
      verify: (_) =>
          verify(() => mockBox.delete(HiveService.kResponseDelay)).called(1),
    );
  });

  group('CountryChanged', () {
    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'écrit Hive, PUT le pays, puis relit le state complet — la devise '
      'recalculée par le serveur n\'est jamais devinée côté client',
      setUp: () {
        when(() => mockRepo.fetchPrefs()).thenAnswer(
          (_) async => const UserBusinessPrefsDto(
            weightUnit: 'kg',
            currencyCode: 'CAD',
            pickupRadiusKm: 10,
            defaultPackageWeightKg: 23,
            minBidPriceEur: 0,
            country: 'CA',
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const CountryChanged('CA')),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.country, 'country', 'CA'),
        isA<BusinessPrefsState>()
            .having((s) => s.isSyncing, 'isSyncing', false)
            .having((s) => s.country, 'country', 'CA')
            .having((s) => s.currencyCode, 'currencyCode', 'CAD'),
      ],
      verify: (_) {
        // 2 écritures : la valeur optimiste, puis la reconfirmation par
        // `_writeToHive(refreshed)` une fois le state complet relu.
        verify(() => mockBox.put(HiveService.kCountryCode, 'CA')).called(2);
        verify(() => mockRepo.updatePrefs(any())).called(1);
        verify(() => mockRepo.fetchPrefs()).called(1);
      },
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'erreur PUT : rollback au pays précédent',
      setUp: () {
        when(() => mockRepo.updatePrefs(any())).thenThrow(Exception('server'));
      },
      build: build,
      seed: () => const BusinessPrefsState(country: 'FR'),
      act: (bloc) => bloc.add(const CountryChanged('CA')),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.isSyncing, 'isSyncing', true)
            .having((s) => s.country, 'country', 'CA'),
        isA<BusinessPrefsState>()
            .having((s) => s.country, 'country', 'FR')
            .having((s) => s.errorMessage, 'error', isNotNull),
      ],
      verify: (_) {
        verifyNever(() => mockRepo.fetchPrefs());
      },
    );
  });

  group(
    'events existants — WeightUnitChanged, CurrencyChanged, PickupRadiusChanged',
    () {
      blocTest<BusinessPrefsBloc, BusinessPrefsState>(
        'WeightUnitChanged écrit Hive + PUT',
        build: build,
        act: (bloc) => bloc.add(const WeightUnitChanged('lbs')),
        expect: () => [
          isA<BusinessPrefsState>().having((s) => s.weightUnit, 'unit', 'lbs'),
          syncStarted,
          syncSettled,
        ],
        verify: (_) {
          verify(() => mockBox.put(HiveService.kWeightUnit, 'lbs')).called(1);
          verify(() => mockRepo.updatePrefs(any())).called(1);
        },
      );

      blocTest<BusinessPrefsBloc, BusinessPrefsState>(
        'CurrencyChanged écrit Hive + PUT',
        build: build,
        act: (bloc) => bloc.add(const CurrencyChanged('XOF')),
        expect: () => [
          isA<BusinessPrefsState>().having(
            (s) => s.currencyCode,
            'code',
            'XOF',
          ),
          syncStarted,
          syncSettled,
        ],
      );

      blocTest<BusinessPrefsBloc, BusinessPrefsState>(
        'PickupRadiusChanged écrit Hive + PUT',
        build: build,
        act: (bloc) => bloc.add(const PickupRadiusChanged(25)),
        expect: () => [
          isA<BusinessPrefsState>().having((s) => s.pickupRadiusKm, 'km', 25),
          syncStarted,
          syncSettled,
        ],
      );
    },
  );
}
