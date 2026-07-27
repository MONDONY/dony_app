import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/bloc/pin_status_cubit.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:dony/features/settings/presentation/widgets/pin_confirm_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockAppPreferencesBloc
    extends MockBloc<AppPreferencesEvent, AppPreferencesState>
    implements AppPreferencesBloc {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class MockLocalAuthService extends Mock implements LocalAuthService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the screen with [biometricAvailableOverride] and the provided bloc.
/// When [biometricAvailableOverride] is true a [MockLocalAuthService] is
/// registered in GetIt so that [PinConfirmBottomSheet] can resolve the service.
/// [pinConfigured] pilote l'état du verrouillage par code PIN, devenu
/// facultatif : les tests de garde PIN supposent un code existant, sinon la
/// confirmation n'a rien à vérifier et l'écran ne la demande plus.
Widget _wrap({
  required MockAppPreferencesBloc mockBloc,
  required AppPreferencesState state,
  bool biometricAvailable = false,
  MockLocalAuthService? authService,
  bool pinConfigured = true,
}) {
  when(() => mockBloc.state).thenReturn(state);

  final pinService = MockLocalAuthService();
  when(pinService.isPinSet).thenAnswer((_) async => pinConfigured);

  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AppPreferencesBloc>.value(value: mockBloc),
        BlocProvider<PinStatusCubit>(
          create: (_) => PinStatusCubit(pinService)..refresh(),
        ),
      ],
      child: SecuritySettingsScreen(
        biometricAvailableOverride: biometricAvailable,
      ),
    ),
  );
}

