import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockHiveService extends Mock implements HiveService {}
class MockBox extends Mock implements Box {}

GoRouter _buildRouter({
  required AuthBloc authBloc,
  required ActiveRoleCubit roleCubit,
  required String initialRole,
}) =>
    GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
          ],
          child: RoleSelectionScreen(initialRole: initialRole),
        ),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (_, __) => const Scaffold(body: Text('Phone Auth')),
      ),
    ]);

GoRouter _buildRouterWithPendingEmail({
  required AuthBloc authBloc,
  required ActiveRoleCubit roleCubit,
  required String initialRole,
  required String pendingEmail,
}) =>
    GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
          ],
          child: RoleSelectionScreen(
            initialRole: initialRole,
            pendingEmail: pendingEmail,
          ),
        ),
      ),
      GoRoute(
        path: '/auth/local',
        builder: (_, __) => const Scaffold(body: Text('Local Auth')),
      ),
    ]);

Future<void> _pump(
  WidgetTester tester, {
  required AuthBloc authBloc,
  required ActiveRoleCubit roleCubit,
  String initialRole = 'SENDER',
}) async {
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: _buildRouter(
      authBloc: authBloc,
      roleCubit: roleCubit,
      initialRole: initialRole,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late MockAuthBloc mockAuthBloc;
  late ActiveRoleCubit roleCubit;
  late MockHiveService mockHiveService;
  late MockBox mockBox;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

    mockHiveService = MockHiveService();
    mockBox = MockBox();
    when(() => mockHiveService.userPrefs).thenReturn(mockBox);
    when(() => mockBox.get(any())).thenReturn(null);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

    roleCubit = ActiveRoleCubit(hiveService: mockHiveService);

    registerFallbackValue(const OnboardingCompleted());
    registerFallbackValue(const AuthInitial());
  });

  tearDown(() => roleCubit.close());

  group('RoleSelectionScreen — affichage initial', () {
    testWidgets('affiche mascotte tenantColis quand initialRole = SENDER', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      expect(
        find.byWidgetPredicate((w) =>
            w is DonyMascotteAnimated && w.type == DonyMascotteType.tenantColis),
        findsOneWidget,
      );
    });

    testWidgets('affiche mascotte enCourse quand initialRole = TRAVELER', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'TRAVELER');
      expect(
        find.byWidgetPredicate((w) =>
            w is DonyMascotteAnimated && w.type == DonyMascotteType.enCourse),
        findsOneWidget,
      );
    });

    testWidgets('affiche les deux cartes de rôle', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit);
      expect(find.text('Expéditeur'), findsOneWidget);
      expect(find.text('Voyageur'), findsOneWidget);
    });
  });

  group('RoleSelectionScreen — interaction', () {
    testWidgets('clic Voyageur → mascotte change en enCourse', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      await tester.tap(find.text('Voyageur'));
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) =>
            w is DonyMascotteAnimated && w.type == DonyMascotteType.enCourse),
        findsOneWidget,
      );
      // Drain all pending animation timers
      await tester.pumpAndSettle();
    });

    testWidgets('clic Continuer navigue vers /auth/phone', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Phone Auth'), findsOneWidget);
    });

    testWidgets('clic Voyageur + Continuer appelle switchToTraveler', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      await tester.tap(find.text('Voyageur'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(roleCubit.state, ActiveRole.traveler);
    });

    testWidgets('clic SENDER + Continuer appelle switchToSender', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'TRAVELER');
      await tester.tap(find.text('Expéditeur'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(roleCubit.state, ActiveRole.sender);
    });
  });

  group('pendingEmail mode (post-auth)', () {
    const fakeUser = UserModel(
      id: 'user-456',
      email: 'test@gmail.com',
      roles: ['SENDER'],
      kycStatus: 'NOT_STARTED',
      status: 'ACTIVE',
    );

    testWidgets('dispatche AuthRegisterWithEmailRequested sur Continuer', (tester) async {
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: _buildRouterWithPendingEmail(
          authBloc: mockAuthBloc,
          roleCubit: roleCubit,
          initialRole: 'SENDER',
          pendingEmail: 'test@gmail.com',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Continuer'));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthRegisterWithEmailRequested(
        email: 'test@gmail.com',
        roles: ['SENDER'],
      ))).called(1);
      verifyNever(() => mockAuthBloc.add(const OnboardingCompleted()));
    });

    testWidgets('navigue vers /auth/local quand AuthAuthenticated émis', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([const AuthLoading(), AuthAuthenticated(fakeUser)]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(MaterialApp.router(
        routerConfig: _buildRouterWithPendingEmail(
          authBloc: mockAuthBloc,
          roleCubit: roleCubit,
          initialRole: 'SENDER',
          pendingEmail: 'test@gmail.com',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Local Auth'), findsOneWidget);
    });
  });
}
