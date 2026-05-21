import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPrivacySettingsBloc
    extends MockBloc<PrivacySettingsEvent, PrivacySettingsState>
    implements PrivacySettingsBloc {}

Widget _wrap({
  required MockPrivacySettingsBloc mockBloc,
  PrivacySettingsState? state,
}) {
  final effectiveState = state ??
      const PrivacySettingsState(
        profileVisibility: 'public',
        hidePhoneNumber: false,
      );
  when(() => mockBloc.state).thenReturn(effectiveState);

  return MaterialApp(
    home: BlocProvider<PrivacySettingsBloc>.value(
      value: mockBloc,
      child: const PrivacySettingsScreen(),
    ),
  );
}

void main() {
  group('PrivacySettingsScreen', () {
    late MockPrivacySettingsBloc mockBloc;

    setUp(() {
      mockBloc = MockPrivacySettingsBloc();
    });

    testWidgets('affiche le titre "Confidentialité"', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Confidentialité'), findsOneWidget);
    });

    testWidgets('affiche la section VISIBILITÉ', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('VISIBILITÉ'), findsOneWidget);
    });

    testWidgets('affiche la tuile "Visibilité du profil"', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Visibilité du profil'), findsOneWidget);
    });

    testWidgets('affiche "Public" quand visibility == public', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsState(profileVisibility: 'public'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Public'), findsOneWidget);
      expect(
        find.text('Visible dans les résultats de matching'),
        findsOneWidget,
      );
    });

    testWidgets('affiche "Limité" quand visibility == limited', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsState(profileVisibility: 'limited'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Limité'), findsOneWidget);
      expect(
        find.text('Visible uniquement par tes partenaires actifs'),
        findsOneWidget,
      );
    });

    testWidgets('affiche la tuile "Masquer mon numéro"', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Masquer mon numéro'), findsOneWidget);
      expect(
        find.text('Les autres utilisateurs ne verront pas ton numéro'),
        findsOneWidget,
      );
    });

    testWidgets('Switch est off quand hidePhoneNumber == false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsState(hidePhoneNumber: false),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final sw = tester.widget<Switch>(switchFinder);
      expect(sw.value, isFalse);
    });

    testWidgets('Switch est on quand hidePhoneNumber == true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsState(hidePhoneNumber: true),
        ),
      );
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets(
        'tapper le Switch envoie HidePhoneToggled au BLoC', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const HidePhoneToggled())).called(1);
    });

    testWidgets(
        'tapper "Visibilité du profil" ouvre le bottom sheet picker',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Visibilité du profil'));
      await tester.pumpAndSettle();

      // Le bottom sheet doit afficher le titre
      expect(find.text('Visibilité du profil'), findsWidgets);
      // Les deux options doivent être présentes
      expect(find.text('Public'), findsWidgets);
      expect(find.text('Limité'), findsOneWidget);
    });

    testWidgets(
        'choisir "Limité" dans le picker envoie ProfileVisibilityChanged',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      // Ouvrir le picker
      await tester.tap(find.text('Visibilité du profil'));
      await tester.pumpAndSettle();

      // Sélectionner "Limité"
      final limitedFinder = find.text('Limité');
      expect(limitedFinder, findsOneWidget);
      await tester.tap(limitedFinder);
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(const ProfileVisibilityChanged('limited')),
      ).called(1);
    });

    testWidgets(
        'choisir "Public" dans le picker envoie ProfileVisibilityChanged',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsState(profileVisibility: 'limited'),
        ),
      );
      await tester.pumpAndSettle();

      // Ouvrir le picker
      await tester.tap(find.text('Visibilité du profil'));
      await tester.pumpAndSettle();

      // Les options sont dans le sheet — "Public" apparaît dans la liste
      final publicFinder = find.text('Public');
      expect(publicFinder, findsWidgets);
      await tester.tap(publicFinder.last);
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(const ProfileVisibilityChanged('public')),
      ).called(1);
    });

    testWidgets('icône check visible sur option sélectionnée dans le picker',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsState(profileVisibility: 'public'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Visibilité du profil'));
      await tester.pumpAndSettle();

      // L'icône check doit être visible (option public sélectionnée)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
