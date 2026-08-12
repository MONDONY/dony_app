import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

class MockBox extends Mock implements Box {}

/// Builds a minimal GoRouter app so we can call [requirePaymentAuth] which
/// internally may push '/auth/local'.
Widget _buildApp({
  required MockLocalAuthService authService,
  required MockBox userPrefs,
  // When non-null, the stub /auth/local route pops with this value.
  bool? pinRouteResult,
  required ValueChanged<bool> onResult,
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => _TestPage(
            authService: authService,
            userPrefs: userPrefs,
            onResult: onResult,
          ),
        ),
        GoRoute(
          path: '/auth/local',
          builder: (context, _) {
            // Pop with [pinRouteResult] after build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.pop(pinRouteResult);
              }
            });
            return const SizedBox.shrink();
          },
        ),
      ],
    ),
  );
}

class _TestPage extends StatelessWidget {
  final MockLocalAuthService authService;
  final MockBox userPrefs;
  final ValueChanged<bool> onResult;

  const _TestPage({
    required this.authService,
    required this.userPrefs,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        key: const Key('trigger'),
        onPressed: () async {
          final result = await requirePaymentAuth(
            context,
            authService: authService,
            userPrefs: userPrefs,
          );
          onResult(result);
        },
        child: const Text('Pay'),
      ),
    );
  }
}

void main() {
  late MockLocalAuthService authService;
  late MockBox userPrefs;

  setUp(() {
    authService = MockLocalAuthService();
    userPrefs = MockBox();
    // Par défaut un code PIN existe : c'était l'hypothèse implicite de tous ces
    // tests, du temps où l'inscription en imposait un. Le groupe « aucun code
    // PIN » plus bas couvre le cas devenu possible depuis qu'il est facultatif.
    when(authService.isPinSet).thenAnswer((_) async => true);
  });

  group('requirePaymentAuth — toggle ON (biometricEnabled = true)', () {
    setUp(() {
      when(
        () => userPrefs.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);
    });

    testWidgets(
      'toggle ON + biométrie dispo + biométrie OK → true, PIN jamais appelé',
      (tester) async {
        when(
          () => authService.isBiometricAvailable(),
        ).thenAnswer((_) async => true);
        when(
          () => authService.authenticateWithBiometric(),
        ).thenAnswer((_) async => true);

        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: null, // should never be reached
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isTrue);
        verify(() => authService.isBiometricAvailable()).called(1);
        verify(() => authService.authenticateWithBiometric()).called(1);
        // /auth/local must NOT have been pushed (no navigation to the PIN route).
        // We assert by confirming we're still on '/'.
        final router = tester.widget<Router<Object>>(
          find.byType(Router<Object>),
        );
        final routerDelegate = router.routerDelegate as GoRouterDelegate;
        expect(routerDelegate.currentConfiguration.uri.path, equals('/'));
      },
    );

    testWidgets(
      'toggle ON + biométrie indispo → fallback PIN (route /auth/local poussée)',
      (tester) async {
        when(
          () => authService.isBiometricAvailable(),
        ).thenAnswer((_) async => false);

        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: true,
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isTrue);
        verify(() => authService.isBiometricAvailable()).called(1);
        verifyNever(() => authService.authenticateWithBiometric());
      },
    );

    testWidgets(
      'toggle ON + biométrie dispo + biométrie échoue → fallback PIN',
      (tester) async {
        when(
          () => authService.isBiometricAvailable(),
        ).thenAnswer((_) async => true);
        when(
          () => authService.authenticateWithBiometric(),
        ).thenAnswer((_) async => false);

        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: true,
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isTrue);
        verify(() => authService.authenticateWithBiometric()).called(1);
      },
    );

    testWidgets(
      'toggle ON + biométrie dispo + authenticateWithBiometric retourne false '
      '(erreur hardware catchée en interne) → fallback PIN déclenché',
      (tester) async {
        // authenticateWithBiometric() catch toutes les PlatformException en interne
        // et retourne false. Ce test vérifie que le helper route bien vers le PIN
        // dans ce cas, sans propager d'exception.
        when(
          () => authService.isBiometricAvailable(),
        ).thenAnswer((_) async => true);
        when(() => authService.authenticateWithBiometric()).thenAnswer(
          (_) async => false,
        ); // simule comportement après catch interne

        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: true, // PIN réussit
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        // La biométrie a échoué (false) → fallback PIN → résultat final true
        expect(captured, isTrue);
        verify(() => authService.isBiometricAvailable()).called(1);
        verify(() => authService.authenticateWithBiometric()).called(1);
      },
    );

    testWidgets(
      'toggle ON + biométrie dispo + authenticateWithBiometric retourne false '
      '+ PIN annulé → résultat final false',
      (tester) async {
        // Vérifie que si la biométrie échoue ET l'utilisateur annule le PIN,
        // requirePaymentAuth retourne false (pas d'authentification).
        when(
          () => authService.isBiometricAvailable(),
        ).thenAnswer((_) async => true);
        when(
          () => authService.authenticateWithBiometric(),
        ).thenAnswer((_) async => false);

        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: false, // PIN annulé
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isFalse);
        verify(() => authService.authenticateWithBiometric()).called(1);
      },
    );
  });

  group('requirePaymentAuth — toggle OFF (biometricEnabled = false)', () {
    setUp(() {
      when(
        () => userPrefs.get(
          HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(false);
    });

    testWidgets(
      'toggle OFF → biométrie jamais tentée, PIN directement (résultat true)',
      (tester) async {
        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: true,
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isTrue);
        verifyNever(() => authService.isBiometricAvailable());
        verifyNever(() => authService.authenticateWithBiometric());
      },
    );

    testWidgets(
      'toggle OFF → biométrie jamais tentée, PIN directement (résultat false)',
      (tester) async {
        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: false,
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isFalse);
        verifyNever(() => authService.isBiometricAvailable());
        verifyNever(() => authService.authenticateWithBiometric());
      },
    );
  });

  /// Le code PIN est facultatif depuis qu'il a quitté l'inscription. Sans code
  /// ni biométrie, il n'y a rien à vérifier : exiger une saisie impossible
  /// bloquerait tout paiement.
  group('requirePaymentAuth — aucun code PIN configuré', () {
    setUp(() {
      when(authService.isPinSet).thenAnswer((_) async => false);
    });

    testWidgets(
      'biométrie désactivée et pas de PIN → paiement autorisé sans rien demander',
      (tester) async {
        when(
          () => userPrefs.get(
            HiveService.kBiometricEnabled,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(false);

        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            // Piège si la route était poussée quand même : le test le verrait
            // par un résultat false au lieu de true.
            pinRouteResult: false,
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isTrue);
        verifyNever(() => authService.authenticateWithBiometric());
      },
    );

    testWidgets(
      'biométrie activée mais échouée, sans PIN → paiement autorisé',
      (tester) async {
        when(
          () => userPrefs.get(
            HiveService.kBiometricEnabled,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(true);
        when(
          () => authService.isBiometricAvailable(),
        ).thenAnswer((_) async => true);
        when(
          () => authService.authenticateWithBiometric(),
        ).thenAnswer((_) async => false);

        bool? captured;

        await tester.pumpWidget(
          _buildApp(
            authService: authService,
            userPrefs: userPrefs,
            pinRouteResult: false,
            onResult: (r) => captured = r,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pumpAndSettle();

        expect(captured, isTrue);
      },
    );
  });
}
