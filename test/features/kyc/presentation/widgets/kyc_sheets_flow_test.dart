import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_required_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late _MockKycBloc kycBloc;
  late _MockAuthBloc authBloc;
  late StreamController<KycState> states;
  final en = lookupAppLocalizations(AppL10n.en);

  setUp(() async {
    useEnglish();
    DonySnackbar.clearDedup();
    await GetIt.I.reset();
    states = StreamController<KycState>.broadcast();
    kycBloc = _MockKycBloc();
    whenListen(kycBloc, states.stream, initialState: const KycInitial());
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );
    // La feuille de statut ouverte depuis « en cours » prend son propre bloc.
    final statusBloc = _MockKycBloc();
    whenListen(
      statusBloc,
      const Stream<KycState>.empty(),
      initialState: const KycLoading(),
    );
    GetIt.I.registerFactory<KycBloc>(() => statusBloc);
  });

  tearDown(() async {
    await states.close();
    await GetIt.I.reset();
  });

  /// Écran GoRouter avec un bouton qui ouvre la feuille choisie.
  Future<void> pump(
    WidgetTester tester,
    Future<void> Function(BuildContext) open,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<KycBloc>.value(value: kycBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => open(ctx),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/kyc/verify',
          builder: (_, s) => Scaffold(body: Text('verify ${s.uri} ${s.extra}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(DonyButton, label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('KycRequiredBottomSheet — vérification en cours', () {
    testWidgets('« Verify my identity » ouvre la feuille de statut', (
      tester,
    ) async {
      await pump(
        tester,
        (ctx) => KycRequiredBottomSheet.show(ctx, kycStatus: 'PENDING'),
      );
      expect(
        find.text(
          'Your verification is in progress. You\'ll be able to send once '
          'your identity is validated.',
        ),
        findsOneWidget,
      );
      await tapButton(tester, 'Verify my identity');
      expect(find.text('Verification required'), findsNothing);
      expect(find.text('Identity verification'), findsOneWidget);
      await tester.pump(const Duration(minutes: 6));
    });

    testWidgets('« Later » referme sans rien ouvrir', (tester) async {
      await pump(
        tester,
        (ctx) => KycRequiredBottomSheet.show(ctx, kycStatus: 'PENDING'),
      );
      await tapButton(tester, 'Later');
      expect(find.text('Verification required'), findsNothing);
      expect(find.text('Identity verification'), findsNothing);
    });
  });

  group('KycRequiredBottomSheet — à démarrer', () {
    Future<void> open(WidgetTester tester) => pump(
      tester,
      (ctx) => KycRequiredBottomSheet.show(
        ctx,
        kycStatus: 'REJECTED',
        returnTo: '/parcels/send-intro',
      ),
    );

    testWidgets('session demandée puis webview avec l\'écran de retour', (
      tester,
    ) async {
      await open(tester);
      verify(() => kycBloc.add(const KycReset())).called(1);

      await tapButton(tester, 'Verify my identity');
      verify(() => kycBloc.add(const KycSessionRequested())).called(1);

      states.add(
        const KycSessionCreated(
          stripeUrl: 'https://verify.didit.me/s',
          sessionId: 's1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final page = tester.widget<Text>(find.textContaining('verify /kyc'));
      expect(page.data, contains('%2Fparcels%2Fsend-intro'));
      expect(page.data, endsWith(' https://verify.didit.me/s'));
    });

    testWidgets('session en cours de création : bouton bloqué', (tester) async {
      await open(tester);
      states.add(const KycLoading());
      await tester.pump();
      // En chargement, le libellé laisse place à l'indicateur.
      final button = tester.widget<DonyButton>(find.byType(DonyButton).first);
      expect(button.label, 'Verify my identity');
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
    });

    testWidgets('erreur : message affiché, feuille gardée', (tester) async {
      await open(tester);
      const error = NetworkException('réseau');
      states.add(const KycError(error));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(ErrorPresenter.resolve(error, l10n: en).message),
        findsOneWidget,
      );
      expect(find.text('Verification required'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('« Later » referme la feuille', (tester) async {
      await open(tester);
      await tapButton(tester, 'Later');
      expect(find.text('Verification required'), findsNothing);
    });
  });

  group('KycOnboardingBottomSheet', () {
    Future<void> open(WidgetTester tester) =>
        pump(tester, KycOnboardingBottomSheet.show);

    testWidgets('démarrer : session puis webview', (tester) async {
      await open(tester);
      verify(() => kycBloc.add(const KycReset())).called(1);
      await tapButton(tester, 'Start verification');
      verify(() => kycBloc.add(const KycSessionRequested())).called(1);

      states.add(
        const KycSessionCreated(
          stripeUrl: 'https://verify.didit.me/o',
          sessionId: 's2',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('verify /kyc/verify https://verify.didit.me/o'),
        findsOneWidget,
      );
    });

    testWidgets('erreur : message affiché', (tester) async {
      await open(tester);
      const error = ServerException();
      states.add(const KycError(error));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(ErrorPresenter.resolve(error, l10n: en).message),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('« Later » referme la feuille', (tester) async {
      await open(tester);
      final before = find.byType(DonyButton).evaluate().length;
      expect(before, 2);
      await tapButton(tester, 'Later');
      expect(find.byType(DonyButton), findsNothing);
    });
  });
}