void main() {
  late MockAppPreferencesBloc mockBloc;
  late MockLocalAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(const BiometricToggled());
    registerFallbackValue(const AppLockBiometricToggled());
  });

  setUp(() {
    mockBloc = MockAppPreferencesBloc();
    mockAuthService = MockLocalAuthService();

    // Register mock LocalAuthService in GetIt for PinConfirmBottomSheet.
    if (GetIt.instance.isRegistered<LocalAuthService>()) {
      GetIt.instance.unregister<LocalAuthService>();
    }
    GetIt.instance.registerLazySingleton<LocalAuthService>(
      () => mockAuthService,
    );
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<LocalAuthService>()) {
      GetIt.instance.unregister<LocalAuthService>();
    }
  });

  // -------------------------------------------------------------------------
  // Existing regression tests (kept intact, biometricAvailable defaults false)
  // -------------------------------------------------------------------------

  group('SecuritySettingsScreen — UI', () {
    testWidgets('renders Sécurité title', (tester) async {
      final state = AppPreferencesState(
        preferences: const UserPreferencesModel(),
      );
      await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
      await tester.pumpAndSettle();

      expect(find.text('Sécurité'), findsOneWidget);
    });

    testWidgets('shows PAIEMENTS section with biometric tile', (tester) async {
      final state = AppPreferencesState(
        preferences: const UserPreferencesModel(),
      );
      await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
      await tester.pumpAndSettle();

      expect(find.text('PAIEMENTS'), findsOneWidget);
      expect(find.text('Biométrie avant paiement'), findsOneWidget);
    });

    testWidgets('shows SESSION section with devices tile', (tester) async {
      final state = AppPreferencesState(
        preferences: const UserPreferencesModel(),
      );
      await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
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
      final state = AppPreferencesState(
        preferences: const UserPreferencesModel(),
      );
      await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsWidgets);
      // The biometric switch should be disabled
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
    });

    testWidgets('affiche le tile Appareils connectés', (tester) async {
      final state = AppPreferencesState(
        preferences: const UserPreferencesModel(),
      );
      await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
      await tester.pumpAndSettle();

      expect(find.text('Appareils connectés'), findsOneWidget);
    });

    testWidgets(
      'biometric tile shows unavailable message when not supported',
      (tester) async {
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(),
        );
        await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
        await tester.pumpAndSettle();

        // biometricAvailable = false → both PAIEMENTS and APPLICATION sections
        // show 'Non disponible sur cet appareil'.
        expect(
          find.text('Non disponible sur cet appareil'),
          findsNWidgets(2),
        );
      },
    );

    testWidgets("affiche le tile Verrouillage de l'app", (tester) async {
      final state = AppPreferencesState(
        preferences: const UserPreferencesModel(),
      );
      await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
      await tester.pumpAndSettle();

      expect(find.text('APPLICATION'), findsOneWidget);
      expect(find.text("Verrouillage de l'app"), findsOneWidget);
    });

    testWidgets(
      "tapper le tile Verrouillage de l'app ne dispatche pas quand indisponible",
      (tester) async {
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(),
        );
        // biometricAvailable defaults to false → tile is not tappable.
        await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
        await tester.pumpAndSettle();

        await tester.tap(find.text("Verrouillage de l'app"));
        await tester.pumpAndSettle();

        verifyNever(() => mockBloc.add(const AppLockBiometricToggled()));
      },
    );

    testWidgets(
      "app lock switch value is false when device unavailable",
      (tester) async {
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(appLockBiometricEnabled: true),
        );
        await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
        await tester.pumpAndSettle();

        // biometricAvailable = false → switch = false regardless of pref value.
        final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
        // Second switch corresponds to APPLICATION tile.
        expect(switches[1].value, isFalse);
      },
    );

    testWidgets(
      'biometric switch value reflects biometricEnabled from bloc (device unavailable)',
      (tester) async {
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(biometricEnabled: true),
        );
        await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
        await tester.pumpAndSettle();

        // Switch = biometricEnabled(true) && biometricAvailable(false) = false.
        final switchFinder = find.byType(Switch).first;
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isFalse);
      },
    );

    testWidgets(
      'tapping biometric tile when unavailable does not dispatch BiometricToggled',
      (tester) async {
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(),
        );
        await tester.pumpWidget(_wrap(mockBloc: mockBloc, state: state));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Biométrie avant paiement'));
        await tester.pumpAndSettle();

        verifyNever(() => mockBloc.add(const BiometricToggled()));
      },
    );
  });

  // -------------------------------------------------------------------------
  // PIN-guard tests (biometricAvailable = true via override)
  // -------------------------------------------------------------------------

  group('PIN guard — activation (OFF→ON) dispatches directly', () {
    testWidgets(
      'tapping biometric tile when OFF dispatches BiometricToggled immediately (no PIN)',
      (tester) async {
        // biometricEnabled = false → activation path, no PIN required.
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(biometricEnabled: false),
        );
        await tester.pumpWidget(_wrap(
          mockBloc: mockBloc,
          state: state,
          biometricAvailable: true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Biométrie avant paiement'));
        await tester.pumpAndSettle();

        // Event dispatched without any PIN sheet.
        verify(() => mockBloc.add(const BiometricToggled())).called(1);
      },
    );

    testWidgets(
      "tapping app lock tile when OFF dispatches AppLockBiometricToggled immediately (no PIN)",
      (tester) async {
        // appLockBiometricEnabled = false → activation path, no PIN required.
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(appLockBiometricEnabled: false),
        );
        await tester.pumpWidget(_wrap(
          mockBloc: mockBloc,
          state: state,
          biometricAvailable: true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text("Verrouillage de l'app"));
        await tester.pumpAndSettle();

        verify(() => mockBloc.add(const AppLockBiometricToggled())).called(1);
      },
    );
  });

  group('PIN guard — désactivation (ON→OFF) exige confirmation PIN', () {
    testWidgets(
      'tapping biometric tile when ON opens PinConfirmBottomSheet and does NOT dispatch if dismissed',
      (tester) async {
        // biometricEnabled = true → désactivation, PIN requis.
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(biometricEnabled: true),
        );
        await tester.pumpWidget(_wrap(
          mockBloc: mockBloc,
          state: state,
          biometricAvailable: true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Biométrie avant paiement'));
        await tester.pumpAndSettle();

        // PinConfirmBottomSheet should be visible.
        expect(find.byType(PinConfirmBottomSheet), findsOneWidget);

        // Dismiss without confirming (back gesture).
        await tester.tapAt(const Offset(200, 100));
        await tester.pumpAndSettle();

        // Event must NOT have been dispatched.
        verifyNever(() => mockBloc.add(const BiometricToggled()));
      },
    );

    testWidgets(
      "tapping app lock tile when ON opens PinConfirmBottomSheet and does NOT dispatch if dismissed",
      (tester) async {
        // appLockBiometricEnabled = true (default) → désactivation, PIN requis.
        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(appLockBiometricEnabled: true),
        );
        await tester.pumpWidget(_wrap(
          mockBloc: mockBloc,
          state: state,
          biometricAvailable: true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text("Verrouillage de l'app"));
        await tester.pumpAndSettle();

        // PinConfirmBottomSheet should be visible.
        expect(find.byType(PinConfirmBottomSheet), findsOneWidget);

        // Dismiss without confirming.
        await tester.tapAt(const Offset(200, 100));
        await tester.pumpAndSettle();

        // Event must NOT have been dispatched.
        verifyNever(() => mockBloc.add(const AppLockBiometricToggled()));
      },
    );

    testWidgets(
      'BiometricToggled is dispatched after PIN confirmed (validatePin returns true)',
      (tester) async {
        when(() => mockAuthService.validatePin(any()))
            .thenAnswer((_) async => true);

        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(biometricEnabled: true),
        );
        await tester.pumpWidget(_wrap(
          mockBloc: mockBloc,
          state: state,
          biometricAvailable: true,
          authService: mockAuthService,
        ));
        await tester.pumpAndSettle();

        // Open the PIN sheet.
        await tester.tap(find.text('Biométrie avant paiement'));
        await tester.pumpAndSettle();
        expect(find.byType(PinConfirmBottomSheet), findsOneWidget);

        // Enter 6 digits to trigger validation.
        for (final digit in ['1', '2', '3', '4', '5', '6']) {
          await tester.tap(find.text(digit).first);
          await tester.pump(const Duration(milliseconds: 50));
        }
        // Wait for the 150ms delay inside PinConfirmBottomSheet + async validate.
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // After successful PIN → sheet closed → event dispatched.
        verify(() => mockBloc.add(const BiometricToggled())).called(1);
      },
    );

    testWidgets(
      'AppLockBiometricToggled is dispatched after PIN confirmed',
      (tester) async {
        when(() => mockAuthService.validatePin(any()))
            .thenAnswer((_) async => true);

        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(appLockBiometricEnabled: true),
        );
        await tester.pumpWidget(_wrap(
          mockBloc: mockBloc,
          state: state,
          biometricAvailable: true,
          authService: mockAuthService,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text("Verrouillage de l'app"));
        await tester.pumpAndSettle();
        expect(find.byType(PinConfirmBottomSheet), findsOneWidget);

        for (final digit in ['1', '2', '3', '4', '5', '6']) {
          await tester.tap(find.text(digit).first);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        verify(() => mockBloc.add(const AppLockBiometricToggled())).called(1);
      },
    );

    testWidgets(
      'BiometricToggled is NOT dispatched when PIN is wrong (validatePin returns false, max attempts)',
      (tester) async {
        // Always fail → after 3 attempts sheet closes with false.
        when(() => mockAuthService.validatePin(any()))
            .thenAnswer((_) async => false);

        final state = AppPreferencesState(
          preferences: const UserPreferencesModel(biometricEnabled: true),
        );
        await tester.pumpWidget(_wrap(
          mockBloc: mockBloc,
          state: state,
          biometricAvailable: true,
          authService: mockAuthService,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Biométrie avant paiement'));
        await tester.pumpAndSettle();
        expect(find.byType(PinConfirmBottomSheet), findsOneWidget);

        // 3 wrong attempts → sheet closes automatically with false.
        for (var attempt = 0; attempt < 3; attempt++) {
          for (final digit in ['9', '9', '9', '9', '9', '9']) {
            await tester.tap(find.text(digit).first);
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
        }

        // Event must NOT have been dispatched.
        verifyNever(() => mockBloc.add(const BiometricToggled()));
      },
    );
  });

  // ── Code PIN facultatif ───────────────────────────────────────────────────

  group('Code PIN à l\'ouverture', () {
    testWidgets('sans code configuré : interrupteur éteint et pas de « Modifier »',
        (tester) async {
      await tester.pumpWidget(_wrap(
        mockBloc: mockBloc,
        state: const AppPreferencesState(preferences: UserPreferencesModel()),
        pinConfigured: false,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Code PIN à l'ouverture"), findsOneWidget);
      expect(find.text("Désactivé, l'app s'ouvre sans code"), findsOneWidget);
      // Rien à modifier tant qu'aucun code n'existe.
      expect(find.text('Modifier le code PIN'), findsNothing);
    });

    testWidgets('avec code configuré : « Modifier » apparaît',
        (tester) async {
      await tester.pumpWidget(_wrap(
        mockBloc: mockBloc,
        state: const AppPreferencesState(preferences: UserPreferencesModel()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Demandé à chaque ouverture de yadony'), findsOneWidget);
      expect(find.text('Modifier le code PIN'), findsOneWidget);
    });

    /// Sans code PIN, `LocalAuthBloc` sort avant d'atteindre la biométrie : le
    /// verrouillage à l'ouverture ne s'applique pas. L'écran doit le dire au
    /// lieu de laisser croire l'app protégée.
    testWidgets("sans code, le verrouillage de l'app renvoie vers le PIN",
        (tester) async {
      await tester.pumpWidget(_wrap(
        mockBloc: mockBloc,
        state: const AppPreferencesState(preferences: UserPreferencesModel()),
        biometricAvailable: true,
        pinConfigured: false,
      ));
      await tester.pumpAndSettle();

      expect(
        find.text("Nécessite d'activer le code PIN ci-dessous"),
        findsOneWidget,
      );
    });

    /// Sans code à comparer, la feuille de confirmation n'a rien à vérifier :
    /// la réclamer enfermerait l'utilisateur dans un réglage indésactivable.
    testWidgets(
        'sans code, désactiver la biométrie ne demande aucune confirmation',
        (tester) async {
      await tester.pumpWidget(_wrap(
        mockBloc: mockBloc,
        state: const AppPreferencesState(
          preferences: UserPreferencesModel(biometricEnabled: true),
        ),
        biometricAvailable: true,
        pinConfigured: false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Biométrie avant paiement'));
      await tester.pumpAndSettle();

      expect(find.byType(PinConfirmBottomSheet), findsNothing);
      verify(() => mockBloc.add(const BiometricToggled())).called(1);
    });
  });
}
