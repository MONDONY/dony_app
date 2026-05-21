import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    // Par défaut, retourne la defaultValue pour toute clé
    when(() => mockBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('PrivacySettingsBloc', () {
    test('état initial lit les valeurs par défaut depuis Hive', () {
      final bloc = PrivacySettingsBloc(mockBox);

      expect(bloc.state.profileVisibility, equals('public'));
      expect(bloc.state.hidePhoneNumber, isFalse);

      bloc.close();
    });

    test('état initial lit la visibilité persistée depuis Hive', () {
      when(
        () => mockBox.get(
          HiveService.kProfileVisibility,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn('limited');

      final bloc = PrivacySettingsBloc(mockBox);

      expect(bloc.state.profileVisibility, equals('limited'));

      bloc.close();
    });

    test('état initial lit le masquage téléphone persisté depuis Hive', () {
      when(
        () => mockBox.get(
          HiveService.kHidePhoneNumber,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);

      final bloc = PrivacySettingsBloc(mockBox);

      expect(bloc.state.hidePhoneNumber, isTrue);

      bloc.close();
    });

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'ProfileVisibilityChanged passe à limited et écrit dans Hive',
      build: () => PrivacySettingsBloc(mockBox),
      act: (bloc) =>
          bloc.add(const ProfileVisibilityChanged('limited')),
      expect: () => [
        isA<PrivacySettingsState>()
            .having((s) => s.profileVisibility, 'profileVisibility', 'limited')
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', false),
      ],
      verify: (_) => verify(
        () => mockBox.put(HiveService.kProfileVisibility, 'limited'),
      ).called(1),
    );

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'ProfileVisibilityChanged repasse à public et écrit dans Hive',
      build: () {
        when(
          () => mockBox.get(
            HiveService.kProfileVisibility,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn('limited');
        return PrivacySettingsBloc(mockBox);
      },
      act: (bloc) => bloc.add(const ProfileVisibilityChanged('public')),
      expect: () => [
        isA<PrivacySettingsState>().having(
          (s) => s.profileVisibility,
          'profileVisibility',
          'public',
        ),
      ],
      verify: (_) => verify(
        () => mockBox.put(HiveService.kProfileVisibility, 'public'),
      ).called(1),
    );

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'HidePhoneToggled active le masquage et écrit dans Hive',
      build: () => PrivacySettingsBloc(mockBox),
      act: (bloc) => bloc.add(const HidePhoneToggled()),
      expect: () => [
        isA<PrivacySettingsState>().having(
          (s) => s.hidePhoneNumber,
          'hidePhoneNumber',
          true,
        ),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kHidePhoneNumber, true))
              .called(1),
    );

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'HidePhoneToggled désactive le masquage si déjà actif et écrit dans Hive',
      build: () {
        when(
          () => mockBox.get(
            HiveService.kHidePhoneNumber,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(true);
        return PrivacySettingsBloc(mockBox);
      },
      act: (bloc) => bloc.add(const HidePhoneToggled()),
      expect: () => [
        isA<PrivacySettingsState>().having(
          (s) => s.hidePhoneNumber,
          'hidePhoneNumber',
          false,
        ),
      ],
      verify: (_) =>
          verify(() => mockBox.put(HiveService.kHidePhoneNumber, false))
              .called(1),
    );

    blocTest<PrivacySettingsBloc, PrivacySettingsState>(
      'Deux toggles successifs restituent la valeur initiale',
      build: () => PrivacySettingsBloc(mockBox),
      act: (bloc) => bloc
        ..add(const HidePhoneToggled())
        ..add(const HidePhoneToggled()),
      expect: () => [
        isA<PrivacySettingsState>()
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', true),
        isA<PrivacySettingsState>()
            .having((s) => s.hidePhoneNumber, 'hidePhoneNumber', false),
      ],
    );

    test('PrivacySettingsState copyWith préserve les champs non modifiés', () {
      const state = PrivacySettingsState(
        profileVisibility: 'limited',
        hidePhoneNumber: true,
      );

      final updated = state.copyWith(profileVisibility: 'public');

      expect(updated.profileVisibility, equals('public'));
      expect(updated.hidePhoneNumber, isTrue); // inchangé
    });

    test('PrivacySettingsState props sont corrects', () {
      const a = PrivacySettingsState(
        profileVisibility: 'public',
        hidePhoneNumber: false,
      );
      const b = PrivacySettingsState(
        profileVisibility: 'public',
        hidePhoneNumber: false,
      );
      const c = PrivacySettingsState(
        profileVisibility: 'limited',
        hidePhoneNumber: false,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
