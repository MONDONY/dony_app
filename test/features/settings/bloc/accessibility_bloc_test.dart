import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockBox box;
  late MockAnalyticsService analytics;

  setUp(() {
    box = MockBox();
    analytics = MockAnalyticsService();
    when(
      () => box.get(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => box.get(any())).thenReturn(null);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
    when(() => box.delete(any())).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  AccessibilityBloc build() => AccessibilityBloc(box, analytics);

  group('AccessibilityBloc — valeurs par défaut', () {
    test('un box vierge donne les valeurs par défaut', () {
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isTrue);
      expect(bloc.state.textScaleFactor, 1.0);
      expect(bloc.state.highContrast, AccessibilityMode.system);
      expect(bloc.state.reduceMotion, AccessibilityMode.system);
      expect(bloc.state.boldText, isFalse);
      expect(bloc.state.underlineLinks, isFalse);
      expect(bloc.state.reinforceLabels, isFalse);
      expect(bloc.state.persistentMessages, isFalse);
      expect(bloc.state.confirmImportantActions, isFalse);
      bloc.close();
    });
  });

  group('AccessibilityBloc — migration depuis l\'ancien format', () {
    void legacy({String? textScale, bool? highContrast, bool? reduce}) {
      when(() => box.get(HiveService.kTextScale)).thenReturn(textScale);
      when(() => box.get(HiveService.kHighContrast)).thenReturn(highContrast);
      when(() => box.get(HiveService.kReduceAnimations)).thenReturn(reduce);
    }

    test('small devient 0.85 sans suivi système', () {
      legacy(textScale: 'small');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isFalse);
      expect(bloc.state.textScaleFactor, 0.85);
      bloc.close();
    });

    test('normal devient suivi système à 1.0', () {
      legacy(textScale: 'normal');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isTrue);
      expect(bloc.state.textScaleFactor, 1.0);
      bloc.close();
    });

    test('large devient 1.3 sans suivi système', () {
      legacy(textScale: 'large');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isFalse);
      expect(bloc.state.textScaleFactor, 1.3);
      bloc.close();
    });

    test('xlarge devient 1.6 sans suivi système', () {
      legacy(textScale: 'xlarge');
      final bloc = build();
      expect(bloc.state.followSystemTextScale, isFalse);
      expect(bloc.state.textScaleFactor, 1.6);
      bloc.close();
    });

    test('high_contrast true devient on, false devient system', () {
      legacy(highContrast: true);
      final a = build();
      expect(a.state.highContrast, AccessibilityMode.on);
      a.close();

      legacy(highContrast: false);
      final b = build();
      expect(b.state.highContrast, AccessibilityMode.system);
      b.close();
    });

    test('reduce_animations true devient on, false devient system', () {
      legacy(reduce: true);
      final a = build();
      expect(a.state.reduceMotion, AccessibilityMode.on);
      a.close();

      legacy(reduce: false);
      final b = build();
      expect(b.state.reduceMotion, AccessibilityMode.system);
      b.close();
    });

    test('les anciennes clés sont supprimées après migration', () {
      legacy(textScale: 'large', highContrast: true, reduce: true);
      final bloc = build();
      verify(() => box.delete(HiveService.kTextScale)).called(1);
      verify(() => box.delete(HiveService.kHighContrast)).called(1);
      verify(() => box.delete(HiveService.kReduceAnimations)).called(1);
      bloc.close();
    });

    test('les nouvelles clés sont écrites après migration', () {
      legacy(textScale: 'large');
      final bloc = build();
      verify(
        () => box.put(HiveService.kA11yFollowSystemTextScale, false),
      ).called(1);
      verify(() => box.put(HiveService.kA11yTextScaleFactor, 1.3)).called(1);
      bloc.close();
    });

    test('aucune migration si aucune ancienne clé', () {
      final bloc = build();
      verifyNever(() => box.delete(HiveService.kTextScale));
      bloc.close();
    });
  });

  group('AccessibilityBloc — réglages', () {
    blocTest<AccessibilityBloc, AccessibilityState>(
      'TextScaleFactorChanged persiste et émet',
      build: build,
      act: (b) => b.add(const TextScaleFactorChanged(1.45)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.textScaleFactor,
          'textScaleFactor',
          1.45,
        ),
      ],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yTextScaleFactor, 1.45)).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'TextScaleFactorChanged borne la valeur entre 0.85 et 2.0',
      build: build,
      act: (b) => b
        ..add(const TextScaleFactorChanged(5.0))
        ..add(const TextScaleFactorChanged(0.1)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.textScaleFactor,
          'max borné',
          2.0,
        ),
        isA<AccessibilityState>().having(
          (s) => s.textScaleFactor,
          'min borné',
          0.85,
        ),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'FollowSystemTextScaleToggled persiste et émet',
      build: build,
      act: (b) => b.add(const FollowSystemTextScaleToggled(false)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.followSystemTextScale,
          'followSystemTextScale',
          isFalse,
        ),
      ],
      verify: (_) {
        verify(
          () => box.put(HiveService.kA11yFollowSystemTextScale, false),
        ).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'HighContrastModeChanged accepte on',
      build: build,
      act: (b) => b.add(const HighContrastModeChanged(AccessibilityMode.on)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.highContrast,
          'highContrast',
          AccessibilityMode.on,
        ),
      ],
      verify: (_) {
        verify(
          () => box.put(HiveService.kA11yHighContrast, AccessibilityMode.on),
        ).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'ReduceMotionModeChanged accepte off',
      build: build,
      act: (b) => b.add(const ReduceMotionModeChanged(AccessibilityMode.off)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.reduceMotion,
          'reduceMotion',
          AccessibilityMode.off,
        ),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'BoldTextToggled persiste et émet',
      build: build,
      act: (b) => b.add(const BoldTextToggled(true)),
      expect: () => [
        isA<AccessibilityState>().having((s) => s.boldText, 'boldText', isTrue),
      ],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yBoldText, true)).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'UnderlineLinksToggled persiste et émet',
      build: build,
      act: (b) => b.add(const UnderlineLinksToggled(true)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.underlineLinks,
          'underlineLinks',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yUnderlineLinks, true)).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'ReinforceLabelsToggled persiste et émet',
      build: build,
      act: (b) => b.add(const ReinforceLabelsToggled(true)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.reinforceLabels,
          'reinforceLabels',
          isTrue,
        ),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'PersistentMessagesToggled persiste et émet',
      build: build,
      act: (b) => b.add(const PersistentMessagesToggled(true)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.persistentMessages,
          'persistentMessages',
          isTrue,
        ),
      ],
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'ConfirmImportantActionsToggled persiste et émet',
      build: build,
      act: (b) => b.add(const ConfirmImportantActionsToggled(true)),
      expect: () => [
        isA<AccessibilityState>().having(
          (s) => s.confirmImportantActions,
          'confirmImportantActions',
          isTrue,
        ),
      ],
    );
  });

  group('AccessibilityBloc — réinitialisation', () {
    blocTest<AccessibilityBloc, AccessibilityState>(
      'AccessibilityResetRequested remet toutes les valeurs par défaut',
      build: build,
      seed: () => const AccessibilityState(
        followSystemTextScale: false,
        textScaleFactor: 1.8,
        highContrast: AccessibilityMode.on,
        reduceMotion: AccessibilityMode.on,
        boldText: true,
        underlineLinks: true,
        reinforceLabels: true,
        persistentMessages: true,
        confirmImportantActions: true,
      ),
      act: (b) => b.add(const AccessibilityResetRequested()),
      expect: () => [const AccessibilityState()],
      verify: (_) {
        verify(() => box.put(HiveService.kA11yTextScaleFactor, 1.0)).called(1);
        verify(() => box.put(HiveService.kA11yBoldText, false)).called(1);
      },
    );
  });

  group('AccessibilityBloc — analytics', () {
    blocTest<AccessibilityBloc, AccessibilityState>(
      'chaque changement émet accessibility_setting_changed sans PII',
      build: build,
      act: (b) => b.add(const BoldTextToggled(true)),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            'accessibility_setting_changed',
            properties: {'setting': 'bold_text', 'value': 'true'},
          ),
        ).called(1);
      },
    );

    blocTest<AccessibilityBloc, AccessibilityState>(
      'la réinitialisation émet un event dédié',
      build: build,
      act: (b) => b.add(const AccessibilityResetRequested()),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            'accessibility_setting_changed',
            properties: {'setting': 'reset', 'value': 'all'},
          ),
        ).called(1);
      },
    );
  });
}
