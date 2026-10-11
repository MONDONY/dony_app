import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _pending = KycStatusLoaded(
  kycStatus: 'PENDING',
  verificationStatus: 'PENDING',
);

void main() {
  late _MockKycBloc kycBloc;
  late _MockAuthBloc authBloc;
  late StreamController<KycState> states;

  setUp(() {
    useEnglish();
    kycBloc = _MockKycBloc();
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );
    states = StreamController<KycState>.broadcast();
    final repo = _MockAuthRepository();
    when(() => repo.markOnboardingSeen()).thenAnswer((_) async {});
    getIt.registerSingleton<AuthRepository>(repo);
  });

  tearDown(() async {
    await states.close();
    await getIt.reset();
  });

  Future<void> pump(WidgetTester tester, KycState initial) async {
    whenListen(kycBloc, states.stream, initialState: initial);
    Widget echo(GoRouterState s) =>
        Scaffold(body: Text('page ${s.uri} ${s.extra ?? ''}'.trim()));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<KycBloc>.value(value: kycBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: const KycStatusScreen(),
          ),
        ),
        GoRoute(path: '/kyc/verify', builder: (_, s) => echo(s)),
        GoRoute(path: '/home', builder: (_, s) => echo(s)),
        GoRoute(path: '/first-steps', builder: (_, s) => echo(s)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('chargement : indicateur seul', (tester) async {
    await pump(tester, const KycLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Resume verification'), findsNothing);
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('session créée : la webview reçoit l\'URL du fournisseur', (
    tester,
  ) async {
    await pump(tester, _pending);
    states.add(
      const KycSessionCreated(
        stripeUrl: 'https://verify.didit.me/s',
        sessionId: 's1',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('page /kyc/verify https://verify.didit.me/s'),
      findsOneWidget,
    );
  });

  testWidgets('en cours : « Continue later » arrête le poll et sort', (
    tester,
  ) async {
    await pump(tester, _pending);
    expect(find.text('Continue later'), findsOneWidget);
    await tester.tap(find.text('Continue later'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('page /'), findsOneWidget);
    // Aucun relevé après la sortie.
    clearInteractions(kycBloc);
    await tester.pump(const Duration(minutes: 1));
    verifyNever(() => kycBloc.add(const KycStatusRefreshed()));
  });

  testWidgets('non commencée puis statut inconnu : le poll reste coupé', (
    tester,
  ) async {
    await pump(tester, _pending);
    states.add(
      const KycStatusLoaded(kycStatus: 'NOT_STARTED', verificationStatus: 'n'),
    );
    await tester.pump();
    states.add(
      const KycStatusLoaded(kycStatus: 'CANCELED', verificationStatus: 'c'),
    );
    await tester.pump();
    clearInteractions(kycBloc);
    await tester.pump(const Duration(minutes: 1));
    verifyNever(() => kycBloc.add(const KycStatusRefreshed()));
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('au bout de 5 min : vue prolongée, reprise ou retour', (
    tester,
  ) async {
    await pump(tester, _pending);
    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Verification is taking longer than expected'),
      findsOneWidget,
    );
    expect(find.text('Back to the app'), findsOneWidget);

    await tester.tap(find.text('Resume verification'));
    await tester.pump();
    verify(() => kycBloc.add(const KycSessionRequested())).called(1);

    await tester.tap(find.text('Back to the app'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('page /'), findsOneWidget);
  });
}
