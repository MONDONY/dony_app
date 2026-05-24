import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
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

  group('AccessibilityBloc', () {
    test('état initial utilise les defaults', () {
      final bloc = AccessibilityBloc(mockBox);
      expect(bloc.state.textScale, 'normal');
      expect(bloc.state.highContrast, isFalse);
      expect(bloc.state.reduceAnimations, isFalse);
      bloc.close();
    });

    blocTest<AccessibilityBloc, AccessibilityState>(
      'HighContrastToggled active le contraste et écrit dans Hive',
      build: () => AccessibilityBloc(mockBox),
      act: (bloc) => bloc.add(const HighContrastToggled()),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.highContrast, 'highContrast', isTrue),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kHighContrast, true)).called(1),
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'HighContrastToggled désactive le contraste si déjà actif',
      build: () {
        when(() => mockBox.get(HiveService.kHighContrast,
                defaultValue: any(named: 'defaultValue')))
            .thenReturn(true);
        return AccessibilityBloc(mockBox);
      },
      act: (bloc) => bloc.add(const HighContrastToggled()),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.highContrast, 'highContrast', isFalse),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kHighContrast, false)).called(1),
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'ReduceAnimationsToggled active la réduction des animations',
      build: () => AccessibilityBloc(mockBox),
      act: (bloc) => bloc.add(const ReduceAnimationsToggled()),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.reduceAnimations, 'reduceAnimations', isTrue),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kReduceAnimations, true))
              .called(1),
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'TextScaleChanged met à jour la taille du texte',
      build: () => AccessibilityBloc(mockBox),
      act: (bloc) => bloc.add(const TextScaleChanged('large')),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.textScale, 'textScale', 'large'),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kTextScale, 'large')).called(1),
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'TextScaleChanged accepte toutes les valeurs valides',
      build: () => AccessibilityBloc(mockBox),
      act: (bloc) => bloc.add(const TextScaleChanged('xlarge')),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.textScale, 'textScale', 'xlarge'),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'TextScaleChanged accepte small',
      build: () => AccessibilityBloc(mockBox),
      act: (bloc) => bloc.add(const TextScaleChanged('small')),
      expect: () => [
        isA<AccessibilityState>()
            .having((s) => s.textScale, 'textScale', 'small'),
      ],
    );

    test('état initial lit les valeurs depuis Hive si présentes', () {
      when(() => mockBox.get(HiveService.kTextScale,
              defaultValue: any(named: 'defaultValue')))
          .thenReturn('large');
      when(() => mockBox.get(HiveService.kHighContrast,
              defaultValue: any(named: 'defaultValue')))
          .thenReturn(true);
      when(() => mockBox.get(HiveService.kReduceAnimations,
              defaultValue: any(named: 'defaultValue')))
          .thenReturn(true);

      final bloc = AccessibilityBloc(mockBox);
      expect(bloc.state.textScale, 'large');
      expect(bloc.state.highContrast, isTrue);
      expect(bloc.state.reduceAnimations, isTrue);
      bloc.close();
    });
  });
}
