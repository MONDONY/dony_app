import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    // Par défaut, retourne la valeur defaultValue pour toute clé
    when(() => mockBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('AppPreferencesBloc', () {
    test('état initial lit depuis Hive', () {
      final bloc = AppPreferencesBloc(mockBox);
      expect(bloc.state.preferences.themeMode, equals('system'));
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

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'DestinationToggled ajoute SN si absent',
      build: () => AppPreferencesBloc(mockBox),
      act: (bloc) => bloc.add(const DestinationToggled('SN')),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.favDestinations,
          'destinations',
          contains('SN'),
        ),
      ],
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'DestinationToggled retire SN si déjà présent',
      build: () {
        when(() => mockBox.get(
              HiveService.kFavDestinations,
              defaultValue: any(named: 'defaultValue'),
            )).thenReturn(['SN', 'CI']);
        return AppPreferencesBloc(mockBox);
      },
      act: (bloc) => bloc.add(const DestinationToggled('SN')),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.favDestinations,
          'destinations',
          isNot(contains('SN')),
        ),
      ],
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
      'SmsAlertsToggled active les alertes SMS quand elles sont désactivées',
      build: () => AppPreferencesBloc(mockBox),
      act: (bloc) => bloc.add(const SmsAlertsToggled()),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.smsAlertsEnabled,
          'smsAlertsEnabled',
          isTrue,
        ),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kSmsAlertsEnabled, true))
              .called(1),
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'SmsAlertsToggled désactive les alertes SMS quand elles sont activées',
      build: () {
        when(() => mockBox.get(
              HiveService.kSmsAlertsEnabled,
              defaultValue: any(named: 'defaultValue'),
            )).thenReturn(true);
        return AppPreferencesBloc(mockBox);
      },
      act: (bloc) => bloc.add(const SmsAlertsToggled()),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.smsAlertsEnabled,
          'smsAlertsEnabled',
          isFalse,
        ),
      ],
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
      'DestinationToggled ajoute CI si absent',
      build: () => AppPreferencesBloc(mockBox),
      act: (bloc) => bloc.add(const DestinationToggled('CI')),
      expect: () => [
        isA<AppPreferencesState>().having(
          (s) => s.preferences.favDestinations,
          'destinations',
          contains('CI'),
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
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kBiometricEnabled, true)).called(1),
    );

    blocTest<AppPreferencesBloc, AppPreferencesState>(
      'BiometricToggled désactive biometricEnabled quand activé',
      build: () {
        when(() => mockBox.get(
              HiveService.kBiometricEnabled,
              defaultValue: any(named: 'defaultValue'),
            )).thenReturn(true);
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

      const smsEvent = SmsAlertsToggled();
      expect(smsEvent.props, equals([]));

      const destEvent = DestinationToggled('SN');
      expect(destEvent.props, equals(['SN']));

      const bioEvent = BiometricToggled();
      expect(bioEvent.props, equals([]));
    });
  });
}
