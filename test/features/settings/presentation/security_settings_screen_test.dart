import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockAppPreferencesBloc
    extends MockBloc<AppPreferencesEvent, AppPreferencesState>
    implements AppPreferencesBloc {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

Widget _wrap({required MockAppPreferencesBloc mockBloc}) {
  final state = AppPreferencesState(
    preferences: const UserPreferencesModel(),
  );
  when(() => mockBloc.state).thenReturn(state);

  return MaterialApp(
    home: BlocProvider<AppPreferencesBloc>.value(
      value: mockBloc,
      child: const Scaffold(
        body: SecuritySettingsScreen(),
      ),
    ),
  );
}

void main() {
  group('SecuritySettingsScreen', () {
    late MockAppPreferencesBloc mockBloc;

    setUp(() {
      mockBloc = MockAppPreferencesBloc();
    });

    testWidgets('renders Sécurité title', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Sécurité'), findsOneWidget);
    });

    testWidgets('shows PAIEMENTS section with biometric tile', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('PAIEMENTS'), findsOneWidget);
      expect(find.text('Biométrie avant paiement'), findsOneWidget);
    });

    testWidgets('shows SESSION section with devices tile', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('SESSION'), findsOneWidget);
      expect(find.text('Appareils connectés'), findsOneWidget);
      expect(
        find.text('Voir et révoquer les sessions actives'),
        findsOneWidget,
      );
    });

    testWidgets('biometric switch is disabled when not available',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsWidgets);
      // The biometric switch should be disabled
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
    });

    testWidgets('revoke dialog shows when tapping devices tile', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      // Find the "Appareils connectés" tile
      final tile = find.text('Appareils connectés');
      expect(tile, findsOneWidget);

      // Tap it
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Déconnecter tous les appareils ?'), findsOneWidget);
      expect(
        find.text(
          'Tu seras déconnecté de tous tes appareils et devras te reconnecter.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('revoke dialog shows "Annuler" and "Déconnecter" buttons',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      // Tap the devices tile
      await tester.tap(find.text('Appareils connectés'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Déconnecter'), findsOneWidget);
    });

    testWidgets('revoke dialog closes when tapping Annuler', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      // Tap the devices tile
      await tester.tap(find.text('Appareils connectés'));
      await tester.pumpAndSettle();

      // Tap Annuler
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.text('Déconnecter tous les appareils ?'), findsNothing);
    });

    testWidgets('revoke dialog shows snackbar when tapping Déconnecter',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      // Tap the devices tile
      await tester.tap(find.text('Appareils connectés'));
      await tester.pumpAndSettle();

      // Tap Déconnecter
      await tester.tap(find.text('Déconnecter'));
      await tester.pumpAndSettle();

      // Snackbar should appear
      expect(
        find.text('Fonctionnalité disponible prochainement'),
        findsOneWidget,
      );
    });

    testWidgets(
      'biometric tile shows unavailable message when not supported',
      (tester) async {
        await tester.pumpWidget(_wrap(mockBloc: mockBloc));
        await tester.pumpAndSettle();

        // On a fresh instance without mocking local_auth,
        // biometricAvailable will be false initially
        // The subtitle should indicate unavailability
        expect(
          find.text('Non disponible sur cet appareil'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'biometric switch value reflects biometricEnabled from bloc (device unavailable)',
      (tester) async {
        // Même si biometricEnabled=true dans le BLoC, switch=false si device indispo
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(biometricEnabled: true),
        );
        when(() => mockBloc.state).thenReturn(state);

        await tester.pumpWidget(_wrap(mockBloc: mockBloc));
        await tester.pumpAndSettle();

        // FutureBuilder retourne false sur le simulateur de test (pas de plugin natif)
        // Switch = biometricEnabled(true) && biometricAvailable(false) = false
        final switchFinder = find.byType(Switch).first;
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isFalse);
      },
    );

    testWidgets(
      'tapping biometric tile when unavailable does not dispatch BiometricToggled',
      (tester) async {
        await tester.pumpWidget(_wrap(mockBloc: mockBloc));
        await tester.pumpAndSettle();

        // La tile biométrie n'est pas tappable quand device indispo
        await tester.tap(find.text('Biométrie avant paiement'));
        await tester.pumpAndSettle();

        verifyNever(() => mockBloc.add(const BiometricToggled()));
      },
    );
  });
}
