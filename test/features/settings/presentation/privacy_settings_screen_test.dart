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
  final effectiveState =
      state ?? const PrivacySettingsLoaded(contactKycOnly: false);
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

    testWidgets('affiche le bandeau de protection du numéro', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Ton numéro est protégé'), findsOneWidget);
    });

    testWidgets('affiche la section QUI PEUT ME CONTACTER', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('QUI PEUT ME CONTACTER'), findsOneWidget);
    });

    testWidgets('affiche la tuile "Profils vérifiés uniquement"',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Profils vérifiés uniquement'), findsOneWidget);
    });

    testWidgets('affiche la section BLOCAGE', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('BLOCAGE'), findsOneWidget);
    });

    testWidgets('affiche la tuile "Utilisateurs bloqués"', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Utilisateurs bloqués'), findsOneWidget);
    });

    testWidgets('Switch est off quand contactKycOnly == false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(contactKycOnly: false),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final sw = tester.widget<Switch>(switchFinder);
      expect(sw.value, isFalse);
    });

    testWidgets('Switch est on quand contactKycOnly == true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(contactKycOnly: true),
        ),
      );
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('Switch désactivé pendant PrivacySettingsLoading',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoading(),
        ),
      );
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.onChanged, isNull);
    });

    testWidgets(
        'tapper le Switch envoie ContactKycOnlyToggled(true) quand valeur false',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(contactKycOnly: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const ContactKycOnlyToggled(true))).called(1);
    });
  });
}
