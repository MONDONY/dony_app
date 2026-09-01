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

/// Lot 8 multidevise : devise d'affichage (presentment). `'AUTO'` = suivre la
/// devise active ; une devise concrète fige les équivalents convertis servis
/// par le backend. Jamais verrouillée par le solde, contrairement à la devise
/// de paiement.
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
    when(
      () => mockRepo.updatePrefs(any()),
    ).thenAnswer((_) async => _defaultDto);
  });

  BusinessPrefsBloc build() => BusinessPrefsBloc(mockRepo, mockBox);

  group('état initial', () {
    test('sans valeur Hive, la devise d\'affichage est AUTO', () {
      final bloc = build();
      expect(bloc.state.displayCurrencyCode, 'AUTO');
      bloc.close();
    });

    test('une devise choisie persistée dans Hive est relue au démarrage', () {
      when(
        () => mockBox.get(
          HiveService.kDisplayCurrencyCode,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn('USD');
      final bloc = build();
      expect(bloc.state.displayCurrencyCode, 'USD');
      bloc.close();
    });
  });

  group('DisplayCurrencyChanged', () {
    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'écrit Hive, émet la valeur optimiste puis synchronise au serveur',
      build: build,
      act: (bloc) => bloc.add(const DisplayCurrencyChanged('XOF')),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.displayCurrencyCode, 'displayCurrencyCode', 'XOF')
            .having((s) => s.isSyncing, 'isSyncing', false),
        isA<BusinessPrefsState>().having((s) => s.isSyncing, 'isSyncing', true),
        isA<BusinessPrefsState>()
            .having((s) => s.displayCurrencyCode, 'displayCurrencyCode', 'XOF')
            .having((s) => s.isSyncing, 'isSyncing', false),
      ],
      verify: (_) {
        verify(
          () => mockBox.put(HiveService.kDisplayCurrencyCode, 'XOF'),
        ).called(1);
        final sent =
            verify(() => mockRepo.updatePrefs(captureAny())).captured.single
                as UserBusinessPrefsDto;
        expect(sent.displayCurrencyCode, 'XOF');
      },
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'AUTO repart au serveur comme valeur à part entière (efface le choix)',
      build: build,
      seed: () => const BusinessPrefsState(displayCurrencyCode: 'USD'),
      act: (bloc) => bloc.add(const DisplayCurrencyChanged('AUTO')),
      verify: (_) {
        final sent =
            verify(() => mockRepo.updatePrefs(captureAny())).captured.single
                as UserBusinessPrefsDto;
        expect(sent.displayCurrencyCode, 'AUTO');
      },
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'échec réseau : rollback sur la valeur précédente avec message d\'erreur',
      build: () {
        when(
          () => mockRepo.updatePrefs(any()),
        ).thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) => bloc.add(const DisplayCurrencyChanged('CAD')),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.displayCurrencyCode, 'displayCurrencyCode', 'CAD'),
        isA<BusinessPrefsState>().having((s) => s.isSyncing, 'isSyncing', true),
        isA<BusinessPrefsState>()
            .having((s) => s.displayCurrencyCode, 'displayCurrencyCode', 'AUTO')
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
      verify: (_) {
        // Le rollback réécrit aussi Hive avec l'état précédent (AUTO).
        verify(
          () => mockBox.put(HiveService.kDisplayCurrencyCode, 'AUTO'),
        ).called(1);
      },
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'la synchro serveur adopte la devise d\'affichage renvoyée par le GET',
      build: () {
        when(() => mockRepo.fetchPrefs()).thenAnswer(
          (_) async => _defaultDto.copyWith(displayCurrencyCode: 'GBP'),
        );
        return build();
      },
      act: (bloc) => bloc.add(const BusinessPrefsSyncRequested()),
      verify: (bloc) {
        expect(bloc.state.displayCurrencyCode, 'GBP');
        verify(
          () => mockBox.put(HiveService.kDisplayCurrencyCode, 'GBP'),
        ).called(1);
      },
    );
  });

  group('UserBusinessPrefsDto — displayCurrencyCode', () {
    test('fromJson : champ absent (vieux backend) → AUTO', () {
      final dto = UserBusinessPrefsDto.fromJson(const {
        'weightUnit': 'kg',
        'currencyCode': 'EUR',
        'pickupRadiusKm': 10,
        'defaultPackageWeightKg': 23,
        'minBidPriceEur': 0,
      });
      expect(dto.displayCurrencyCode, 'AUTO');
    });

    test('fromJson : champ présent → valeur serveur', () {
      final dto = UserBusinessPrefsDto.fromJson(const {
        'weightUnit': 'kg',
        'currencyCode': 'XOF',
        'pickupRadiusKm': 10,
        'defaultPackageWeightKg': 23,
        'minBidPriceEur': 0,
        'displayCurrencyCode': 'USD',
      });
      expect(dto.displayCurrencyCode, 'USD');
    });

    test('toJson : toujours envoyée, AUTO compris (valeur à part entière)', () {
      expect(_defaultDto.toJson()['displayCurrencyCode'], 'AUTO');
      expect(
        _defaultDto.copyWith(displayCurrencyCode: 'XAF').toJson()['displayCurrencyCode'],
        'XAF',
      );
    });

    test('copyWith préserve la devise d\'affichage par défaut', () {
      final copied = _defaultDto.copyWith(weightUnit: 'lbs');
      expect(copied.displayCurrencyCode, 'AUTO');
    });
  });
}
