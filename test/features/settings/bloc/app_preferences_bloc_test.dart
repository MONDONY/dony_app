import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    // Par défaut, retourne la valeur defaultValue pour toute clé
    when(
      () => mockBox.get(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('AppPreferencesBloc', () {
    test('état initial lit depuis Hive', () {
      final bloc = AppPreferencesBloc(mockBox);
      expect(bloc.state.preferences.themeMode, equals('light'));
      expect(bloc.state.preferences.languageCode, equals('system'));
      bloc.close();
    });

    test('valeur Hive inconnue → system', () {
      when(
        () => mockBox.get(
          HiveService.kLanguageCode,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn('de');
      final bloc = AppPreferencesBloc(mockBox);
      expect(bloc.state.preferences.languageCode, equals('system'));
      bloc.close();
    });

    test('choix fr déjà stocké → conservé', () {
      when(
        () => mockBox.get(
          HiveService.kLanguageCode,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn('fr');
      final bloc = AppPreferencesBloc(mockBox);
      expect(bloc.state.preferences.languageCode, equals('fr'));
      bloc.close();
    });

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'ThemeChanged met à jour le thème et écrit dans Hive',
      build: () => AppPreferencesBloc(mockBox),
      act: (bloc) => bloc.add(const ThemeChanged('dark')),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.themeMode,
          'themeMode',
          'dark',
        ),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kThemeMode, 'dark')).called(1),
    );

    test(
      'FLUTTER-H5 : une ancienne clé fav_destinations stockée ne gêne pas la '
      'lecture, et n\'est plus jamais réécrite',
      () async {
        when(
          () => mockBox.get(
            'fav_destinations',
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(<String>['SN', 'CI']);
        when(
          () => mockBox.get(
            HiveService.kThemeMode,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn('dark');
        final bloc = AppPreferencesBloc(mockBox);
        expect(bloc.state.preferences.themeMode, 'dark');
        bloc.add(const ThemeChanged('light'));
        await expectLater(
          bloc.stream,
          emits(
            isA<AppPreferencesState>().having(
              (s) => s.preferences.themeMode,
              'themeMode',
              'light',
            ),
          ),
        );
        verifyNever(() => mockBox.put('fav_destinations', any()));
        verifyNever(
          () => mockBox.get(
            'fav_destinations',
            defaultValue: any(named: 'defaultValue'),
          ),
        );
        await bloc.close();
      },
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'LanguageChanged met à jour la langue et écrit dans Hive',
      build: () => AppPreferencesBloc(mockBox),
      act: (bloc) => bloc.add(const LanguageChanged('en')),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.languageCode,
          'languageCode',
          'en',
        ),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kLanguageCode, 'en')).called(1),
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'LanguageChanged(system) revient à la langue du téléphone',
      build: () => AppPreferencesBloc(mockBox),
      seed: () => const AppPreferencesState(
        preferences: UserPreferencesModel(languageCode: 'en'),
      ),
      act: (bloc) => bloc.add(const LanguageChanged('system')),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.languageCode,
          'languageCode',
          'system',
        ),
      ],
      verify: (_) => verify(
        () => mockBox.put(HiveService.kLanguageCode, 'system'),
      ).called(1),
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'ThemeChanged vers light met à jour le thème',
      build: () => AppPreferencesBloc(mockBox),
      act: (bloc) => bloc.add(const ThemeChanged('light')),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.themeMode,
          'themeMode',
          'light',
        ),
      ],
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'BiometricToggled active biometricEnabled quand désactivé',
      build: () => AppPreferencesBloc(mockBox),
      act: (bloc) => bloc.add(const BiometricToggled()),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.biometricEnabled,
          'biometricEnabled',
          isTrue,
        ),
      ],
      verify: (_) => verify(
        () => mockBox.put(HiveService.kBiometricEnabled, true),
      ).called(1),
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'BiometricToggled désactive biometricEnabled quand activé',
      build: () {
        when(
          () => mockBox.get(
            HiveService.kBiometricEnabled,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(true);
        return AppPreferencesBloc(mockBox);
      },
      act: (bloc) => bloc.add(const BiometricToggled()),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.biometricEnabled,
          'biometricEnabled',
          isFalse,
        ),
      ],
    );

    test('AppPreferencesEvent props sont corrects', () {
      const themeEvent = ThemeChanged('dark');
      expect(themeEvent.props, equals(['dark']));

      const langEvent = LanguageChanged('en');
      expect(langEvent.props, equals(['en']));

      const bioEvent = BiometricToggled();
      expect(bioEvent.props, equals([]));
    });

    group('AppLockBiometricToggled', () {
      blocTest<AppPreferencesBloc, AppPreferencesState>(
        'AppLockBiometricToggled bascule appLockBiometricEnabled de true à false',
        build: () {
          // appLockBiometricEnabled par défaut = true
          when(
            () => mockBox.get(
              HiveService.kAppLockBiometric,
              defaultValue: any(named: 'defaultValue'),
            ),
          ).thenReturn(true);
          return AppPreferencesBloc(mockBox);
        },
        act: (bloc) => bloc.add(const AppLockBiometricToggled()),
        expect: () => [
          isA<AppPreferencesState>().having(
            (s) => s.preferences.appLockBiometricEnabled,
            'appLockBiometricEnabled',
            isFalse,
          ),
        ],
        verify: (_) => verify(
          () => mockBox.put(HiveService.kAppLockBiometric, false),
        ).called(1),
      );

      blocTest<AppPreferencesBloc, AppPreferencesState>(
        'AppLockBiometricToggled bascule appLockBiometricEnabled de false à true',
        build: () {
          when(
            () => mockBox.get(
              HiveService.kAppLockBiometric,
              defaultValue: any(named: 'defaultValue'),
            ),
          ).thenReturn(false);
          return AppPreferencesBloc(mockBox);
        },
        act: (bloc) => bloc.add(const AppLockBiometricToggled()),
        expect: () => [
          isA<AppPreferencesState>().having(
            (s) => s.preferences.appLockBiometricEnabled,
            'appLockBiometricEnabled',
            isTrue,
          ),
        ],
        verify: (_) => verify(
          () => mockBox.put(HiveService.kAppLockBiometric, true),
        ).called(1),
      );
    });

    group('bulle de l’assistant', () {
      test('valeurs par défaut de la bulle', () {
        final bloc = AppPreferencesBloc(mockBox);
        final prefs = bloc.state.preferences;
        expect(prefs.assistantBubbleEnabled, isTrue);
        expect(prefs.assistantBubbleSide, 'right');
        expect(prefs.assistantBubbleY, 0.65);
        expect(prefs.assistantHintSeen, isFalse);
        bloc.close();
      });

      blocTest<AppPreferencesBloc, AppPreferencesState>(
        'déplacer la bulle borne la hauteur et écrit dans Hive',
        build: () => AppPreferencesBloc(mockBox),
        act: (bloc) => bloc.add(const AssistantBubbleMoved('left', 1.4)),
        expect: () => [
          isA<AppPreferencesState>()
              .having((s) => s.preferences.assistantBubbleSide, 'side', 'left')
              .having((s) => s.preferences.assistantBubbleY, 'y', 1.0),
        ],
        verify: (_) {
          verify(
            () => mockBox.put(HiveService.kAssistantBubbleSide, 'left'),
          ).called(1);
          verify(
            () => mockBox.put(HiveService.kAssistantBubbleY, 1.0),
          ).called(1);
        },
      );

      blocTest<AppPreferencesBloc, AppPreferencesState>(
        'côté inconnu retombe à droite',
        build: () => AppPreferencesBloc(mockBox),
        act: (bloc) => bloc.add(const AssistantBubbleMoved('haut', 0.3)),
        expect: () => [
          isA<AppPreferencesState>().having(
            (s) => s.preferences.assistantBubbleSide,
            'side',
            'right',
          ),
        ],
      );

      blocTest<AppPreferencesBloc, AppPreferencesState>(
        'désactiver, réinitialiser, bulle d’aide vue',
        build: () => AppPreferencesBloc(mockBox),
        act: (bloc) => bloc
          ..add(const AssistantBubbleToggled(false))
          ..add(const AssistantBubbleMoved('left', 0.2))
          ..add(const AssistantBubbleReset())
          ..add(const AssistantHintDismissed()),
        expect: () => [
          isA<AppPreferencesState>().having(
            (s) => s.preferences.assistantBubbleEnabled,
            'off',
            false,
          ),
          isA<AppPreferencesState>().having(
            (s) => s.preferences.assistantBubbleSide,
            'left',
            'left',
          ),
          isA<AppPreferencesState>()
              .having(
                (s) => s.preferences.assistantBubbleSide,
                'reset',
                'right',
              )
              .having((s) => s.preferences.assistantBubbleY, 'y', 0.65),
          isA<AppPreferencesState>().having(
            (s) => s.preferences.assistantHintSeen,
            'hint',
            true,
          ),
        ],
      );

      blocTest<AppPreferencesBloc, AppPreferencesState>(
        'une hauteur NaN ne remplace pas la hauteur courante',
        build: () => AppPreferencesBloc(mockBox),
        seed: () => const AppPreferencesState(
          preferences: UserPreferencesModel(assistantBubbleY: 0.3),
        ),
        act: (bloc) => bloc.add(const AssistantBubbleMoved('left', double.nan)),
        expect: () => [
          isA<AppPreferencesState>()
              .having((s) => s.preferences.assistantBubbleSide, 'side', 'left')
              .having((s) => s.preferences.assistantBubbleY, 'y', 0.3),
        ],
      );

      test('les événements de bulle exposent leurs props', () {
        const moved = AssistantBubbleMoved('left', 0.2);
        expect(moved.props, equals(['left', 0.2]));
        const toggled = AssistantBubbleToggled(false);
        expect(toggled.props, equals([false]));
      });

      group('lecture Hive : jamais de plantage, valeurs bornées', () {
        void stubGet(String key, Object? value) => when(
          () => mockBox.get(key, defaultValue: any(named: 'defaultValue')),
        ).thenReturn(value);

        test('hauteur hors bornes ramenée entre 0 et 1', () {
          stubGet(HiveService.kAssistantBubbleY, 2.5);
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 1.0);
          stubGet(HiveService.kAssistantBubbleY, -3.0);
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 0.0);
          stubGet(HiveService.kAssistantBubbleY, double.infinity);
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 1.0);
        });

        test('hauteur NaN revient au défaut 0.65', () {
          stubGet(HiveService.kAssistantBubbleY, double.nan);
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 0.65);
        });

        test('hauteur d’un mauvais type revient au défaut sans lever', () {
          stubGet(HiveService.kAssistantBubbleY, 'haut');
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 0.65);
          stubGet(HiveService.kAssistantBubbleY, null);
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 0.65);
        });

        test('hauteur entière lue comme nombre puis bornée', () {
          stubGet(HiveService.kAssistantBubbleY, 1);
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 1.0);
          stubGet(HiveService.kAssistantBubbleY, 5);
          expect(UserPreferencesModel.fromHive(mockBox).assistantBubbleY, 1.0);
        });

        test('côté inconnu, absent ou non textuel retombe à droite', () {
          stubGet(HiveService.kAssistantBubbleSide, 'top');
          expect(
            UserPreferencesModel.fromHive(mockBox).assistantBubbleSide,
            'right',
          );
          stubGet(HiveService.kAssistantBubbleSide, 42);
          expect(
            UserPreferencesModel.fromHive(mockBox).assistantBubbleSide,
            'right',
          );
          stubGet(HiveService.kAssistantBubbleSide, 'left');
          expect(
            UserPreferencesModel.fromHive(mockBox).assistantBubbleSide,
            'left',
          );
        });

        test('booléens d’un mauvais type retombent au défaut', () {
          stubGet(HiveService.kAssistantBubbleEnabled, 'oui');
          expect(
            UserPreferencesModel.fromHive(mockBox).assistantBubbleEnabled,
            isTrue,
          );
          stubGet(HiveService.kAssistantHintSeen, 1);
          expect(
            UserPreferencesModel.fromHive(mockBox).assistantHintSeen,
            isFalse,
          );
        });
      });
    });
  });
}
