import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/kyc_rejection_messages.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

const _title = 'Identity verification';

void main() {
  late _MockAuthBloc authBloc;
  late _MockKycBloc kycBloc;
  late StreamController<KycState> kycStates;
  late List<KycEvent> events;
  final en = lookupAppLocalizations(AppL10n.en);

  setUpAll(() {
    registerFallbackValue(const KycStatusRefreshed());
    registerFallbackValue(const AuthCheckRequested());
  });

  setUp(() async {
    useEnglish();
    await GetIt.I.reset();
    authBloc = _MockAuthBloc();
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

    kycStates = StreamController<KycState>.broadcast();
    kycBloc = _MockKycBloc();
    when(() => kycBloc.state).thenReturn(const KycInitial());
    when(() => kycBloc.stream).thenAnswer((_) => kycStates.stream);
    when(() => kycBloc.close()).thenAnswer((_) async {});
    events = [];
    when(() => kycBloc.add(any())).thenAnswer(
      (inv) => events.add(inv.positionalArguments.first as KycEvent),
    );
    GetIt.I.registerFactory<KycBloc>(() => kycBloc);
  });

  tearDown(() async {
    await kycStates.close();
    await GetIt.I.reset();
  });

  void authenticated(String kycStatus) {
    when(() => authBloc.state).thenReturn(
      AuthAuthenticated(
        UserModel(
          id: 'u1',
          roles: const [],
          kycStatus: kycStatus,
          status: 'ACTIVE',
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Ouvre la feuille depuis un écran GoRouter ; `/kyc/verify` affiche l'URL
  /// Stripe reçue en `extra`.
  Future<void> open(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => KycStatusBottomSheet.show(ctx),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/kyc/verify',
          builder: (_, state) =>
              Scaffold(body: Text('verify ${state.extra as String}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(find.text(_title), findsOneWidget);
  }

  Future<void> emit(WidgetTester tester, KycState state) async {
    kycStates.add(state);
    await settle(tester);
  }

  /// Nombre total de relevés de statut demandés depuis l'ouverture.
  int refreshCount() => events.whereType<KycStatusRefreshed>().length;

  testWidgets('sans statut connu : indicateur de chargement', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthInitial());
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('non commencée : « Start verification » ouvre Stripe', (
    tester,
  ) async {
    authenticated('NOT_STARTED');
    await open(tester);
    expect(find.text('Verification not started'), findsOneWidget);

    await tester.tap(find.text('Start verification'));
    await tester.pump();
    verify(() => kycBloc.add(const KycSessionRequested())).called(1);

    await emit(
      tester,
      const KycSessionCreated(
        stripeUrl: 'https://verify.stripe.com/s',
        sessionId: 'vs_1',
      ),
    );
    await settle(tester);
    expect(find.text('verify https://verify.stripe.com/s'), findsOneWidget);
  });

  testWidgets('refusée : motif traduit et « Retry verification »', (
    tester,
  ) async {
    authenticated('PENDING');
    await open(tester);
    await emit(
      tester,
      const KycStatusLoaded(
        kycStatus: 'REJECTED',
        verificationStatus: 'requires_input',
        rejectionCode: 'document_expired',
      ),
    );
    expect(find.text('Verification failed'), findsOneWidget);
    expect(
      find.text(kycRejectionMessage(en, 'document_expired')),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry verification'));
    await tester.pump();
    verify(() => kycBloc.add(const KycSessionRequested())).called(1);
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('vérifiée : la feuille se ferme seule et recharge le profil', (
    tester,
  ) async {
    authenticated('PENDING');
    await open(tester);
    await emit(
      tester,
      const KycStatusLoaded(kycStatus: 'VERIFIED', verificationStatus: 'ok'),
    );
    expect(find.text('Identity verified ✓'), findsOneWidget);
    // Aucun bouton collant sur l'état vérifié.
    expect(find.text('Continue later'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1600));
    await settle(tester);
    verify(() => authBloc.add(const AuthCheckRequested())).called(1);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('erreur réseau : message et « Try again » recharge', (
    tester,
  ) async {
    authenticated('PENDING');
    await open(tester);
    const error = NetworkException('réseau');
    await emit(tester, const KycError(error));
    expect(
      find.text(ErrorPresenter.resolve(error, l10n: en).message),
      findsOneWidget,
    );
    expect(refreshCount(), 1);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(refreshCount(), 2);
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('en cours : le statut est relu toutes les 30 s', (tester) async {
    authenticated('PENDING');
    await open(tester);
    expect(refreshCount(), 1);
    await emit(
      tester,
      const KycStatusLoaded(kycStatus: 'PENDING', verificationStatus: 'p'),
    );
    expect(find.text('Verification in progress'), findsOneWidget);
    expect(find.text('Automatic verification in progress'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    expect(refreshCount(), 2);

    // 429 : la période double (60 s), le relevé suivant attend.
    await emit(tester, const KycError(RateLimitException()));
    await tester.pump(const Duration(seconds: 31));
    expect(refreshCount(), 2);
    await tester.pump(const Duration(seconds: 30));
    expect(refreshCount(), 3);

    // Statut non commencé : le poll s'arrête.
    await emit(
      tester,
      const KycStatusLoaded(kycStatus: 'NOT_STARTED', verificationStatus: 'n'),
    );
    await tester.pump(const Duration(minutes: 2));
    expect(refreshCount(), 3);
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('statut inconnu : pas de poll', (tester) async {
    authenticated('PENDING');
    await open(tester);
    await emit(
      tester,
      const KycStatusLoaded(kycStatus: 'CANCELED', verificationStatus: 'c'),
    );
    await tester.pump(const Duration(minutes: 1));
    expect(refreshCount(), 1);
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('au bout de 5 min : vue d\'attente prolongée et retour', (
    tester,
  ) async {
    authenticated('PENDING');
    await open(tester);
    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await settle(tester);
    expect(
      find.text('Verification is taking longer than expected'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back to the app'));
    await settle(tester);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('le widget seul ne rend rien : tout passe par show()', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: KycStatusBottomSheet()));
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.byType(Text), findsNothing);
  });
}
