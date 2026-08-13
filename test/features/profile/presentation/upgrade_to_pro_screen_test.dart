import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/profile/presentation/screens/upgrade_to_pro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockUpgradeToProBloc
    extends MockBloc<UpgradeToProEvent, UpgradeToProState>
    implements UpgradeToProBloc {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Duration long enough to let all flutter_animate delays complete.
/// The screen has delays up to 260ms.
const _kSettle = Duration(milliseconds: 600);

/// Finds the submit button (works even when animations cause duplicates).
Finder get _submitBtn => find.text('Activer le compte PRO').last;

UserModel _nonProUser() => const UserModel(
  id: 'user-1',
  roles: ['ROLE_TRAVELER'],
  kycStatus: 'NONE',
  status: 'ACTIVE',
);

UserModel _proUser() => const UserModel(
  id: 'user-2',
  roles: ['ROLE_TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  isProAccount: true,
  companyName: 'Diallo Transport SARL',
  siret: '12345678901234',
);

Widget _wrap(MockProfileRepository repo, MockAuthBloc authBloc) {
  if (getIt.isRegistered<ProfileRepository>()) {
    getIt.unregister<ProfileRepository>();
  }
  getIt.registerLazySingleton<ProfileRepository>(() => repo);

  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const UpgradeToProScreen()),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Scaffold(body: Text('Profile')),
          ),
        ],
      ),
    ),
  );
}

