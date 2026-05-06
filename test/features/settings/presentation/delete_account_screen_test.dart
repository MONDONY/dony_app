import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _kSettle = Duration(milliseconds: 400);

void main() {
  late MockAccountDeletionBloc mockDeletionBloc;
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(const RequestDeletion());
    registerFallbackValue(const ReactivateAccount());
    registerFallbackValue(const AuthCheckRequested());
  });

  setUp(() {
    mockDeletionBloc = MockAccountDeletionBloc();
    mockAuthBloc = MockAuthBloc();

    whenListen<AccountDeletionState>(
      mockDeletionBloc,
      const Stream.empty(),
      initialState: const AccountDeletionInitial(),
    );
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: const AuthAuthenticated(UserModel(
        id: 'u1',
        roles: ['SENDER'],
        kycStatus: 'PENDING',
        status: 'ACTIVE',
      )),
    );
  });

  Widget wrap() => MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/settings/delete-account',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const Scaffold(body: Text('Settings')),
              routes: [
                GoRoute(
                  path: 'delete-account',
                  builder: (_, __) => MultiBlocProvider(
                    providers: [
                      BlocProvider<AccountDeletionBloc>.value(
                          value: mockDeletionBloc),
                      BlocProvider<AuthBloc>.value(value: mockAuthBloc),
                    ],
                    child: const DeleteAccountScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  testWidgets('renders title and explanation text', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(_kSettle);

    expect(find.text('Supprimer mon compte'), findsOneWidget);
    expect(find.textContaining('30 jours'), findsOneWidget);
  });

  testWidgets('Confirmer button dispatches RequestDeletion', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(_kSettle);

    await tester.tap(find.text('Confirmer la suppression'));
    await tester.pump();

    verify(() => mockDeletionBloc.add(const RequestDeletion())).called(1);
  });

  testWidgets('shows EscrowBlockDialog when isEscrowBlocked is true',
      (tester) async {
    whenListen<AccountDeletionState>(
      mockDeletionBloc,
      Stream.fromIterable([
        const AccountDeletionLoading(),
        const AccountDeletionError(
          message: 'escrow-active',
          isEscrowBlocked: true,
        ),
      ]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(wrap());
    await tester.pump(_kSettle);
    await tester.pumpAndSettle();

    expect(find.text('Voir mes envois'), findsOneWidget);
  });

  testWidgets('dispatches AuthCheckRequested and shows SnackBar on AccountDeletionRequested',
      (tester) async {
    whenListen<AccountDeletionState>(
      mockDeletionBloc,
      Stream.fromIterable([
        const AccountDeletionLoading(),
        const AccountDeletionRequested(),
      ]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(wrap());
    await tester.pump(_kSettle);  // let the SnackBar appear
    expect(find.byType(SnackBar), findsAtLeastNWidgets(1));  // SnackBar is visible before pop
    await tester.pumpAndSettle();

    verify(() => mockAuthBloc.add(const AuthCheckRequested())).called(1);
  });

  testWidgets('shows inline error message for generic errors', (tester) async {
    whenListen<AccountDeletionState>(
      mockDeletionBloc,
      Stream.fromIterable([
        const AccountDeletionError(message: 'Une erreur est survenue. Veuillez réessayer.'),
      ]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(wrap());
    await tester.pump(_kSettle);

    expect(find.textContaining('Une erreur est survenue'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('button is disabled during loading', (tester) async {
    whenListen<AccountDeletionState>(
      mockDeletionBloc,
      Stream.fromIterable([const AccountDeletionLoading()]),
      initialState: const AccountDeletionInitial(),
    );

    await tester.pumpWidget(wrap());
    await tester.pump(_kSettle);

    // DonyButton wraps a FilledButton — find it and verify onPressed is null
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
