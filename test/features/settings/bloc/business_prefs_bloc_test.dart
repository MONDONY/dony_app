import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    when(() => mockBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('BusinessPrefsBloc', () {
    test('état initial utilise les defaults', () {
      final bloc = BusinessPrefsBloc(mockBox);
      expect(bloc.state.weightUnit, 'kg');
      expect(bloc.state.currencyCode, 'EUR');
      expect(bloc.state.pickupRadiusKm, 10);
      bloc.close();
    });

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'WeightUnitChanged met à jour le weightUnit et écrit dans Hive',
      build: () => BusinessPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const WeightUnitChanged('lbs')),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.weightUnit, 'weightUnit', 'lbs'),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kWeightUnit, 'lbs')).called(1),
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'CurrencyChanged met à jour la devise et écrit dans Hive',
      build: () => BusinessPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const CurrencyChanged('XOF')),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.currencyCode, 'currencyCode', 'XOF'),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kCurrencyCode, 'XOF')).called(1),
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'CurrencyChanged accepte XAF',
      build: () => BusinessPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const CurrencyChanged('XAF')),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.currencyCode, 'currencyCode', 'XAF'),
      ],
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'PickupRadiusChanged met à jour le rayon et écrit dans Hive',
      build: () => BusinessPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const PickupRadiusChanged(25)),
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.pickupRadiusKm, 'pickupRadiusKm', 25),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kPickupRadiusKm, 25)).called(1),
    );

    blocTest<BusinessPrefsBloc, BusinessPrefsState>(
      'plusieurs événements successifs maintiennent un état cohérent',
      build: () => BusinessPrefsBloc(mockBox),
      act: (bloc) {
        bloc.add(const WeightUnitChanged('lbs'));
        bloc.add(const CurrencyChanged('XOF'));
        bloc.add(const PickupRadiusChanged(30));
      },
      expect: () => [
        isA<BusinessPrefsState>()
            .having((s) => s.weightUnit, 'weightUnit', 'lbs'),
        isA<BusinessPrefsState>()
            .having((s) => s.currencyCode, 'currencyCode', 'XOF'),
        isA<BusinessPrefsState>()
            .having((s) => s.pickupRadiusKm, 'pickupRadiusKm', 30),
      ],
    );

    test('état initial lit les valeurs depuis Hive si présentes', () {
      when(() => mockBox.get(HiveService.kWeightUnit,
              defaultValue: any(named: 'defaultValue')))
          .thenReturn('lbs');
      when(() => mockBox.get(HiveService.kCurrencyCode,
              defaultValue: any(named: 'defaultValue')))
          .thenReturn('XOF');
      when(() => mockBox.get(HiveService.kPickupRadiusKm,
              defaultValue: any(named: 'defaultValue')))
          .thenReturn(20);

      final bloc = BusinessPrefsBloc(mockBox);
      expect(bloc.state.weightUnit, 'lbs');
      expect(bloc.state.currencyCode, 'XOF');
      expect(bloc.state.pickupRadiusKm, 20);
      bloc.close();
    });
  });
}