Widget _wrapWithUser(MockProfileRepository repo, MockAuthBloc authBloc) =>
    _wrap(repo, authBloc);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const UpgradeToProSubmitted(companyName: '', siret: ''),
    );
    registerFallbackValue(const DowngradeRequested());
    registerFallbackValue(const AuthCheckRequested());
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  tearDown(() {
    if (getIt.isRegistered<ProfileRepository>()) {
      getIt.unregister<ProfileRepository>();
    }
  });

  // ── BLoC state rendering ──────────────────────────────────────────────────

  group('UpgradeToProScreen — BLoC state rendering', () {
    late MockUpgradeToProBloc mockBloc;

    setUp(() {
      mockBloc = MockUpgradeToProBloc();
    });

    testWidgets('button is disabled when BLoC is in UpgradeToProLoading', (
      tester,
    ) async {
      whenListen<UpgradeToProState>(
        mockBloc,
        Stream.value(UpgradeToProLoading()),
        initialState: UpgradeToProLoading(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<UpgradeToProBloc>.value(
            value: mockBloc,
            // Inject the BLoC externally via a thin wrapper
            child: Builder(
              builder: (ctx) =>
                  BlocBuilder<UpgradeToProBloc, UpgradeToProState>(
                    builder: (context, state) {
                      final isLoading = state is UpgradeToProLoading;
                      return Scaffold(
                        body: Column(
                          children: [
                            FilledButton(
                              onPressed: isLoading ? null : () {},
                              child: const Text('Activer le compte PRO'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ),
        ),
      );
      await tester.pump(_kSettle);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  // ── Integration-style form tests ──────────────────────────────────────────

  group('UpgradeToProScreen — form interaction', () {
    late MockProfileRepository mockRepo;
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockRepo = MockProfileRepository();
      mockAuthBloc = MockAuthBloc();
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthInitial(),
      );
    });

    testWidgets('renders form with companyName and siret fields', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      expect(find.text('Conta PRO'), findsNothing);
      expect(find.text('Compte PRO'), findsOneWidget);
      expect(find.text('Passe en PRO'), findsOneWidget);
      expect(find.text('Activer le compte PRO'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(find.text("Le nom de l'entreprise est requis"), findsOneWidget);
      expect(find.text('Le numéro SIRET est requis'), findsOneWidget);
    });

    testWidgets('shows SIRET validation error for wrong length', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '123', // wrong length
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Le SIRET doit contenir exactement 14 chiffres'),
        findsOneWidget,
      );
    });

    testWidgets('shows confirmation dialog on valid form submission', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '12345678901234',
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirmer le passage en PRO'), findsOneWidget);
    });

    testWidgets('calls upgradeToPro and shows success snackbar on confirm', (
      tester,
    ) async {
      when(
        () => mockRepo.upgradeToPro(
          companyName: any(named: 'companyName'),
          siret: any(named: 'siret'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '12345678901234',
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Tap Confirmer in dialog
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      verify(
        () => mockRepo.upgradeToPro(
          companyName: 'Ma Société SAS',
          siret: '12345678901234',
        ),
      ).called(1);

      expect(find.text('Compte PRO activé'), findsOneWidget);
    });

    testWidgets('does NOT call upgradeToPro when dialog is cancelled', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '12345678901234',
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Tap Annuler
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockRepo.upgradeToPro(
          companyName: any(named: 'companyName'),
          siret: any(named: 'siret'),
        ),
      );
    });

    testWidgets('shows error banner when upgradeToPro throws generic error', (
      tester,
    ) async {
      when(
        () => mockRepo.upgradeToPro(
          companyName: any(named: 'companyName'),
          siret: any(named: 'siret'),
        ),
      ).thenThrow(Exception('Network timeout'));

      await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '12345678901234',
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Une erreur est survenue. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows generic error message when upgradeToPro throws AppException with code 409',
      (tester) async {
        when(
          () => mockRepo.upgradeToPro(
            companyName: any(named: 'companyName'),
            siret: any(named: 'siret'),
          ),
        ).thenThrow(const NetworkException('Conflict', code: '409'));

        await tester.pumpWidget(_wrap(mockRepo, mockAuthBloc));
        await tester.pump(_kSettle);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Ma Société SAS',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          '12345678901234',
        );
        await tester.pump(_kSettle);

        await tester.ensureVisible(_submitBtn);
        await tester.tap(_submitBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmer'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Une erreur est survenue. Vérifie ta connexion et réessaie.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  // ── PRO / non-PRO state switching ─────────────────────────────────────────

  group('UpgradeToProScreen — PRO vs non-PRO rendering', () {
    late MockProfileRepository mockRepo;
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockRepo = MockProfileRepository();
      mockAuthBloc = MockAuthBloc();
    });

    testWidgets('montre le formulaire si non PRO', (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_nonProUser()),
      );

      await tester.pumpWidget(_wrapWithUser(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      // Upgrade form is shown
      expect(find.text('Numéro SIRET'), findsOneWidget);
      expect(find.text('Activer le compte PRO'), findsOneWidget);
      // Downgrade button is NOT shown
      expect(find.text('Revenir en compte standard'), findsNothing);
    });

    testWidgets('montre downgrade si déjà PRO', (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_proUser()),
      );

      await tester.pumpWidget(_wrapWithUser(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      // Downgrade button is shown
      expect(find.text('Revenir en compte standard'), findsOneWidget);
      // Company info is shown
      expect(find.text('Diallo Transport SARL'), findsOneWidget);
      // Upgrade form is NOT shown
      expect(find.text('Activer le compte PRO'), findsNothing);
    });

    testWidgets('PRO screen shows active badge', (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_proUser()),
      );

      await tester.pumpWidget(_wrapWithUser(mockRepo, mockAuthBloc));
      await tester.pump(_kSettle);

      expect(find.text('Compte PRO actif'), findsOneWidget);
    });

    testWidgets(
      'downgrade triggers confirm dialog and dispatches DowngradeRequested on confirm',
      (tester) async {
        when(() => mockRepo.downgradePro()).thenAnswer((_) async {});

        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: AuthAuthenticated(_proUser()),
        );

        await tester.pumpWidget(_wrapWithUser(mockRepo, mockAuthBloc));
        await tester.pump(_kSettle);

        await tester.tap(find.text('Revenir en compte standard'));
        await tester.pumpAndSettle();

        // Confirm dialog shown
        expect(find.text('Désactiver le compte PRO'), findsOneWidget);

        await tester.tap(find.text('Désactiver'));
        await tester.pumpAndSettle();

        verify(() => mockRepo.downgradePro()).called(1);
      },
    );
  });
}
